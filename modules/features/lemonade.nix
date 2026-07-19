{ self, inputs, ... }: {
    flake.nixosModules.lemonade = { config, lib, pkgs, ... }: {
        imports = [
            inputs.nix-amd-ai.nixosModules.default
        ];

        nixpkgs.overlays = [
            inputs.nix-amd-ai.overlays.default
            (final: prev: {
                lemonade = prev.lemonade.override {
                    withWebApp = false;
                    withDesktopApp = false;
                };
            })
        ];

        hardware.amd-npu = {
            enable = true;
            enableNPU = false;
            enableFastFlowLM = false;
            enableLemonade = true;
            enableROCm = true;
            enableVulkan = true;
            enableImageGen = true;
            lemonade.user = "obiwanshinobi";
        };
    };
}
