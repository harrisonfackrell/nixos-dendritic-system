{ self, inputs, ... }: {
    flake.nixosModules.holoprojectorConfiguration = { config, lib, pkgs, ... }: {
        imports = [
            self.nixosModules.holoprojectorHardware
            self.nixosModules.mangowc
            self.nixosModules.firefox
            self.nixosModules.plymouth
            self.nixosModules.noctaliaGreeter
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

        services.openssh = {
            enable = true;
            openFirewall = true;
            settings = {
                PermitRootLogin = "no";
                AllowUsers = [ "obiwanshinobi" ];
            };
        };

        networking.firewall = {
            enable = true;
            allowedTCPPorts = [ 3000 ];
        };

        time.timeZone = "America/Denver";

        system.stateVersion = "26.05";
    };
}
