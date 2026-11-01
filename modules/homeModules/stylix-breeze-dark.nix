{ inputs, ... }: {
    flake.homeModules.stylix-breeze-dark = { config, pkgs, lib, ... }: {
        imports = [
            inputs.stylix.homeModules.stylix
        ];
        stylix = {
            enable = true;
            targets = {
                qt.enable = true;
                noctalia-shell.enable = true;
                fuzzel.enable = true;
                foot.enable = true;
                regreet.enable = true;
                swaylock = {
                    enable = true;
                    image.override = "${pkgs.nixos-artwork.wallpapers.catppuccin-latte.src}";
                };
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
            opacity.terminal = 0.8;
            image = "${pkgs.nixos-artwork.wallpapers.catppuccin-mocha.src}";
            imageScalingMode = "fill";
            polarity = "dark";
        };
    };
}
