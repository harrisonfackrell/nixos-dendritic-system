{ self, inputs, ... }: {
    flake.nixosModules.lemonade = { config, lib, pkgs, ... }: {
        imports = [
            inputs.nix-amd-ai.nixosModules.default
        ];

        # Binary cache for pre-built packages (avoids building from source)
        nix.settings = {
            substituters = [ "https://nix-amd-ai.cachix.org" ];
            trusted-public-keys = [ "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ=" ];
        };

        nixpkgs.overlays = [
            inputs.nix-amd-ai.overlays.default
            (final: prev: {
                lemonade = prev.lemonade.override {
                    withWebApp = false;
                    withDesktopApp = false;
                };
            })
        ];

        # GPU-only configuration for Radeon RX 7900 (gfx1201)
        # No NPU present; ROCm + Vulkan backends for GPU inference
        hardware.amd-npu = {
            enable = true;
            enableNPU = false;        # No NPU on this hardware
            enableFastFlowLM = false; # Requires NPU
            enableLemonade = true;    # OpenAI-compatible API server
            enableROCm = true;        # ROCm GPU backend (gfx1201)
            enableVulkan = true;      # Vulkan GPU backend
            enableImageGen = true;    # Image generation (sd-cpp via ROCm)
            lemonade.user = "obiwanshinobi";
        };
    };
}
