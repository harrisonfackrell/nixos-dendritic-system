{ self, inputs, ... }:
{
    flake.nixosModules.openwebui = { config, lib, pkgs, ... }: {
        services.open-webui = {
            enable = true;
            port = 8080;
            host = "0.0.0.0";
            openFirewall = true;
        };
    };
}
