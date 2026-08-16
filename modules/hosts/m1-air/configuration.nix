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

        services = {
            # desktopManager.plasma6.enable = true;
            displayManager.plasma-login-manager.enable = true;
        };

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
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit self inputs; };
            users.obiwanshinobi = {
                home.stateVersion = config.system.stateVersion;

                imports = [
                    inputs.noctalia.homeModules.default
                ];

                programs.noctalia.enable = true;
                programs.noctalia.settings = {
                    wallpaper = {
                        enabled = false;
                    };
                    widget.clock-12h = {
                        type   = "clock";
                        format = "{:%-I:%M %p}";
                    };
                    bar.default = {
                        radius = 0;
                        reserve_space = true;
                        margin_ends = 0;
                        start = [ "launcher" "workspaces" ];
                        center = [ "clock-12h" ];
                    };
                    shell = {
                        font = "JetBrainsMono Nerd Font";
                        settings_show_advanced = true;
                        session.actions = [
                            { action = "lock"; command = "${pkgs.swaylock}/bin/swaylock"; }
                            { action = "suspend"; command = "systemctl suspend"; }
                            { action = "shutdown"; command = "systemctl poweroff"; }
                            { action = "logout"; command = "uwsm stop"; }
                            { action = "reboot"; command = "systemctl reboot"; }
                        ];
                    };
                    theme = {
                        mode = "dark";
                        source = "builtin";
                        builtin = "Catppuccin";
                    };
                };

                home.packages = with pkgs; [
                    neovim
                    git
                    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
                ];
            };
        };
    };
}
