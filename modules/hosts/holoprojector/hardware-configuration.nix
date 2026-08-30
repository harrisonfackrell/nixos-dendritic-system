{ config, lib, pkgs, modulesPath, ... }: {
    flake.nixosModules.holoprojectorHardware = { config, modulesPath, pkgs, lib, ... }: {
        imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

        boot.initrd.availableKernelModules = [ "nvme" "xhci_pci_prom21" "ahci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sr_mod" ];
        boot.initrd.kernelModules = [ ];
        boot.kernelModules = [ "kvm-amd" ];
        boot.extraModulePackages = [ ];

        fileSystems."/" = {
            device = "/dev/disk/by-uuid/fe708bcc-7e10-4e2c-af15-144b3b744e7a";
            fsType = "ext4";
        };

        fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/0B21-F039";
            fsType = "vfat";
            options = [ "fmask=0077" "dmask=0077" ];
        };

        swapDevices =[{ device = "/dev/disk/by-uuid/632d782f-0e96-4e13-8caf-87ce148db6cc"; }];

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
