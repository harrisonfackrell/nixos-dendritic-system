{ self, inputs, homeManager, ... }: {
    flake.homeModules.fuzzel = { config, pkgs, lib, ... }: {
        programs.fuzzel = {
            enable = true;
            settings = {
                main = {
                    dpi-aware = "no";
                    launch-prefix = "uwsm app --";
                };
            };
        };
    };
}