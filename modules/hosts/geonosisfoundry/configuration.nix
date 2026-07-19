{ self, inputs, ... }: {
    flake.nixosModules.geonosisfoundryConfiguration = { config, lib, pkgs, modulesPath, ... }: {
        imports = [
            self.nixosModules.geonosisfoundryHardware
            self.nixosModules.llamaswap
            inputs.nix-amd-ai.nixosModules.default
        ];

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
        };

        nixpkgs.config.allowUnfree = true;

        networking = {
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
            pciutils
            vulkan-tools
            rocmPackages.rocminfo
            rocmPackages.rocm-smi
        ];

        system.stateVersion = "25.05";
    };
}
