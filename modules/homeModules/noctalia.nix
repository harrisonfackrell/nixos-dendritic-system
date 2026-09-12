{ self, inputs, homeManager, ... }: {
    flake.homeModules.noctalia = { config, pkgs, lib, ... }: {
        imports = [
            inputs.noctalia.homeModules.default
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
                session.actions = [
                    { action = "lock"; command = "swaylock"; }
                    { action = "suspend"; lock_before_suspend = false; command = "swaylock & noctalia msg session suspend"; }
                    { action = "shutdown"; }
                    { action = "logout"; command = "uwsm stop"; }
                    { action = "reboot"; }
                ];
            };
        };
        programs.fuzzel = {
            enable = true;
            settings = {
                main = {
                    dpi-aware = "yes";
                    launch-prefix = "uwsm app --";
                };
            };
        };
        programs.swaylock.enable = true;
        programs.foot.enable = true;
        home.packages = with pkgs; [
            inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
    };
}
