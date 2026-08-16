{ inputs, ... }: {
    flake.homeManagerModules.stylix-breeze-dark = { config, pkgs, lib, ... }: {
        imports = [
            inputs.stylix.homeModules.stylix
        ];

        stylix = {
            enable = true;
            targets.qt.colors.enable = false;
            targets.noctalia-shell.enable = true;
            icons = {
                enable = true;
                package = pkgs.kdePackages.breeze-icons;
                light = "breeze";
                dark = "breeze-dark";
            };
            cursor = {
                name = "breeze_cursors";
                package = pkgs.kdePackages.breeze;
                size = 24;
            };
            image = "${pkgs.fetchurl {
                url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/refs/heads/master/wallpapers/nixos-wallpaper-catppuccin-mocha.png";
                hash = "sha256-fmKFYw2gYAYFjOv4lr8IkXPtZfE1+88yKQ4vjEcax1s=";
            }}";
            polarity = "dark";
        };

        qt.style.name = lib.mkForce "adwaita-dark";
    };
    
}
