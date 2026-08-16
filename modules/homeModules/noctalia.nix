{ self, inputs, ... }: {
    flake.homeModules.noctalia = { config, pkgs, lib, ... }: {
        imports = [
            inputs.noctalia.homeModules.default
            inputs.stylix.homeModules.stylix
        ];

        nixpkgs.config.allowUnfree = true;

        programs.noctalia.enable = true;
        programs.noctalia.settings = {
            wallpaper = {
                enabled = false;
            };
            widget.clock-12h = {
                type   = "clock";
                format = "{:%-I:%M %p}";
            };
            bar.default = {
                radius = 0;
                reserve_space = true;
                margin_ends = 0;
                start = [ "launcher" "workspaces" ];
                center = [ "clock-12h" ];
            };
            shell = {
                font = "JetBrainsMono Nerd Font";
                settings_show_advanced = true;
                session.actions = [
                    { action = "lock"; command = "${pkgs.swaylock}/bin/swaylock"; }
                    { action = "suspend"; command = "systemctl suspend"; }
                    { action = "shutdown"; command = "systemctl poweroff"; }
                    { action = "logout"; command = "uwsm stop"; }
                    { action = "reboot"; command = "systemctl reboot"; }
                ];
            };
        };

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

        home.packages = with pkgs; [
            neovim
            git
            inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
    };
}
