{ self, inputs, ... }:
{
    flake.nixosConfigurations.jediarchives = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.nixosModules.jediarchivesConfiguration
        ];
    };
}
