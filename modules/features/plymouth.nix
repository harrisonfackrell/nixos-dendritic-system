{ self, inputs, ... }: {
    flake.nixosModules.plymouth = { pkgs, lib, ... }: {
        imports = [
            inputs.stylix.nixosModules.stylix
        ];
        boot = {
            plymouth.enable = true;
            consoleLogLevel = 3;
            kernelParams = [
                "quiet"
                "rd.udev.log_level=3"
                "rd.systemd.show_status=auto"
            ];
        };
        stylix = {
            enable = true;
            targets = {
                plymouth.enable = true;
                regreet.enable = true;
            };
            icons = {
                enable = true;
                package = pkgs.kdePackages.breeze-icons;
                light = "breeze";
                dark = "breeze-dark";
            };
            cursor = {
                name = "macOS";
                package = pkgs.apple-cursor;
                size = 24;
            };
            image = "${pkgs.nixos-artwork.wallpapers.catppuccin-mocha.src}";
            imageScalingMode = "fill";
            polarity = "dark";
            homeManagerIntegration.autoImport = false;
        };
    };
}