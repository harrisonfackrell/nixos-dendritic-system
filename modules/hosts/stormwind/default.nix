{ self, inputs, ... }: {
    flake.nixosConfigurations.stormwind = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.nixosModules.stormwindConfiguration
        ];
    };
}
