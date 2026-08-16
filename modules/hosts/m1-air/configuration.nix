{ self, inputs, ... }: {
    flake.nixosModules.m1AirConfiguration = { config, lib, pkgs, ... }: {
        imports = [
            self.nixosModules.m1AirHardware
            self.nixosModules.mangowc
            self.nixosModules.firefox
            self.nixosModules.plymouth
            inputs.apple-silicon.nixosModules.apple-silicon-support
            inputs.home-manager.nixosModules.home-manager
        ];

        nixpkgs.config.allowUnfree = true;

        nix.settings = {
            extra-substituters = [
                "https://nixos-apple-silicon.cachix.org"
            ];
            extra-trusted-public-keys = [
                "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
            ];
            experimental-features = [ "nix-command" "flakes" ];
        };

        networking = {
            hostName = "nixos";
            networkmanager = {
                enable = true;
                wifi.backend = "iwd";
            };
        };

        time.timeZone = "America/Denver";

        services.displayManager = {
            sddm = {
                enable = true;
                wayland = {
                    enable = true;
                    compositor = "kwin";
                };
                theme = "${pkgs.sddm-astronaut}/share/sddm/themes/sddm-astronaut-theme";
                extraPackages = with pkgs; [
                    qt6.qtmultimedia
                    apple-cursor
                ];
                settings = {
                    Theme = {
                        CursorTheme = "macOS";
                        Size = 24;
                    };
                };
            };
        };

        programs.dconf.enable = true;

        environment.plasma6.excludePackages = with pkgs.kdePackages; [
            aurorae
            plasma-browser-integration
            plasma-workspace-wallpapers
            konsole
            kwin-x11
            ark
            elisa
            gwenview
            okular
            kate
            ktexteditor # provides elevated actions for kate
            khelpcenter
            dolphin
            baloo-widgets # baloo information in Dolphin
            dolphin-plugins
            spectacle
            ffmpegthumbs
            krdp
        ];

        users.users.obiwanshinobi = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            packages = with pkgs; [
            
            ];
        };

        environment.systemPackages = with pkgs; [
            neovim
            wget
            vscodium
            git
            libreoffice
            nodejs
            sqlite
            python3
            gnumake
            gcc
            vlc
            lsof
        ];

        system.stateVersion = "25.11";

        home-manager = {
            useUserPackages = true;
            extraSpecialArgs = { inherit self inputs; };
            users.obiwanshinobi = {
                imports = [
                    self.homeModules.noctalia
                ];
                home.stateVersion = config.system.stateVersion;
            };
        };
    };
}
