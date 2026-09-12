{ inputs, ... }: {
    flake.homeModules.stylix-breeze-dark = { config, pkgs, lib, ... }: {
        imports = [
            inputs.stylix.homeModules.stylix
        ];
        stylix = {
            enable = true;
            targets.qt.colors.enable = true;
            targets.noctalia-shell.enable = true;
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
            polarity = "dark";
        };
    };
}
