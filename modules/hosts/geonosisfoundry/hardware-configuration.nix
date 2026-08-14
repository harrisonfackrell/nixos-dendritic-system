{ self, inputs, ... }: {
    flake.nixosModules.geonosisfoundryHardware = { config, modulesPath, pkgs, lib, ... }: {
        imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

        nix.settings = {
            sandbox = false;
        };

        proxmoxLXC = {
            manageNetwork = false;
            privileged = false;
        };

        services.fstrim.enable = false; # Let Proxmox host handle fstrim

        hardware.graphics = {
            enable = true;
            enable32Bit = true;
        };

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
