{ self, inputs, ... }: {
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
                    { action = "lock"; command = "${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.neoswaylock}"; }
                    { action = "suspend"; lock_before_suspend = false; command = "${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.neoswaylock} & noctalia msg session suspend"; }
                    { action = "shutdown"; }
                    { action = "logout"; command = "uwsm stop"; }
                    { action = "reboot"; }
                ];
            };
        };

        home.packages = with pkgs; [
            inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
    };
}
