{ self, inputs, ... }: {
    flake.nixosModules.plymouth = { pkgs, lib, ... }: {
        boot = {
            plymouth.enable = true;
            consoleLogLevel = 3;
            initrd.verbose = false;
            kernelParams = [
                "quiet"
                "rd.udev.log_level=3"
                "rd.systemd.show_status=auto"
            ];
        };
    };
}