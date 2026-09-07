{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        flake-parts = {
            url = "github:hercules-ci/flake-parts";
        };
        apple-silicon = {
            url = "github:nix-community/nixos-apple-silicon";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        import-tree = {
            url = "github:vic/import-tree";
        };
        wrapper-modules = {
            url = "github:BirdeeHub/nix-wrapper-modules";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        noctalia = {
            url = "github:noctalia-dev/noctalia";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        stylix = {
            url = "github:nix-community/stylix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        # Not a flake for our purposes (its flake only exports devShells) —
        # fetch it as a source-only input so `inputs.azerothcore` is the
        # source tree itself, not a flake outputs attrset.
        azerothcore = {
            url = "github:mod-playerbots/azerothcore-wotlk/Playerbot";
            flake = false;
        };
        # Not a flake (no flake.nix) — fetch it as a source-only input.
        playerbots = {
            url = "git+https://github.com/mod-playerbots/mod-playerbots";
            flake = false;
        };
    };

    outputs = inputs:
        inputs.flake-parts.lib.mkFlake { inherit inputs; } {
            systems = [ "aarch64-linux" "x86_64-linux" ];
            imports = [
                (inputs.import-tree ./modules)
                inputs.home-manager.flakeModules.home-manager
            ];
        };
}