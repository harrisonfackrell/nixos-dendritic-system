{ self, inputs, ... }: {
    flake.nixosModules.m1AirHardware = { config, lib, pkgs, modulesPath, ... }: {
        imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

        boot.initrd.availableKernelModules = [ "usb_storage" ];
        boot.initrd.kernelModules = [ ];
        boot.kernelModules = [ ];
        boot.extraModulePackages = [ ];
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = false;

        hardware.asahi.enable = true;

        hardware.asahi.peripheralFirmwareDirectory = /boot/vendorfw;

        fileSystems."/" = {
            device = "/dev/disk/by-uuid/679237a9-1b36-4c82-a180-4d655c3e3717";
            fsType = "ext4";
        };

        fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/866C-13F9";
            fsType = "vfat";
            options = [ "fmask=0022" "dmask=0022" ];
        };

        swapDevices = [
            { device = "/swapfile"; size = 8 * 1024; }
        ];

        nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
    };
}