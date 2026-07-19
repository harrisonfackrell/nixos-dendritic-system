{ self, inputs, ... }: {
    flake.nixosModules.geonosisfoundryHardware = { config, modulesPath, pkgs, lib, ... }: {
        import = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

        nix.settings = {
            sandbox = false;
        };

        proxmoxLXC = {
            manageNetwork = false;
            privileged = false;
        };

        services.fstrim.enable = false; # Let Proxmox host handle fstrim

        hardware.graphics.enable = true;

        environment.systemPackages = with pkgs; [
            pciutils
            vulkan-tools
            rocmPackages.rocminfo
            rocmPackages.rocm-smi
        #    llama-cpp-vulkan
        ];
    }
}
