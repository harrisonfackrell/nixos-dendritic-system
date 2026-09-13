{ self, inputs, ... }:
{
    flake.nixosModules.jediarchivesConfiguration = { config, lib, pkgs, modulesPath, ... }: {
        imports = [
            self.nixosModules.jediarchivesHardware
            self.nixosModules.searx
        ];

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
        };

        nixpkgs.config.allowUnfree = true;

        users.users.obiwanshinobi = {
            isNormalUser = true;
            description = "ObiwanShinobi";
            extraGroups = [ "networkmanager" "wheel" ];
        };

        services.open-webui = {
            enable = true;
            port = 8080;
            host = "0.0.0.0";
            openFirewall = true;
            environment = {
                # Public URL the instance is reached at; used for OAuth and
                # self-referencing links.
                WEBUI_URL = "https://khetanna.party";
            };
        };

        environment.systemPackages = [ pkgs.git ];

        time.timeZone = "America/Denver";
        system.stateVersion = "25.11";
    };
}
