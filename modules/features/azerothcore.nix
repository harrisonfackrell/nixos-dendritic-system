{ self, inputs, ... }:
{
    # NixOS feature module: builds the AzerothCore (WotLK) Playerbot fork
    # with mod-playerbots compiled in, wires up MySQL, generates the
    # server config files and provides systemd units.
    #
    # Usage from a host configuration:
    #   imports = [ self.nixosModules.azerothcore ];
    #   services.azerothcore.enable = true;
    #
    # Config files are fully declarative: the contents of each of the four
    # .conf files (authserver, worldserver, dbimport, playerbots) are each
    # exposed as an attribute-set option (services.azerothcore.*Config).
    # The module ships a sensible default for every key; a host can
    # override a single key or add new ones without disturbing the rest,
    # e.g.:
    #   services.azerothcore.worldserverConfig.MaxPlayers = "200";
    #   services.azerothcore.worldserverConfig.Visibility = {
    #       Distance.Continents = 100;
    #       ObjectSparkles = "1";
    #   };
    # Values are strings or integers. Nested attribute sets are flattened
    # to the dot-separated key names that AzerothCore's (flat)
    # Config::ParseFile expects: the example above renders as
    #   Visibility.Distance.Continents = 100
    #   Visibility.ObjectSparkles = 1
    # Keys that contain a dot but are *not* a nested path must be quoted
    # in Nix so they stay a single literal key, e.g.
    #   services.azerothcore.worldserverConfig."GM.StartLevel" = "50";
    flake.nixosModules.azerothcore = { config, lib, pkgs, ... }:
    let
        cfg = config.services.azerothcore;

        # Connection strings shared by all three servers + the playerbots
        # module:  host;port;user;password;database
        dbInfo = db: "127.0.0.1;3306;${cfg.mysqlUser};${cfg.mysqlPassword};${db}";

        mysqlExe = "${pkgs.mysql84}/bin/mysql";
        logsDir = "/var/lib/azerothcore/logs";
        tmpDir = "/var/lib/azerothcore";

        # --------------------------------------------------------------
        # Merge the AzerothCore Playerbot fork with mod-playerbots the
        # same way the upstream quick-start does it:
        #   git clone mod-playerbots azerothcore-wotlk/modules/mod-playerbots
        # The fork's CMake auto-discovers modules/* (a directory that
        # contains a src/ subdir) and bakes the module list + config
        # list + SQL-update paths into the binaries. The result is a
        # store path that persists, so the runtime lookups below keep
        # working.
        #
        # Both inputs are source-only flake inputs (flake = false), so
        # `inputs.azerothcore` and `inputs.playerbots` are the source
        # tree paths themselves.
        # --------------------------------------------------------------
        mergedSource =
            if cfg.enablePlayerbots then
                pkgs.stdenvNoCC.mkDerivation {
                    pname = "azerothcore-wotlk-with-playerbots";
                    version = "17.0.0";
                    dontUnpack = true;
                    buildPhase = ''
                        cp -r ${inputs.azerothcore} merged
                        mkdir -p merged/modules
                        cp -r ${inputs.playerbots} merged/modules/mod-playerbots
                        mv merged $out
                    '';
                }
            else
                inputs.azerothcore;

        # --------------------------------------------------------------
        # Default contents of each config file.
        #
        # Each server reads <prefix>/etc/<name>.conf (CONF_DIR is baked
        # in as <prefix>/etc by src/cmake/platform/unix/settings.cmake),
        # and the worldserver additionally reads
        # <prefix>/etc/modules/<module>.conf for each compiled-in module.
        #
        # IMPORTANT: AzerothCore's Config.cpp keeps the *first*
        # occurrence of a key and skips later duplicates
        # (Config::ParseFile -> IsDuplicateOption). The shipped
        # *.conf.dist files already define keys such as
        # LoginDatabaseInfo / RealmServerPort / WorldServerPort /
        # DataDir / SourceDirectory, so we cannot simply append our
        # values. Instead we generate a complete .conf that contains
        # only the keys we care about; the rest of the server behaviour
        # falls back to the compiled-in defaults.
        #
        # SourceDirectory points at the source tree that was compiled
        # into the package (the store path of `mergedSource`). The
        # runtime SQL base/updates lookups (worldserver auth/world/
        # characters updaters, the dbimport tool, and the playerbots
        # module's own DB updater) all resolve relative to this path, so
        # it must persist in the store — which it does, because the
        # systemd units reference the package and thus GC-protect it.
        #
        # NOTE: every value below is a plain *string*. DataDir in
        # particular is coerced with toString because `cfg.dataDir` is a
        # lib.types.path; interpolating a bare path literal forces Nix to
        # verify the path exists at eval time, which fails on a host that
        # hasn't been booted with this module yet.
        # --------------------------------------------------------------
        mkConfDefaults = {
            authserver = {
                RealmServerPort = toString cfg.authPort;
                LoginDatabaseInfo = dbInfo "acore_auth";
                LogsDir = logsDir;
                TempDir = tmpDir;
                MySQLExecutable = mysqlExe;
                SourceDirectory = "${mergedSource}";
            };
            worldserver = {
                DataDir = toString cfg.dataDir;
                WorldServerPort = toString cfg.worldPort;
                LoginDatabaseInfo = dbInfo "acore_auth";
                WorldDatabaseInfo = dbInfo "acore_world";
                CharacterDatabaseInfo = dbInfo "acore_characters";
                LogsDir = logsDir;
                TempDir = tmpDir;
                MySQLExecutable = mysqlExe;
                SourceDirectory = "${mergedSource}";
            };
            dbimport = {
                LoginDatabaseInfo = dbInfo "acore_auth";
                WorldDatabaseInfo = dbInfo "acore_world";
                CharacterDatabaseInfo = dbInfo "acore_characters";
                LogsDir = logsDir;
                TempDir = tmpDir;
                MySQLExecutable = mysqlExe;
                SourceDirectory = "${mergedSource}";
            };
            playerbots = {
                PlayerbotsDatabaseInfo = dbInfo "acore_playerbots";
            };
        };

        # Value type for one key of a *Config option: a string or an
        # integer, or a nested attrset of the same to any depth. Nested
        # attrsets are flattened to the dot-separated keys AzerothCore's
        # flat Config::ParseFile expects, so both of these render
        # identically:
        #   worldserverConfig."Visibility.Distance" = 100;
        #   worldserverConfig.Visibility.Distance = 100;
        #   -> Visibility.Distance = 100
        #
        # The element type must be a hand-built option type rather than a
        # built-in:
        # - check is deliberately root-only (the module system warns that
        #   deep checks can force infinite recursion during merging);
        #   renderConf stringifies whatever survives, and AzerothCore
        #   rejects unknown/bogus keys at its own startup.
        # - merge implements the per-key deep merge: each def is unwrapped
        #   from its mkDefault/mkOrder marker, and defs are combined from
        #   lowest to highest precedence (higher mkOrder priority number
        #   == lower precedence; mkDefault = 1000, a plain definition =
        #   defaultOverridePriority). Two attrsets are recursively
        #   merged, so a host overriding one key of a nested set keeps
        #   the default keys of the siblings; scalars use last-wins.
        confElemType = lib.mkOptionType {
            name = "confValue";
            description = "a server config value: a string, an integer, or a nested set of these";
            descriptionClass = "composite";
            check = x:
                builtins.isAttrs x
                || lib.types.str.check x
                || lib.types.int.check x;
            merge = loc: defs:
                let
                    unwrap = d:
                        let v = d.value; in
                        if builtins.isAttrs v && v ? _type && v._type == "override" then
                            { value = v.content; priority = v.priority; }
                        else
                            { value = v; priority = lib.defaultOverridePriority; };
                    deepMergeTwo = a: b:
                        if builtins.isAttrs a && builtins.isAttrs b then
                            lib.recursiveUpdate a b
                        else
                            b;
                in
                builtins.foldl' deepMergeTwo { }
                    (lib.map (u: u.value)
                        (builtins.sort (x: y: y.priority > x.priority)
                            (lib.map unwrap defs)));
        };
        confValueType = lib.types.attrsOf confElemType;

        # Flatten a (possibly nested) key/value attrset to a flat attrset
        # whose keys are dot-joined paths. Nested attrsets become
        # dot-separated key names (the only "nested" concept AzerothCore's
        # flat Config::ParseFile has); everything else is stringified,
        # since every conf value is ultimately a string.
        #   flattenConfValues { a = 1; b = { c = "x"; }; }
        #     == { a = "1"; b.c = "x"; }
        # The recursion works over a list of {name, value} entries; the
        # final listToAttrs happens once, at the top level.
        flattenEntries = attrs:
            builtins.concatMap (name:
                let
                    v = attrs.${name};
                in
                if v != null && builtins.isAttrs v then
                    map (kv: { name = "${name}.${kv.name}"; value = toString kv.value; })
                        (flattenEntries v)
                else
                    [ { inherit name; value = toString v; } ]
            ) (builtins.attrNames attrs);
        flattenConfValues = attrs: builtins.listToAttrs (flattenEntries attrs);

        # Render a key/value attrset into the "Key = Value" lines the
        # servers expect. Keys are emitted in a stable, sensible order
        # (the most-frequently-tuned ones first) with any unknown keys
        # appended alphabetically, so the generated file is predictable
        # and diffs stay readable when a host adds or overrides keys.
        confOrder = [
            "RealmServerPort"
            "WorldServerPort"
            "DataDir"
            "LoginDatabaseInfo"
            "WorldDatabaseInfo"
            "CharacterDatabaseInfo"
            "PlayerbotsDatabaseInfo"
            "LogsDir"
            "TempDir"
            "MySQLExecutable"
            "SourceDirectory"
        ];
        orderedNames = attrs:
            let
                present = builtins.attrNames attrs;
                # Keys we know about, in the curated order above.
                known = builtins.filter (k: builtins.elem k present) confOrder;
                # Anything else (host-added keys), alphabetically.
                unknown = builtins.sort builtins.lessThan
                    (builtins.filter (k: !builtins.elem k confOrder) present)
                ;
            in
            known ++ unknown;
        renderConf = name: attrs:
            let
                # Flatten nested attrsets to their dot-separated key names
                # and stringify values. The flattened keys flow through
                # orderedNames unchanged: known keys keep their curated
                # position, any host-added keys append alphabetically.
                flat = flattenConfValues attrs;
            in
            ''
                # --- generated by nixos-dendritic-system (azerothcore: ${name}) ---
                ${lib.concatStringsSep "\n" (lib.map (k: "${k} = ${flat.${k}}") (orderedNames flat))}
            '';

        # --------------------------------------------------------------
        # Build the servers.
        #
        # - src is a store path, so CMAKE_SOURCE_DIR (baked into
        #   revision.h as _SOURCE_DIRECTORY) is a persistent store path.
        # - APPS_BUILD=all builds authserver + worldserver.
        # - TOOLS_BUILD=db-only builds dbimport (its default is "none",
        #   which would otherwise skip the dbimport tool entirely).
        # - MODULES=static + SCRIPTS=static compile the playerbots module
        #   into the worldserver.
        # --------------------------------------------------------------
        azerothcorePkg =
            if cfg.enable then
                pkgs.stdenv.mkDerivation {
                    pname = "azerothcore-wotlk";
                    version = "17.0.0";

                    src = mergedSource;

                    nativeBuildInputs = [
                        pkgs.cmake
                        pkgs.ninja
                        # Provides mysql_config, which FindMySQL.cmake uses
                        # to locate the MySQL client headers/library.
                        pkgs.mysql84
                    ];

                    buildInputs = [
                        pkgs.boost
                        pkgs.openssl
                        pkgs.mysql84
                        pkgs.readline
                        pkgs.bzip2
                        pkgs.zlib
                    ];

                    # Build in-tree (read-only source is fine: CMake only
                    # writes to the build dir; WITHOUT_GIT avoids needing a
                    # .git directory, which store paths do not have).
                    cmakeFlags = [
                        # String-valued options (CACHE STRING in the core's
                        # conf/dist/config.cmake) are passed as plain -D
                        # strings; lib.cmakeBool only works for booleans.
                        "-DAPPS_BUILD=all"      # build authserver + worldserver
                        "-DTOOLS_BUILD=db-only" # build dbimport (default "none" skips it)
                        "-DSCRIPTS=static"
                        "-DMODULES=static"      # compile the playerbots module in
                        (lib.cmakeBool "BUILD_TESTING" false)
                        (lib.cmakeBool "WITHOUT_GIT" true)  # store paths have no .git
                        (lib.cmakeBool "USE_COREPCH" false)
                        (lib.cmakeBool "USE_SCRIPTPCH" false)
                    ];
                    cmakeBuildType = "RelWithDebInfo";

                    # Install the generated config files next to the
                    # binaries (CONF_DIR == <prefix>/etc).
                    postInstall = ''
                        install -Dm644 ${authserverConf} $out/etc/authserver.conf
                        install -Dm644 ${worldserverConf} $out/etc/worldserver.conf
                        install -Dm644 ${dbimportConf} $out/etc/dbimport.conf
                        ${lib.optionalString cfg.enablePlayerbots ''
                            install -Dm644 ${playerbotsConf} $out/etc/modules/playerbots.conf
                        ''}
                    '';
                }
            else null;

        # The final, user-merged contents of each file, rendered to text.
        # cfg.*Config is the attrset option; merging with the leaf-level
        # lib.mkDefault declarations done in `config` below means a host
        # that overrides one key keeps every other default key.
        authserverConf = pkgs.writeText "authserver.conf"
            (renderConf "authserver" cfg.authserverConfig);
        worldserverConf = pkgs.writeText "worldserver.conf"
            (renderConf "worldserver" cfg.worldserverConfig);
        dbimportConf = pkgs.writeText "dbimport.conf"
            (renderConf "dbimport" cfg.dbimportConfig);
        playerbotsConf = pkgs.writeText "playerbots.conf"
            (renderConf "playerbots" cfg.playerbotsConfig);
    in
    {
        options.services.azerothcore = {
            enable = lib.mkEnableOption "the AzerothCore (WotLK) server with mod-playerbots support";

            enablePlayerbots = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = ''
                    Compile in the mod-playerbots module. This flake fetches
                    the mod-playerbots/azerothcore-wotlk fork, which is
                    required for playerbots; vanilla AzerothCore will not
                    build the module.
                '';
            };

            dataDir = lib.mkOption {
                type = lib.types.path;
                default = "/var/lib/azerothcore/data";
                description = ''
                    Directory holding the WoW WotLK client data (dbc/,
                    maps/, vmaps/, mmaps/). Must be populated manually from
                    a legitimate game client install. Used as the default
                    for worldserverConfig.DataDir.
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

            # ----------------------------------------------------------------
            # Per-file config contents.
            #
            # Each option is the full set of "Key" = "Value" pairs written
            # to the corresponding .conf file. The module provides a
            # complete, working default for every key; a host can override
            # any individual key (or add new ones) without disturbing the
            # rest, e.g.:
            #
            #   services.azerothcore.worldserverConfig.MaxPlayers = "200";
            #   services.azerothcore.worldserverConfig.GM.StartLevel = "50";
            #   services.azerothcore.worldserverConfig.Visibility = {
            #       Distance.Continents = 100;
            #       ObjectSparkles = "1";
            #   };
            #
            # Values are strings or integers. Nested attrsets are flattened
            # to dot-separated keys at render time (the example above
            # becomes Visibility.Distance.Continents = 100).
            # ----------------------------------------------------------------
            authserverConfig = lib.mkOption {
                type = confValueType;
                default = { };
                description = ''
                    Contents of authserver.conf as a set of key/value pairs.
                    See the module source for the shipped defaults
                    (RealmServerPort, LoginDatabaseInfo, LogsDir, TempDir,
                    MySQLExecutable, SourceDirectory).
                '';
            };

            worldserverConfig = lib.mkOption {
                type = confValueType;
                default = { };
                description = ''
                    Contents of worldserver.conf as a set of key/value pairs.
                    See the module source for the shipped defaults
                    (DataDir, WorldServerPort, LoginDatabaseInfo,
                    WorldDatabaseInfo, CharacterDatabaseInfo, LogsDir,
                    TempDir, MySQLExecutable, SourceDirectory).
                '';
            };

            dbimportConfig = lib.mkOption {
                type = confValueType;
                default = { };
                description = ''
                    Contents of dbimport.conf as a set of key/value pairs.
                    See the module source for the shipped defaults
                    (LoginDatabaseInfo, WorldDatabaseInfo,
                    CharacterDatabaseInfo, LogsDir, TempDir,
                    MySQLExecutable, SourceDirectory).
                '';
            };

            playerbotsConfig = lib.mkOption {
                type = confValueType;
                default = { };
                description = ''
                    Contents of modules/playerbots.conf as a set of
                    key/value pairs. See the module source for the shipped
                    default (PlayerbotsDatabaseInfo).
                '';
            };
        };

        config = lib.mkIf cfg.enable {
            assertions = [{
                assertion = cfg.enablePlayerbots;
                message = "services.azerothcore.enablePlayerbots must stay true: this flake fetches the mod-playerbots fork of AzerothCore, and the playerbots module only builds against it.";
            }];

            # ----------------------------------------------------------
            # Default contents for each config file, declared at the
            # *leaf* level (each key individually wrapped in lib.mkDefault)
            # so that a host overriding one key — or adding a new one —
            # keeps every other default key intact. This is the standard
            # NixOS deep-merge behaviour for attrsOf options.
            # ----------------------------------------------------------
            services.azerothcore.authserverConfig =
                lib.mapAttrs (_: v: lib.mkDefault v) mkConfDefaults.authserver;
            services.azerothcore.worldserverConfig =
                lib.mapAttrs (_: v: lib.mkDefault v) mkConfDefaults.worldserver;
            services.azerothcore.dbimportConfig =
                lib.mapAttrs (_: v: lib.mkDefault v) mkConfDefaults.dbimport;
            services.azerothcore.playerbotsConfig =
                lib.mapAttrs (_: v: lib.mkDefault v) mkConfDefaults.playerbots;

            # ----------------------------------------------------------
            # MySQL
            # ----------------------------------------------------------
            services.mysql = {
                enable = true;
                package = pkgs.mysql84;
                settings = {
                    bind-address = "127.0.0.1";
                    mysqld.max_connections = 300;
                };
                ensureDatabases = [
                    "acore_auth"
                    "acore_world"
                    "acore_characters"
                    "acore_playerbots"
                ];
                # nixpkgs creates the user from `name`/`password` and then
                # runs `creationStatement`; the AzerothCore servers connect
                # over TCP to 127.0.0.1, which reverse-resolves to
                # 'localhost', so grant to that host.
                ensureUsers = [{
                    name = cfg.mysqlUser;
                    password = cfg.mysqlPassword;
                    creationStatement = ''
                        GRANT ALL PRIVILEGES ON acore_auth.* TO '${cfg.mysqlUser}'@'localhost';
                        GRANT ALL PRIVILEGES ON acore_world.* TO '${cfg.mysqlUser}'@'localhost';
                        GRANT ALL PRIVILEGES ON acore_characters.* TO '${cfg.mysqlUser}'@'localhost';
                        GRANT ALL PRIVILEGES ON acore_playerbots.* TO '${cfg.mysqlUser}'@'localhost';
                    '';
                }];
            };

            # ----------------------------------------------------------
            # Runtime user + writable directories
            # ----------------------------------------------------------
            users.users.${cfg.user} = {
                isSystemUser = true;
                group = cfg.user;
                home = "/var/lib/azerothcore";
            };
            users.groups.${cfg.user} = { };

            systemd.tmpfiles.rules = [
                "d /var/lib/azerothcore 0750 ${cfg.user} ${cfg.user} - -"
                "d /var/lib/azerothcore/logs 0750 ${cfg.user} ${cfg.user} - -"
                "d /var/lib/azerothcore/data 0750 ${cfg.user} ${cfg.user} - -"
                "d /var/lib/azerothcore/data/dbc 0750 ${cfg.user} ${cfg.user} - -"
                "d /var/lib/azerothcore/data/maps 0750 ${cfg.user} ${cfg.user} - -"
                "d /var/lib/azerothcore/data/vmaps 0750 ${cfg.user} ${cfg.user} - -"
                "d /var/lib/azerothcore/data/mmaps 0750 ${cfg.user} ${cfg.user} - -"
            ];

            # ----------------------------------------------------------
            # Services
            # ----------------------------------------------------------
            systemd.services = {
                azerothcore-dbimport = {
                    description = "AzerothCore database import (auth/world/characters)";
                    wantedBy = [ "multi-user.target" ];
                    after = [ "network.target" "mysql.service" ];
                    wants = [ "mysql.service" ];
                    # Hash-based and idempotent — cheap to re-run every
                    # boot, keeps the DBs in sync with source updates.
                    # NOTE: dbimport only seeds Login/Character/World; the
                    # playerbots DB is created + populated by the
                    # worldserver (the mod-playerbots module runs its own
                    # DB updater during OnDatabasesLoading).
                    serviceConfig = {
                        Type = "oneshot";
                        User = cfg.user;
                        Environment = [
                            # Databases are pre-created by NixOS; never
                            # block on an interactive prompt.
                            "AC_DISABLE_INTERACTIVE=1"
                        ];
                    };
                    path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                    script = ''
                        ${lib.getExe' azerothcorePkg "dbimport"}
                    '';
                };

                azerothcore-authserver = {
                    description = "AzerothCore auth server";
                    wantedBy = [ "multi-user.target" ];
                    after = [ "network.target" "mysql.service" "azerothcore-dbimport.service" ];
                    wants = [ "mysql.service" ];
                    restartIfChanged = true;
                    serviceConfig = {
                        User = cfg.user;
                        Environment = [ "AC_DISABLE_INTERACTIVE=1" ];
                        Restart = "on-failure";
                        RestartSec = "5";
                    };
                    path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                    script = ''
                        ${lib.getExe' azerothcorePkg "authserver"}
                    '';
                };

                azerothcore-worldserver = {
                    description = "AzerothCore world server (WotLK, mod-playerbots)";
                    wantedBy = [ "multi-user.target" ];
                    after = [ "network.target" "mysql.service" "azerothcore-authserver.service" ];
                    wants = [ "mysql.service" ];
                    restartIfChanged = true;
                    serviceConfig = {
                        User = cfg.user;
                        # The WotLK worldserver opens thousands of
                        # map/DB handles.
                        LimitNOFILE = 16384;
                        Environment = [ "AC_DISABLE_INTERACTIVE=1" ];
                        Restart = "on-failure";
                        RestartSec = "10";
                        # First start populates the playerbots DB and
                        # loads all maps; allow a generous start timeout.
                        TimeoutStartSec = "600";
                    };
                    path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                    script = ''
                        ${lib.getExe' azerothcorePkg "worldserver"}
                    '';
                };
            };

            networking.firewall = lib.mkIf cfg.openFirewall {
                allowedTCPPorts = [ cfg.authPort cfg.worldPort ];
            };

            environment.systemPackages = [
                pkgs.mysql84 # convenient for manual DB work
            ];
        };
    };
}
