{ self, inputs, ... }: {
    flake.nixosModules.terrariaServer = { config, lib, pkgs, ... }: {
        # Terraria server settings (services.terraria, provided by nixpkgs)
        services.terraria = {
            enable = true;
            openFirewall = true;
            port = 7777;
            maxPlayers = 16;
            autoCreatedWorldSize = "medium";
            # Without an existing world at this path, one is auto-created on
            # first start with the size given by autoCreatedWorldSize.
            worldPath = "${config.services.terraria.dataDir}/world.wld";
            secure = true;
        };
    };
}
