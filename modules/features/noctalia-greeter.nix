{ self, inputs, ... }: {
    flake.nixosModules.noctaliaGreeter = { config, pkgs, lib, ... }: {
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
    };
}