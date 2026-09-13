{ self, inputs, ... }:
{
    flake.nixosModules.sitharchivesConfiguration = { config, lib, pkgs, modulesPath, ... }: {
        imports = [
            self.nixosModules.sitharchivesHardware
            # self.nixosModules.searx
            self.nixosModules.openwebui
            self.nixosModules.sillytavern
        ];

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
        };

        nixpkgs.config.allowUnfree = true;

        networking = {
            hostName = "sitharchives";
        };

        users.users.obiwanshinobi = {
            isNormalUser = true;
            description = "ObiwanShinobi";
            extraGroups = [ "networkmanager" "wheel" ];
        };

        services.openssh = {
            enable = true;
            openFirewall = true;
        };

        time.timeZone = "America/Denver";

        system.stateVersion = "25.11";
    };
}
