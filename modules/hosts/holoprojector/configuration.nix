{ self, inputs, ... }: {
    flake.nixosModules.holoprojectorConfiguration = { config, lib, pkgs, ... }: {
        imports = [
            self.nixosModules.holoprojectorHardware
            self.nixosModules.mangowc
            self.nixosModules.firefox
            self.nixosModules.plymouth
            self.nixosModules.noctaliaGreeter
            self.nixosModules.azerothcore
            inputs.home-manager.nixosModules.home-manager
        ];

        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        boot.kernelPackages = pkgs.linuxPackages_latest;

        home-manager = {
            useUserPackages = true;
            extraSpecialArgs = { inherit self inputs; };
            backupFileExtension = ".hmbak";
            users.obiwanshinobi = {
                imports = [
                    self.homeModules.noctalia
                    self.homeModules.stylix-breeze-dark
                ];
                home = {
                    packages = with pkgs; [
                        neovim
                        wget
                        vscodium
                        git
                        gimp
                        libreoffice
                        nodejs
                        sqlite
                        python3
                        gnumake
                        gcc
                        vlc
                        lsof
                        discord
                        moonlight-qt
                        jellyfin-desktop
                    ];
                    stateVersion = config.system.stateVersion;
                };
            };
        };

        programs.dconf.enable = true; # Necessary for Stylix

        users.users.obiwanshinobi = {
            isNormalUser = true;
            description = "ObiwanShinobi";
            extraGroups = [ "networkmanager" "wheel" "video" "render" ];
        };

        nixpkgs.config.allowUnfree = true;

        networking = {
            hostName = "holoprojector";
            networkmanager = {
                enable = true;
                wifi.backend = "iwd";
            };
        };

        # services.openssh = {
        #     enable = true;
        #     openFirewall = true;
        #     settings = {
        #         PermitRootLogin = "no";
        #         AllowUsers = [ "obiwanshinobi" ];
        #     };
        # };

        services.azerothcore = {
            enable = true;
            # Expose auth (3724) and world (8085) to the LAN
            openFirewall = true;
            # Substitute the mod-playerbots fork of the core (latest commit
            # of its `Playerbot` branch, pinned with a content hash) for the
            # module's upstream azerothcore/azerothcore-wotlk default.
            # source = {
            #     src = pkgs.fetchFromGitHub {
            #         owner = "mod-playerbots";
            #         repo = "azerothcore-wotlk";
            #         rev = "06234df3d5ab26c93f4f1f06f3edb828b73ecd3c";
            #         hash = "sha256-0cCscmspZLqt9WtULVUph2aoA/lWW9eZb19sG4n+HtI=";
            #     };
            # };
            # Modules are keyed by the directory they're installed as
            # (modules/<name>/). `database` only provisions the MySQL
            # database; the connection string is a plain conf key written in
            # `configFiles` below, built with the module's `dbInfo` helper.
            # modules = {
            #     mod-playerbots = {
            #         # Latest commit of mod-playerbots/mod-playerbots,
            #         # pinned with a content hash.
            #         src = pkgs.fetchFromGitHub {
            #             owner = "mod-playerbots";
            #             repo = "mod-playerbots";
            #             rev = "b6696bdbd3740e575598d167d69f39f68cc0b907";
            #             hash = "sha256-xN4I8VIxZ3JebR4jZ6OpsBuxqg4E3vzRNeGOLtwo35U=";
            #         };
            #         database = "acore_playerbots";
            #         # The module's conf file (the key must match its
            #         # conf/playerbots.conf.dist), holding the connection
            #         # string for the database above.
            #         configFiles = {
            #             playerbots.conf = {
            #                 PlayerbotsDatabaseInfo = config.services.azerothcore.dbInfo "acore_playerbots";
            #             };
            #         };
            #     };
            # };
            # Example of custom tuning — each .conf file is an attrset
            # option; override a key or add new ones without touching the
            # module's defaults:
            # worldserverConfig = {
            #     MaxPlayers = "200";
            #     "GM.StartLevel" = "50";
            # };
        };

        networking.firewall = {
            enable = true;
            allowedTCPPorts = [ 3000 ];
        };

        time.timeZone = "America/Denver";

        system.stateVersion = "26.05";
    };
}
