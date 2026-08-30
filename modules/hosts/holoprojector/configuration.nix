{ self, inputs, ... }: {
    flake.nixosModules.holoprojectorConfiguration = { config, lib, pkgs, ... }: {
        imports = [
            self.nixosModules.holoprojectorHardware
            self.nixosModules.mangowc
            self.nixosModules.firefox
            self.nixosModules.plymouth
            inputs.home-manager.nixosModules.home-manager
        ];

        home-manager = {
            useUserPackages = true;
            extraSpecialArgs = { inherit self inputs; };
            users.obiwanshinobi = {
                imports = [
                    self.homeModules.noctalia
                    self.homeModules.stylix-breeze-dark
                ];
                home.stateVersion = config.system.stateVersion;
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
            hostName = "nixos";
            networkmanager = {
                enable = true;
                wifi.backend = "iwd";
            };
        };

        time.timeZone = "America/Denver";

        system.stateVersion = "26.05";
    };
}
