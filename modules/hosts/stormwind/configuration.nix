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
            enablePlayerbots = true;
            # Expose auth (3724), world (8085) and SOAP (8089) to the LAN
            openFirewall = true;
            # Example of custom tuning:
            # extraWorldConf = [
            #     "GM.StartLevel = 50"
            # ];
        };

        system.stateVersion = "25.05";
    };
}
