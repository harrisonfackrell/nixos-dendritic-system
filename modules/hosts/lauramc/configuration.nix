{ self, inputs, ... }: {
    flake.nixosModules.lauramcConfiguration = { config, lib, pkgs, modulesPath, ... }: {
        imports = [
            self.nixosModules.lauramcHardware
            self.nixosModules.lauramcMinecraft
            inputs.nix-minecraft.nixosModules.minecraft-servers
            {
                nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
            }
        ];

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
        };

        nixpkgs.config.allowUnfree = true;

        users.users.obiwanshinobi = {
            isNormalUser = true;
            description = "ObiwanShinobi";
            extraGroups = [ "networkmanager" "wheel" ];
        };

        services.openssh = {
            enable = true;
            openFirewall = true;
        };

        system.stateVersion = "25.05";
    };
}
