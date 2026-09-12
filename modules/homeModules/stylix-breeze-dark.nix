{ inputs, ... }: {
    flake.homeModules.stylix-breeze-dark = { config, pkgs, lib, ... }: {
        imports = [
            inputs.stylix.homeModules.stylix
        ];
        stylix = {
            enable = true;
            targets.qt.enable = true;
            targets.noctalia-shell.enable = true;
            #targets.noctalia-greeter.enable = true; (Stylix PR 2490; coming soon)
            targets.fuzzel.enable = true;
            targets.foot.enable = true;
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
