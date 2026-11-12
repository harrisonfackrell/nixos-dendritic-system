{ self, inputs, ... }:
{
    flake.nixosConfigurations.terraria = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.nixosModules.terrariaConfiguration
        ];
    };
}
