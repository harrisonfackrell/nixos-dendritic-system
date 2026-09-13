{ self, inputs, ... }:
{
    flake.nixosModules.sillytavern = { config, lib, pkgs, ... }: {
        services.sillytavern = {
            enable = true;
            port = 8000;
            configFile = "/etc/nixos/sillytavern/config.yaml";
            whitelist = true;
        };
        networking.firewall.allowedTCPPorts = [ 8000 ];
    };
}
