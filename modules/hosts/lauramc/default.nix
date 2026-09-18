{ self, inputs, ... }:
{
    flake.nixosConfigurations.lauramc = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.nixosModules.lauramcConfiguration
        ];
    };
}
