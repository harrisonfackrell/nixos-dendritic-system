{ self, inputs, ... }: {
    flake.nixosConfigurations.geonosisfoundry = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.nixosModules.geonosisfoundryConfiguration
        ];
    };
}
