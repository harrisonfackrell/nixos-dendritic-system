{ self, inputs, homeManager, ... }: {
    flake.homeModules.foot = { config, pkgs, lib, ... }: {
        programs.foot = {
            enable = true;
            settings = {
                main = {
                    dpi-aware = "yes";
                };
                colors-dark = {
                    alpha = 0.8;
                    alpha-mode = "all";
                };
            };
        };
    };
}