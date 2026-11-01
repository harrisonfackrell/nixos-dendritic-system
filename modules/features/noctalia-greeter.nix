{ self, inputs, ... }: {
    flake.nixosModules.noctaliaGreeter = { config, pkgs, lib, ... }: {
        imports = [
            inputs.stylix.nixosModules.stylix
        ];
        services.displayManager.noctalia-greeter = {
            enable = true;
            cursorTheme = {
                name = "macOS";
                package = pkgs.apple-cursor;
            };
            settings = {
                session.default = "Mango (UWSM)";
                appearance = {
                    palette = "Catppuccin";
                    wallpaper.path = "${pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha-alt.src}";
                    hide_logo = true;
                };
                cursor = {
                    size = 24;
                };
            };
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