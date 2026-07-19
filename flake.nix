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
    };

    outputs = inputs:
        inputs.flake-parts.lib.mkFlake { inherit inputs; } {
            systems = [ "aarch64-linux" "x86_64-linux" ];
            imports = [(inputs.import-tree ./modules)];
        };
}