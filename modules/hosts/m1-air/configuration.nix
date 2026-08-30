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
                        moonlight
                    ];
                    stateVersion = config.system.stateVersion;
                };
            };
        };

        programs.dconf.enable = true; #Necessary for Stylix

        users.users.obiwanshinobi = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
        };

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
                ];
            };
        };

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

        system.stateVersion = "25.11";
    };
}
