{ self, inputs, ...}: {
    flake.nixosConfigurations.m1Air = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.nixosModules.m1AirConfiguration
        ];
    };
}