# The AzerothCore (World of Warcraft: Wrath of the Lich King) server
# derivation, built with AzerothCore's CMake and any number of statically
# compiled modules.
#
# Parameters:
# - pkgs: the nixpkgs package set (build inputs come from here).
# - src: a source tree following the AzerothCore layout (top-level
#   CMakeLists.txt plus src/). Defaults to the latest commit on
#   azerothcore/azerothcore-wotlk master, pinned via fetchFromGitHub.
# - version: informational version string for the store path name.
# - modules: optional attrset mapping a module's directory name (the
#   modules/<name>/ it is merged into in the source tree) to the module's
#   source tree (a store path or derivation whose top level is the module,
#   i.e. contains a src/ subdirectory). Defaults to { } (core only).
# - configFiles: list of { name, target } pairs. A symlink is installed at
#   $out/<name> (name = "etc/worldserver.conf" or "etc/modules/<module>.conf")
#   pointing at <target>, the runtime location of the file's content (the
#   NixOS module materializes it under /etc/azerothcore via environment.etc).
#   The core reads <prefix>/etc/<name>.conf (CONF_DIR is baked in by its
#   CMake) and, for each compiled-in module, <prefix>/etc/modules/<module>.
#   conf. Keeping the conf *content* out of the build inputs is deliberate:
#   editing a conf then changes only the (cheap) writeText, not this build.
#
# The module merging happens in the build itself (postUnpack): each module
# is copied into $sourceRoot/modules/<name>/ before the configure phase,
# because the core's CMake auto-discovers modules/* (a file(GLOB) in
# src/cmake/macros/ConfigureModules.cmake) at configure time and bakes the
# module list, config-file locations and SQL-update paths into the
# binaries. Each module must contain a src/ subdirectory (the AzerothCore
# module layout); the build fails if it does not.
#
# The merged tree (core + modules) is installed to $out/source in
# postInstall: the runtime SourceDirectory lookups (worldserver
# auth/world/characters updaters, the dbimport tool, and modules' own DB
# updaters) all resolve SQL files relative to it, so it must persist in
# the store. The NixOS module sets AC_SOURCE_DIRECTORY to $out/source in
# the systemd units (AzerothCore's ConfigMgr checks AC_* environment
# variables before the conf file for every key) - the conf files are
# build inputs of this derivation, so they cannot reference its own
# (not yet known) store path.
#
# The AzerothCore core is GPLv3+; check each compiled-in module's own
# license separately.
{ pkgs, src ? pkgs.lib.fetchFromGitHub {
    owner = "azerothcore";
    repo = "azerothcore-wotlk";
    rev = "16685343110115b12e76d517f7bac15c6a97fb2a";
    hash = "sha256-sCi8tvuQtiMRYyghfR4s9uEnFCP_XLTOY9Au1-jWcUo=";
}, version ? "17.0.0", modules ? { }, configFiles ? [ ] }:
with pkgs;
let
    # The shell script fragment that copies the requested modules into
    # $sourceRoot/modules/<name>/ (merged in postUnpack, before the
    # configure phase).
    mergeModulesScript = lib.concatStringsSep "\n"
        (lib.mapAttrsToList
            (name: modSrc: ''
                mkdir -p $sourceRoot/modules
                cp -r ${modSrc} $sourceRoot/modules/${name}
                test -d $sourceRoot/modules/${name}/src || {
                    echo "azerothcore module '${name}' is missing a src/ subdirectory" >&2
                    exit 1
                }
            '')
            modules);
in
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

    # Sanity-check the core tree and merge the requested modules in before
    # the configure phase: the module list (plus each module's conf and
    # SQL-update paths) is discovered by file(GLOB) at configure time, so
    # the modules must already sit in $sourceRoot/modules/<name>/ then.
    postUnpack = ''
        test -d $sourceRoot/src
        test -f $sourceRoot/CMakeLists.txt
        ${mergeModulesScript}
    '';

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

    # Lay symlinks next to the binaries (CONF_DIR == <prefix>/etc) pointing
    # at the runtime conf locations (see the file header), then persist the
    # merged source tree for the runtime SourceDirectory SQL lookups.
    postInstall =
        lib.concatMapStrings (f: ''
            install -d $(dirname $out/${f.name})
            ln -s ${f.target} $out/${f.name}
        '') configFiles
        + ''
            cp -r $sourceRoot $out/source
        '';

    passthru = { inherit src modules; };

    meta = with lib; {
        description = "AzerothCore World of Warcraft: Wrath of the Lich King server with statically compiled modules";
        homepage = "https://www.azerothcore.org/";
        license = licenses.gpl3Plus;
        platforms = platforms.linux;
        mainProgram = "worldserver";
    };
})
