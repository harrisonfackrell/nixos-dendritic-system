{ self, inputs, ... }: {
    flake.nixosModules.terrariaConfiguration = { config, lib, pkgs, modulesPath, ... }: {
        imports = [
            self.nixosModules.terrariaHardware
            self.nixosModules.terrariaServer
        ];

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
        };

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
