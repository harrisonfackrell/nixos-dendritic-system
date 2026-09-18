{ self, ... }: {
    flake.nixosModules.stormwindConfiguration = { config, lib, pkgs, modulesPath, ... }: {
        imports = [
            self.nixosModules.stormwindHardware
            self.nixosModules.azerothcore
        ];

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
        };

        nixpkgs.config.allowUnfree = true;

        networking = {
            hostName = "stormwind";
            nftables.enable = true;
        };

        time.timeZone = "America/Denver";

        environment.systemPackages = with pkgs; [
            git
            htop
            wget
        ];

        # ----------------------------------------------------------------
        # AzerothCore (WotLK) + mod-playerbots
        # ----------------------------------------------------------------
        # See ./README.md for the one-time manual step of copying the
        # WoW WotLK client data (dbc/maps/vmaps/mmaps) into
        # /var/lib/azerothcore/data before the worldserver will start.
        services.azerothcore = {
            enable = true;
            # Expose auth (3724) and world (8085) to the LAN
            openFirewall = true;
            # Substitute the mod-playerbots fork of the core (latest commit
            # of its `Playerbot` branch, pinned with a content hash) for the
            # module's upstream azerothcore/azerothcore-wotlk default.
            source = {
                src = pkgs.fetchFromGitHub {
                    owner = "mod-playerbots";
                    repo = "azerothcore-wotlk";
                    rev = "06234df3d5ab26c93f4f1f06f3edb828b73ecd3c";
                    hash = "sha256-95w0z0fcvoiKxgCzEqVKScy1ozJsFHnTd0xX8TYjA9U";
                };
            };
            # Modules are keyed by the directory they're installed as
            # (modules/<name>/). `database` only provisions the MySQL
            # database; the connection string is a plain conf key written in
            # `configFiles` below, built with the module's `dbInfo` helper.
            modules = {
                mod-playerbots = {
                    # Latest commit of mod-playerbots/mod-playerbots,
                    # pinned with a content hash.
                    src = pkgs.fetchFromGitHub {
                        owner = "mod-playerbots";
                        repo = "mod-playerbots";
                        rev = "b6696bdbd3740e575598d167d69f39f68cc0b907";
                        hash = "sha256-4VGXpaiAx3s16ZHAxgdk3rfLAQsV3OCrGSJgAUYBaIc";
                    };
                    database = "acore_playerbots";
                    # The module's conf file (the key must match its
                    # conf/playerbots.conf.dist), holding the connection
                    # string for the database above.
                    configFiles = {
                        playerbots.conf = {
                            PlayerbotsDatabaseInfo = config.services.azerothcore.dbInfo "acore_playerbots";
                        };
                    };
                };
            };
            # Example of custom tuning — each .conf file is an attrset
            # option; override a key or add new ones without touching the
            # module's defaults:
            # worldserverConfig = {
            #     MaxPlayers = "200";
            #     "GM.StartLevel" = "50";
            # };
        };

        system.stateVersion = "25.05";
    };
}
