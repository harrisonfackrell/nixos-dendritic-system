{ self, inputs, ... }: {
    flake.nixosConfigurations.holoprojector = inputs.nixpkgs.lib.nixosSystem {
        modules = [
            self.nixosModules.holoprojectorConfiguration
        ];
    };
}
