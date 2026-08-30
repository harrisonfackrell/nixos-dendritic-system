{ self, inputs, ... }: {
    flake.nixosModules.holoprojectorConfiguration = { config, lib, pkgs, ... }: {
        imports = [
            self.nixosModules.holoprojectorHardware
            self.nixosModules.mangowc
            self.nixosModules.firefox
            self.nixosModules.plymouth
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

        services = {
            desktopManager.plasma6.enable = true;
            displayManager = {
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
        };

        nixpkgs.config.allowUnfree = true;

        networking = {
            hostName = "holoprojector";
            networkmanager = {
                enable = true;
                wifi.backend = "iwd";
            };
        };

        time.timeZone = "America/Denver";

        system.stateVersion = "26.05";
    };
}
