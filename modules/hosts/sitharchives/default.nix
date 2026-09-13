{ self, inputs, ... }:
{
    flake.nixosConfigurations.sitharchives = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.nixosModules.sitharchivesConfiguration
        ];
    };
}
