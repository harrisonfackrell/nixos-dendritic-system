{ self, inputs, ... }:
{
    # NixOS feature module: builds AzerothCore (WotLK) with an arbitrary set of
    # statically compiled modules, wires up MySQL, generates the server config
    # files and provides systemd units.
    #
    # Usage from a host configuration:
    #   imports = [ self.nixosModules.azerothcore ];
    #   services.azerothcore.enable = true;
    #
    # The AzerothCore source tree and the set of modules are both options, so a
    # host can substitute a fork of the core and/or supply any number of
    # modules (e.g. fetched with pkgs.fetchFromGitHub) without touching this
    # module:
    #   services.azerothcore.source = {
    #       src = pkgs.fetchFromGitHub {
    #           owner = "some-org"; repo = "azerothcore-wotlk";
    #           rev = "…"; hash = "sha256-…";
    #       };
    #       version = "17.0.0";
    #   };
    #   services.azerothcore.modules = {
    #       # The attribute name is the directory the module is copied into
    #       # (modules/<name>/); the module must contain a src/ subdirectory.
    #       mod-playerbots = {
    #           src = pkgs.fetchFromGitHub {
    #               owner = "mod-playerbots"; repo = "mod-playerbots";
    #               rev = "…"; hash = "sha256-…";
    #           };
    #           # Provisions (ensures + grants) the acore_playerbots MySQL
    #           # database. The connection string itself is a normal conf
    #           # key the host adds to configFiles below, built with the
    #           # services.azerothcore.dbInfo helper:
    #           database = "acore_playerbots";
    #           # The module's conf files: key = file name (must match the
    #           # module's conf/<name>.conf.dist), value = its key/value
    #           # pairs (same shape as the core *Config options).
    #           configFiles = {
    #               playerbots.conf = {
    #                   PlayerbotsDatabaseInfo = dbInfo "acore_playerbots";
    #                   SomeKey = "value";
    #               };
    #           };
    #       };
    #   };
    #
    # dbInfo is exposed as a module option (a function taking a database
    # name) so hosts can build *DatabaseInfo connection strings for module
    # confs without hardcoding the MySQL user/password:
    #   services.azerothcore.dbInfo "acore_playerbots"
    #
    # The built package is exposed as pkgs.azerothcoreWotlk (via a nixpkgs
    # overlay) and the servers run from it through the systemd units defined
    # here.
    #
    # Config files are fully declarative. The contents of each core .conf file
    # (authserver, worldserver, dbimport) and of each module's conf are exposed
    # as attribute-set options. The module ships sensible defaults for the core
    # keys; a host can override a single key or add new ones without disturbing
    # the rest, e.g.:
    #   services.azerothcore.worldserverConfig.MaxPlayers = "200";
    #   services.azerothcore.worldserverConfig."GM.StartLevel" = "50";
    # AzerothCore's Config::ParseFile is *flat*: a key like "GM.StartLevel"
    # (or "CharacterCreating.Disabled.RaceMask") is a single literal key name,
    # not a nested path, so every conf key is a flat quoted attr name and
    # values are strings or integers. Nested attribute sets are not possible;
    # e.g.
    #   services.azerothcore.worldserverConfig."Visibility.Distance.Continents" = "100";
    flake.nixosModules.azerothcore = { config, lib, pkgs, ... }:
    let
        cfg = config.services.azerothcore;

        # Private helpers. They live under `_lib/` so import-tree's default
        # filter (which ignores any path containing `/_`) does not pick them
        # up as separate flake modules; they are plain libraries imported here.
        # The conf machinery is pure, so it is imported up front; the other
        # helpers depend on `cfg` / `azerothcorePkg` and are imported just
        # before they are used, further down.
        conf = import ./_lib/conf.nix { inherit lib; };

        # Connection strings shared by all servers + modules:
        #   host;port;user;password;database
        dbInfo = db: "127.0.0.1;3306;${cfg.mysqlUser};${cfg.mysqlPassword};${db}";

        # nixpkgs has no built-in "function" option type, so the dbInfo
        # helper option uses a minimal hand-rolled one: any function passes
        # (the host is responsible for the argument/return contract, which
        # the description documents).
        funcType = lib.mkOptionType {
            name = "function";
            description = "a function";
            descriptionClass = "composite";
            check = builtins.isFunction;
        };

        mysqlExe = "${pkgs.mysql84}/bin/mysql";
        logsDir = "/var/lib/azerothcore/logs";
        tmpDir = "/var/lib/azerothcore";

        # ---------------------------------------------------------------------
        # Default contents of each core config file.
        #
        # Each server reads <prefix>/etc/<name>.conf (CONF_DIR is baked in as
        # <prefix>/etc by the core's CMake), and the worldserver additionally
        # reads <prefix>/etc/modules/<module>.conf for each compiled-in module.
        #
        # The complete default key/value set of each core .conf file is
        # generated from the upstream *.conf.dist files - see _lib/defaults.nix
        # - with the host-dependent values (ports, *DatabaseInfo connection
        # strings, log/temp dirs, the mysql binary) layered over the literals.
        # Every conf key, including dotted ones, is a flat quoted attr name;
        # the renderer in _lib/conf.nix writes them out verbatim.
        #
        # SourceDirectory is deliberately NOT a conf key: it is the one key
        # whose value is the package's own store path (<prefix>/source, the
        # merged source tree the SQL updaters read from), which the generated
        # conf files cannot reference (they are build *inputs* of the
        # package). AzerothCore's ConfigMgr checks environment variables
        # before conf files for every key (AC_ + upper-snake-case name, even
        # for keys the file does not define), so the units in
        # _lib/services.nix set AC_SOURCE_DIRECTORY to <package>/source
        # instead. The tree persists in the store because the systemd units
        # reference the package and thus GC-protect it.
        #
        # NOTE: every value is a plain string or integer. DataDir in
        # particular is coerced with toString because `cfg.dataDir` is a
        # lib.types.path; interpolating a bare path literal forces Nix to
        # verify the path exists at eval time, which fails on a host that
        # hasn't been booted with this module yet.
        # ---------------------------------------------------------------------
        allDefaults = (import ./_lib/defaults.nix) {
            inherit cfg dbInfo logsDir tmpDir mysqlExe;
        };

        # ---------------------------------------------------------------------
        # Materialize every config file as a store path (pkgs.writeText) and
        # describe where it goes. The core reads <prefix>/etc/<name>.conf and,
        # per module conf file, <prefix>/etc/modules/<file>, so each entry
        # carries:
        # - name:   the install path inside the package ("etc/<name>.conf" for
        #           core files, "etc/modules/<file>" for module files).
        #           The package lays a *symlink* there (see _lib/package.nix);
        # - etcRel: the path under ${etcConfDir} where the *content* is
        #           materialized via environment.etc, and the symlink's target.
        # Keeping the content out of the package's build inputs is what lets
        # a conf edit avoid the ~30-60 min CMake rebuild: only the writeText
        # and the nixos activation re-run. The units embed the store paths
        # (see _lib/services.nix) so restart semantics are preserved.
        # ---------------------------------------------------------------------
        etcConfDir = "/etc/azerothcore";
        coreConfFile = name:
            {
                name = "etc/${name}.conf";
                etcRel = "${name}.conf";
                file = pkgs.writeText "${name}.conf" (conf.renderConf name cfg."${name}Config");
            };
        # One entry per conf file of a module. The file name is the key of the
        # module's configFiles attrset; it must match the module's
        # conf/<name>.conf.dist, since the worldserver loads
        # <prefix>/etc/modules/<name> for each compiled-in module. The
        # connection string (if the module uses a database) is a plain conf
        # key the host writes into the file's value, built with dbInfo.
        moduleConfFile = name: entry:
            lib.mapAttrsToList (file: values:
                {
                    name = "etc/modules/${file}";
                    etcRel = "modules/${file}";
                    file = pkgs.writeText "${name}-${file}" (conf.renderConf file values);
                }) entry.configFiles;
        # Module confs: mapAttrsToList yields one *list* of entries per module
        # (moduleConfFile is list-valued), so flatten one level to get a flat
        # list. (lib.concatMapAttrs is not usable: it expects an attrset
        # return, not a list.)
        configFiles =
            (lib.map coreConfFile [ "authserver" "worldserver" "dbimport" ])
            ++ lib.flatten (lib.mapAttrsToList (name: entry: moduleConfFile name entry) cfg.modules);

        # ---------------------------------------------------------------------
        # Build the package with this host's source tree, version, the
        # requested modules and the generated config files. The private
        # builder in _lib/package.nix pulls its build inputs (stdenv, cmake,
        # boost, mysql84, ...) from `pkgs`; src, version, modules and
        # configFiles come from the options above. Module merging happens
        # inside the derivation (see that file).
        #
        # The units below reference this local derivation. It is *also*
        # exposed as pkgs.azerothcoreWotlk through the nixpkgs overlay in
        # `config` (same derivation, so it is built only once), for use from
        # host configurations and other modules. (The module's `pkgs`
        # special argument does not include overlays declared by the module
        # itself, hence the local reference in the units.)
        # ---------------------------------------------------------------------
        azerothcorePkg = (import ./_lib/package.nix) {
            inherit pkgs;
            # Symlink specs only ({ name, target }): the conf *content* is
            # materialized under /etc/azerothcore (see confEtc below) and is
            # not a build input of the package, so editing a conf does not
            # retrigger the CMake build.
            configFiles =
                lib.map (f: {
                    inherit (f) name;
                    target = "${etcConfDir}/${f.etcRel}";
                }) configFiles;
            inherit (cfg.source) src version;
            # Directory name -> module source tree; the package copies each
            # into $sourceRoot/modules/<name>/ before CMake configure.
            modules = lib.mapAttrs (_: entry: entry.src) cfg.modules;
        };

        # These helpers are imported here (after `azerothcorePkg`, which they
        # need) and before `config`, which consumes their `.config` attrsets.
        mysqlLib = import ./_lib/mysql.nix { inherit lib pkgs cfg; };
        servicesLib = import ./_lib/services.nix {
            inherit lib pkgs cfg azerothcorePkg configFiles;
            mysqlInitSql = mysqlLib.mysqlInitSql;
        };

        # Default contents for each core config file, declared at the *leaf*
        # level (each key individually wrapped in lib.mkDefault) so that a host
        # overriding one key - or adding a new one - keeps every other default
        # key intact. The confValueType's custom element merge
        # (lib.mkOptionType in _lib/conf.nix) implements the per-key
        # priority-based (last-wins) merge for this.
        confDefaults = {
            services.azerothcore.authserverConfig =
                lib.mapAttrs (_: v: lib.mkDefault v) allDefaults.authserver;
            services.azerothcore.worldserverConfig =
                lib.mapAttrs (_: v: lib.mkDefault v) allDefaults.worldserver;
            services.azerothcore.dbimportConfig =
                lib.mapAttrs (_: v: lib.mkDefault v) allDefaults.dbimport;
        };

        # Materialize the generated confs under /etc/azerothcore - the
        # targets of the symlinks the package installs. A conf edit rewrites
        # these files at activation time (cheap) instead of rebuilding
        # azerothcorePkg. environment.etc maps <relative path> ->
        # { source = …; } (a submodule), so the /etc/azerothcore prefix is
        # part of each key. The default mode "symlink" means each file is a
        # symlink into the Nix store; the worldserver follows that chain
        # transparently. A host can override one file's content via
        # environment.etc."azerothcore/<file>".text / .source.
        confEtc = {
            environment.etc = lib.listToAttrs (
                lib.map (f: {
                    name = "azerothcore/${f.etcRel}";
                    value = { source = f.file; };
                }) configFiles
            );
        };

        # All the enable-gated settings: conf defaults + conf installation +
        # MySQL + systemd services + firewall + packages. The fragments share
        # top-level keys (`services`, `systemd`, `environment`) but have
        # disjoint leaf paths, so a shallow `//` would silently drop a whole
        # subtree; lib.recursiveUpdate keeps them all.
        enabledSettings = lib.mkIf cfg.enable
            (lib.recursiveUpdate (lib.recursiveUpdate confDefaults confEtc)
                (lib.recursiveUpdate mysqlLib.config servicesLib.config));
    in
    {
        options.services.azerothcore = {
            enable = lib.mkEnableOption "the AzerothCore (WotLK) server with statically compiled modules";

            source = lib.mkOption {
                type = lib.types.submodule {
                    options = {
                        src = lib.mkOption {
                            type = lib.types.package;
                            # Latest commit of azerothcore/azerothcore-wotlk
                            # `master`, pinned with a content hash.
                            default = pkgs.fetchFromGitHub {
                                owner = "azerothcore";
                                repo = "azerothcore-wotlk";
                                rev = "f1bef3bc0a2f6396175e184c2cac70df77b46d11";
                                hash = "sha256-0cCscmspZLqt9WtULVUph2aoA/lWW9eZb19sG4n+HtI=";
                            };
                            description = ''
                                AzerothCore (WotLK) source tree: a store path or
                                derivation whose top level is the core (a
                                CMakeLists.txt and a src/ directory). Defaults to
                                the latest commit of azerothcore/azerothcore-wotlk
                                `master`, fetched with pkgs.fetchFromGitHub. Point
                                this at a fork (e.g. another
                                pkgs.fetchFromGitHub) to build a different core.
                            '';
                        };
                        version = lib.mkOption {
                            type = lib.types.str;
                            default = "17.0.0";
                            description = "Version string, used to name the built package's store path.";
                        };
                    };
                };
                description = "The AzerothCore source tree and version to build.";
            };

            modules = lib.mkOption {
                type = lib.types.attrsOf (
                    lib.types.submodule {
                        options = {
                            src = lib.mkOption {
                                type = lib.types.package;
                                description = ''
                                    Module source: a store path or derivation
                                    (e.g. pkgs.fetchFromGitHub). The directory name
                                    is taken from this option's attribute and the
                                    module must contain a src/ subdirectory
                                    (AzerothCore's module layout).
                                '';
                            };
                            database = lib.mkOption {
                                type = lib.types.nullOr lib.types.str;
                                default = null;
                                description = ''
                                    If set, the module's MySQL database name. The
                                    database is ensured and granted to the app
                                    user. The connection string itself is a plain
                                    conf key - add it to configFiles, e.g.
                                    PlayerbotsDatabaseInfo = dbInfo "acore_playerbots";
                                '';
                            };
                            configFiles = lib.mkOption {
                                type = lib.types.attrsOf conf.confValueType;
                                default = { };
                                description = ''
                                    The module's conf files. Each key is a file
                                    name (e.g. "playerbots.conf") that must match
                                    the module's conf/<name>.conf.dist - the
                                    worldserver loads <prefix>/etc/modules/<name>
                                    for each compiled-in module. Each value is
                                    that file's key/value pairs (same shape as
                                    the core *Config options). An empty set
                                    installs no conf files for the module.
                                '';
                            };
                        };
                    }
                );
                default = { };
                description = ''
                    Modules to compile into the worldserver, keyed by the
                    directory name they are installed as (modules/<name>/). An
                    empty set builds the core with no modules.
                '';
            };

            dataDir = lib.mkOption {
                type = lib.types.path;
                default = "/var/lib/azerothcore/data";
                description = ''
                    Directory holding the WoW WotLK client data (dbc/, maps/,
                    vmaps/, mmaps/). Must be populated manually from a legitimate
                    game client install. Used as the default for
                    worldserverConfig.DataDir.
                '';
            };

            worldPort = lib.mkOption {
                type = lib.types.port;
                default = 8085;
                description = "TCP port the world server listens on. Used as the default for worldserverConfig.WorldServerPort.";
            };

            authPort = lib.mkOption {
                type = lib.types.port;
                default = 3724;
                description = "TCP port the auth server listens on. Used as the default for authserverConfig.RealmServerPort.";
            };

            openFirewall = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Open the auth and world TCP ports on the NixOS firewall.";
            };

            user = lib.mkOption {
                type = lib.types.str;
                default = "azerothcore";
                description = "System user the servers run as.";
            };

            mysqlUser = lib.mkOption {
                type = lib.types.str;
                default = "acore";
                description = "MySQL user the servers connect as. Used to build the default *DatabaseInfo connection strings.";
            };

            mysqlPassword = lib.mkOption {
                type = lib.types.str;
                default = "acore";
                description = "MySQL password for the database user. Used to build the default *DatabaseInfo connection strings. Change in production.";
            };

            # Helper exposed to hosts for building *DatabaseInfo connection
            # strings (e.g. for a module's conf files) without hardcoding the
            # MySQL user/password: dbInfo "acore_playerbots" ->
            # "127.0.0.1;3306;acore;acore;acore_playerbots". A plain function
            # option; the default lambda captures cfg so it reflects the
            # host's (possibly overridden) mysqlUser / mysqlPassword.
            dbInfo = lib.mkOption {
                type = funcType;
                default = dbInfo;
                description = ''
                    Build a MySQL connection string (host;port;user;password;
                    database) for the given database name, using mysqlUser and
                    mysqlPassword. Use it in module configFiles, e.g.
                    PlayerbotsDatabaseInfo = dbInfo "acore_playerbots";
                '';
            };

            # -----------------------------------------------------------------
            # Per-file config contents for the three core servers.
            #
            # Each option is the full set of "Key" = "Value" pairs written to the
            # corresponding .conf file. The module provides a complete, working
            # default for every key; a host can override any individual key (or
            # add new ones) without disturbing the rest, e.g.:
            #   services.azerothcore.worldserverConfig.MaxPlayers = "200";
            #   services.azerothcore.worldserverConfig."GM.StartLevel" = "50";
            # AzerothCore's Config::ParseFile is flat, so every key is a single
            # literal name - quoted in Nix when it contains a dot - and values
            # are strings or integers. Nested attrsets are rejected at eval
            # time; there is no nesting to flatten.
            # -----------------------------------------------------------------
            authserverConfig = lib.mkOption {
                type = conf.confValueType;
                default = { };
                description = ''
                    Contents of authserver.conf as a set of key/value pairs,
                    installed to /etc/azerothcore/authserver.conf (the
                    package carries a symlink to it). The shipped defaults
                    (_lib/defaults.nix) are the complete set of keys from
                    upstream's authserver.conf.dist, with the host-dependent
                    values (RealmServerPort, LoginDatabaseInfo, LogsDir,
                    TempDir, MySQLExecutable) overridden. Note:
                    SourceDirectory is not a conf key here - it is supplied
                    as the AC_SOURCE_DIRECTORY environment variable by the
                    systemd unit (it is the package's own store path, which
                    the generated conf cannot reference).
                '';
            };

            worldserverConfig = lib.mkOption {
                type = conf.confValueType;
                default = { };
                description = ''
                    Contents of worldserver.conf as a set of key/value pairs.
                    The shipped defaults (_lib/defaults.nix) are the complete
                    set of keys from upstream's worldserver.conf.dist, with
                    the host-dependent values (RealmID, DataDir,
                    WorldServerPort, the *DatabaseInfo strings, LogsDir,
                    TempDir, MySQLExecutable) overridden. SourceDirectory is
                    supplied via the AC_SOURCE_DIRECTORY environment
                    variable; see authserverConfig for the rationale.
                '';
            };

            dbimportConfig = lib.mkOption {
                type = conf.confValueType;
                default = { };
                description = ''
                    Contents of dbimport.conf as a set of key/value pairs.
                    The shipped defaults (_lib/defaults.nix) are the complete
                    set of keys from upstream's dbimport.conf.dist, with the
                    host-dependent values (the *DatabaseInfo strings, LogsDir,
                    TempDir, MySQLExecutable) overridden. SourceDirectory is
                    supplied via the AC_SOURCE_DIRECTORY environment variable;
                    see authserverConfig for the rationale.
                '';
            };
        };

        config = {
            # Expose the built package in the system's pkgs set as
            # pkgs.azerothcoreWotlk (the same derivation the units use).
            # Declared unconditionally (outside mkIf) so the attribute always
            # exists; it is only *built* when referenced.
            nixpkgs.overlays = [ (final: prev: { inherit azerothcorePkg; }) ];
        } // enabledSettings;
    };
}
