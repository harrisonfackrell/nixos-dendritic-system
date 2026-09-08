# The AzerothCore (World of Warcraft: Wrath of the Lich King) server
# derivation, built with AzerothCore's CMake and any number of statically
# compiled modules.
#
# Parameters:
# - pkgs: the nixpkgs package set (build inputs come from here).
# - src: a source tree following the AzerothCore layout (top-level
#   CMakeLists.txt plus src/). It may contain a modules/ directory with one
#   subdirectory per module, each holding its own src/ subdirectory; the
#   core's CMake auto-discovers them (file(GLOB) in
#   src/cmake/macros/ConfigureModules.cmake) and bakes the module list,
#   config-file locations and SQL-update paths into the binaries. The tree
#   must be a persistent store path: the runtime SourceDirectory lookups
#   (SQL updaters, module conf loading) resolve against it.
# - version: informational version string for the store path name.
# - configFiles: list of { name, file } pairs installed relative to $out
#   (name = "etc/worldserver.conf"), where file is a derivation providing
#   the file content (typically pkgs.writeText). The core reads
#   <prefix>/etc/<name>.conf (CONF_DIR is baked in by its CMake) and, for
#   each compiled-in module, <prefix>/etc/modules/<module>.conf.
#
# The AzerothCore core is GPLv3+; check each compiled-in module's own
# license separately.
{ pkgs, src, version ? "17.0.0", configFiles ? [ ] }:
with pkgs;
stdenv.mkDerivation (finalAttrs: {
    pname = "azerothcore-wotlk";
    inherit version src;

    nativeBuildInputs = [
        cmake
        ninja
        # Provides mysql_config, which the core's FindMySQL.cmake uses to
        # locate the MySQL client headers/library.
        mysql84
    ];

    buildInputs = [
        boost
        openssl
        mysql84
        readline
        bzip2
        zlib
    ];

    # String-valued options (CACHE STRING in conf/dist/config.cmake) are
    # passed as plain -D strings; lib.cmakeBool only works for booleans.
    cmakeFlags = [
        "-DAPPS_BUILD=all"     # build authserver + worldserver
        "-DTOOLS_BUILD=db-only" # build dbimport (default "none" skips it)
        "-DSCRIPTS=static"
        "-DMODULES=static"     # compile discovered modules into the worldserver
        (lib.cmakeBool "BUILD_TESTING" false)
        (lib.cmakeBool "WITHOUT_GIT" true)  # store paths have no .git
        (lib.cmakeBool "USE_COREPCH" false)
        (lib.cmakeBool "USE_SCRIPTPCH" false)
    ];
    cmakeBuildType = "RelWithDebInfo"; # debug symbols help with crash triage

    # Install the generated config files next to the binaries
    # (CONF_DIR == <prefix>/etc).
    postInstall = lib.concatMapStrings (f: ''
        install -Dm644 ${f.file} $out/${f.name}
    '') configFiles;

    passthru = { inherit src; };

    meta = with lib; {
        description = "AzerothCore World of Warcraft: Wrath of the Lich King server with statically compiled modules";
        homepage = "https://www.azerothcore.org/";
        license = licenses.gpl3Plus;
        platforms = platforms.linux;
        mainProgram = "worldserver";
    };
})
