{ config, lib, pkgs, modulesPath, ... }: {
    # Hardware configuration for holoprojector

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
