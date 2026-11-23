{ inputs, ... }: {
    flake.darwinModules.workMacConfiguration = { pkgs, ... }: {
        imports = [
            inputs.home-manager.darwinModules.home-manager
        ];

        nixpkgs.hostPlatform = "aarch64-darwin";

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
            always-allow-substitutes = true;
            bash-prompt-prefix = "(nix:$name)\\040";
            extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
        };

        # Keep the installer's system-wide shell files and existing user config.
        programs.bash.enable = false;
        programs.zsh.enable = false;

        # Leave macOS and work-managed SSH configuration untouched.
        services.openssh.hostKeys = [ ];
        environment.etc."ssh/ssh_config.d/100-nix-darwin.conf".enable = false;
        environment.etc."ssh/sshd_config.d/100-nix-darwin.conf".enable = false;
        environment.etc."ssh/sshd_config.d/101-authorized-keys.conf".enable = false;

        users.users."harrison.fackrell".home = "/Users/harrison.fackrell";
        system.primaryUser = "harrison.fackrell";
        system.stateVersion = 6;

        home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users."harrison.fackrell" = {
                home.packages = with pkgs; [
                    bashInteractive
                    devenv
                ];
                home.stateVersion = "26.05";
            };
        };
    };
}
