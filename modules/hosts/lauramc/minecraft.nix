{ self, inputs, ... }: {
    flake.nixosModules.lauramcMinecraft = {
        config,
        pkgs,
        lib,
        ...
    }:
    {
        # Minecraft server settings
        services.minecraft-servers = {
            enable = true;
            eula = true;
            openFirewall = true;
            servers.aether = {
                enable = true;
                package = pkgs.neoforgeServers.neoforge-26_1_2;
                symlinks = {
                    "world/datapacks" = pkgs.fetchzip {
                        url = "https://vanillatweaks.net/download/VanillaTweaks_d628217_UNZIP_ME.zip";
                        sha256 = "pe3IlaeHEmOYgaCEfJnSOad2EGcN3ZhrU77/kA6AohM=";
                        stripRoot = false;
                    };
                    mods = pkgs.linkFarmFromDrvs "mods" (
                        builtins.attrValues {
                            Aether-II = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/JD2NSu5O/versions/soZ6Sulf/aether_ii-26.1.2-alpha.4.1-neoforge.jar";
                                sha512 = "9bP86hcbglTl76HP35AAXbeOVCHzI79DdK8FqtMgstT5cJlU8Xc5HLVnsattb3w1Xu5yuB+STjTqEf9B5MBjgQ==";
                            };
                        }
                    );
                };
                operators = {
                    Thunderstarer = "4282f50d-7f25-4f3f-8dac-dc9bad432f07";
                };
                whitelist = {
                    Thunderstarer = "4282f50d-7f25-4f3f-8dac-dc9bad432f07";
                    BioBug_ = "dec5d116-7e29-49d7-a007-688d6e395783";
                };
                serverProperties = {
                    white-list = true;
                    max-players = 2;
                    allow-flight = true;
                    difficulty = "hard";
                    enforce-whitelist = true;
                    motd = "I do not know what to call this";
                };
            };
        };
    };
}
