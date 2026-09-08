{ self, inputs, ... }: {
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
            # Modules are keyed by the directory they're installed as
            # (modules/<name>/). `database` ensures the MySQL database and
            # generates the module's <Base>DatabaseInfo conf key. The core
            # source defaults to the mod-playerbots/azerothcore-wotlk
            # `Playerbot` branch flake input; point `source.src` at a
            # fetchFromGitHub to substitute another fork.
            modules = {
                mod-playerbots = {
                    src = inputs.playerbots;
                    database = "acore_playerbots";
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
