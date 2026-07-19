{ self, inputs, ... }: {
    flake.nixosModules.geonosisfoundryConfiguration = { config, lib, pkgs, modulesPath, ... }: {
        imports = [
            self.nixosModules.geonosisfoundryHardware
            inputs.nix-amd-ai.nixosModules.amd-ai
        ];

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
        };

        nixpkgs.config.allowUnfree = true;

        networking = {
            hostName = "geonosisfoundry";
            networkmanager.enable = true;
            nftables.enable = true;
        };

        users.users.obiwanshinobi = {
            isNormalUser = true;
            description = "ObiwanShinobi";
            extraGroups = [ "networkmanager" "wheel" "video" "render" "root" ];
        };

        time.timeZone = "America/Denver";

        environment.systemPackages = with pkgs; [
            neovim
            wget
            git
            htop
        ];

        system.stateVersion = "25.05";
    };
}
