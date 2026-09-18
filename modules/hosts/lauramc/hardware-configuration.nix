{ self, inputs, ... }: {
    flake.nixosModules.lauramcHardware = { config, modulesPath, pkgs, lib, ... }: {
        imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

        nix.settings = {
            sandbox = false;
        };

        proxmoxLXC = {
            manageNetwork = false;
            privileged = false;
        };

        services.fstrim.enable = false; # Let Proxmox host handle fstrim

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
