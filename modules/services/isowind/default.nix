{ self, inputs, ... }: {
    # Re-export the vendored Isowind flake's NixOS module as
    # self.nixosModules.isowind, mirroring how self.nixosModules.azerothcore is
    # exposed, so a host can do:
    #   imports = [ self.nixosModules.isowind ];
    #   services.isowind.enable = true;
    #
    # The flake itself (the prebuilt Isowind release: the tes3mp multiplayer
    # server plus the game client) lives under _flake/ so that import-tree's
    # default filter — which ignores any path containing `/_` — does not try to
    # import the flake file (a `{ inputs; outputs; }` flake, not a NixOS module)
    # as a module. It is pulled in as the `isowind` path input in flake.nix,
    # with its nixpkgs following the host's so the server package is built
    # against the same nixpkgs as the rest of the system.
    flake.nixosModules.isowind = inputs.isowind.nixosModules.isowind;
}
