{ self, inputs, ... }: {
    flake.darwinConfigurations.workMac = inputs.nix-darwin.lib.darwinSystem {
        modules = [
            self.darwinModules.workMacConfiguration
        ];
    };
}
