{ self, inputs, ... }: {
    flake.nixosModules.noctaliaGreeter = { pkgs, lib, ... }: {
        services.displayManager.noctalia-greeter = {
            enable = true;
            cursorTheme = {
                name = "macOS";
                package = pkgs.apple-cursor;
            };
            settings = {
                cursor = {
                    size = 24;
                };
                appearance = {
                    hide_logo = true;
                };
            };
        };
    };
}