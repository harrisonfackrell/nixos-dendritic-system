{
  description = "Isowind (the top-down isometric OpenMW), packaged from its prebuilt GitHub release for Nix: the multiplayer server, and the game itself";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
    let
      # The release to package: its tag and the sha256 of its Linux package
      # (isowind-linux-x86_64.tar.gz), as GitHub publishes it on the release.
      # To pin another release, add it to the table and point `release` at it
      # (check the hash with:
      #   curl -L -o /tmp/i.tar.gz <release url> && sha256sum /tmp/i.tar.gz).
      releases = {
        "alpha-v1.0.2b" = {
          tag = "alpha-v1.0.2b";
          sha256 = "344c59f42758b5cbd34195ef3acbd27ad7327ae250b3bf3fd250a29b1c661b6f";
        };
        "alpha-v1.0.2a" = {
          tag = "alpha-v1.0.2a";
          sha256 = "670bd5b1485abeaab6ffb34d2268a44743b6bccfbf6a813b066b97ae10dead5e";
        };
        "alpha-v1.0.1a" = {
          tag = "alpha-v1.0.1a";
          sha256 = "628d41005bc2c29915c58b80d7ece518bc56672ad0754b99304983d9524ffbfb";
        };
      };
      release = releases."alpha-v1.0.2b";

      # The prebuilt release is for x86-64 only (its tarball is, and it needs
      # glibc 2.38 or newer, which every recent nixpkgs has).
      systems = [ "x86_64-linux" ];
      pkgsFor = system: import nixpkgs { inherit system; };

      # The packages, one set per system.
      buildPkgs = system:
        let
          pkgs = pkgsFor system;
          # python3 with Pillow, for the pixel art look's textures (isowind.sh
          # runs "python3"):
          pythonPillow = pkgs.python3.withPackages (ps: [ ps.pillow ]);
        in
        rec {
          # The released Linux package, unpacked as it is: the Isowind/ folder
          # with isowind.sh, engine/ (the games and their own libraries) and
          # server/ (tes3mp-server's settings and TES3MP's CoreScripts).
          isowind = pkgs.stdenvNoCC.mkDerivation {
            pname = "isowind";
            version = release.tag;
            src = pkgs.fetchurl {
              url = "https://github.com/pw-tf/isowind/releases/download/${release.tag}/isowind-linux-x86_64.tar.gz";
              sha256 = release.sha256;
            };
            # The tarball unpacks one Isowind/ folder; take its contents:
            unpackPhase = "true";
            dontConfigure = true;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out
              tar -xzf $src -C $out --strip-components=1
              chmod -R u+w $out
            '';
            meta.description = "Isowind (release ${release.tag}), the prebuilt Linux package from the GitHub release";
          };

          # The wrapper: the server must run from its own folder (it finds
          # tes3mp-server-default.cfg there, and keeps its settings, its saved
          # world and its ban list in it, as the release's "isowind.sh host"
          # does), so it is kept in ~/.isowind/server-<version>, seeded from
          # the package. No environment is needed: the binary finds its
          # libraries by RUNPATH.
          isowind-server-wrapper = pkgs.writeShellScript "isowind-server" ''
            DIR="$HOME/.isowind/server-${release.tag}"
            mkdir -p "$DIR/CoreScripts/data"
            cp -f ${isowind}/server/tes3mp-server-default.cfg "$DIR/"
            cp -rn ${isowind}/server/CoreScripts/. "$DIR/CoreScripts/"
            cd "$DIR"
            exec ${isowind}/engine/usr/bin/tes3mp-server "$@"
          '';

          # The multiplayer server for a headless box: the release's engine and
          # server folders, plus the wrapper.
          isowind-server = pkgs.stdenvNoCC.mkDerivation {
            pname = "isowind-server";
            version = release.tag;
            dontUnpack = true;
            dontConfigure = true;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out/bin
              cp -a ${isowind}/engine ${isowind}/server $out/
              cp ${isowind-server-wrapper} $out/bin/isowind-server
              chmod +x $out/bin/isowind-server
            '';
            meta.description = "Isowind's multiplayer server (a TES3MP port), from the GitHub release";
          };

          # The wrapper: on first start the release is copied to a writable
          # folder (isowind.sh keeps its choices there, and the pixel art look
          # builds its textures into it), as unzipping the release's tarball
          # does; then it is run from there, with a Python 3 that has Pillow.
          isowind-client-wrapper = pkgs.writeShellScript "isowind" ''
            DIR="$HOME/.isowind/${release.tag}"
            if [ ! -d "$DIR" ]; then
              echo "Isowind: first start, unpacking to $DIR"
              cp -a ${isowind} "$DIR"
              chmod -R u+w "$DIR"
            fi
            cd "$DIR"
            PATH="${pythonPillow}/bin:$PATH" exec ./isowind.sh "$@"
          '';

          # The game, for a desktop machine. It needs Morrowind, Game of the
          # Year edition.
          isowind-client = pkgs.stdenvNoCC.mkDerivation {
            pname = "isowind-client";
            version = release.tag;
            dontUnpack = true;
            dontConfigure = true;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out/bin
              cp -a ${isowind} $out/isowind
              cp ${isowind-client-wrapper} $out/bin/isowind
              chmod +x $out/bin/isowind
            '';
            meta.description = "Isowind, the top-down isometric Morrowind (the prebuilt release), for a desktop";
          };
        };
    in
    {
      packages = nixpkgs.lib.genAttrs systems (system:
        let set = buildPkgs system;
        in set // {
          # For a NixOS box the server is the point:
          default = set.isowind-server;
        });

      devShells = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = pkgsFor system;
          set = buildPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = [ set.isowind-client set.isowind-server pkgs.bash pkgs.coreutils pkgs.curl ];
            shellHook = ''
              echo "Isowind ${release.tag}:"
              echo "  isowind ...         the game (a desktop; needs Morrowind)"
              echo "  isowind-server      the multiplayer server (from its folder in ~/.isowind/)"
            '';
          };
        });

      nixosModules = rec {
        isowind = { config, lib, pkgs, ... }:
        let
          cfg = config.services.isowind;
          serverPackage = cfg.package;
          # The settings' values, in the file's own form: the scripts read
          # "true" and "false" as strings (not 1 and 0).
          valueToString = value:
            if builtins.isBool value
            then (if value then "true" else "false")
            else builtins.toString value;
          # This server's settings, in the form the release's "Host a server"
          # keeps them: over the release's tes3mp-server-default.cfg, written to
          # the server folder's tes3mp-server.cfg on every start.
          configText = lib.concatStringsSep "\n" (lib.mapAttrsToList (section: values:
            "[${section}]\n"
            + lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
                "${name} = ${valueToString value}") values)
          ) cfg.config);
          # The server's port, for the firewall (General.port, default 25565).
          # lib.getAttr is 2-argument (curried) in current nixpkgs, so the
          # fallback for a missing [General] section is spelled out:
          portRaw =
            if cfg.config ? General && cfg.config.General ? port
            then cfg.config.General.port
            else 25565;
          port = if builtins.isInt portRaw then portRaw else lib.toInt (builtins.toString portRaw);
        in
        {
          options.services.isowind = {
            enable = lib.mkEnableOption "Isowind's multiplayer server (the tes3mp-server of the prebuilt release)";

            package = lib.mkOption {
              type = lib.types.package;
              # This flake's isowind-server, built with the host's nixpkgs
              # (stdenv.hostPlatform.system, not pkgs.system, which current
              # nixpkgs only warns about):
              default = (buildPkgs pkgs.stdenv.hostPlatform.system).isowind-server;
              description = ''
                The Isowind server package (the release's engine/ and server/
                folders) to run. The release is built on Ubuntu 24.04 and needs
                glibc 2.38 or newer, and the system's graphics (libGL), X11,
                freetype and fontconfig libraries.
              '';
            };

            dataDir = lib.mkOption {
              type = lib.types.str;
              default = "/var/lib/isowind/server";
              description = ''
                The server's folder: its settings (tes3mp-server.cfg), its
                CoreScripts (in data/ the world's saved data, the ban list).
                With the default it is created and owned by the service's user;
                with another path it must already exist and be writable by the
                isowind user.
              '';
            };

            config = lib.mkOption {
              type = lib.types.attrsOf (lib.types.attrsOf (lib.types.oneOf [
                # lib.types.str (not lib.types.string, which was removed from
                # nixpkgs; the flake is evaluated with the host's nixpkgs):
                lib.types.str
                lib.types.int
                lib.types.bool
              ]));
              default = {
                General.hostname = "Isowind server";
                General.port = 25565;
                General.maximumPlayers = 16;
                Isowind.mode = "coop";
              };
              example = {
                General.hostname = "My Isowind";
                General.port = 25565;
                General.maximumPlayers = 32;
                General.password = ""; # empty: no password
                Isowind.mode = "mmo"; # or "coop"
                Isowind.pvp = false;
                Isowind.difficulty = 0; # -100..100
                Isowind.respawnSpeed = 1; # mmo: 0.5, 1, 2, 4
                Isowind.timeSpeed = 1; # 0.5, 1, 2, 4
                Isowind.portableCharacters = false;
              };
              description = ''
                The server's settings, written to the server folder's
                tes3mp-server.cfg on every start (over the release's
                tes3mp-server-default.cfg), in the same form the release's "Host
                a server" keeps them: top-level names are sections, their
                entries settings. The settings of the release's defaults:
                [General] localAddress, port, maximumPlayers, hostname,
                logLevel, password; [Isowind] mode (coop|mmo), pvp, difficulty,
                respawnSpeed, timeSpeed, portableCharacters.
              '';
            };

            openFirewall = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Open the server's UDP port (General.port, default 25565) in the firewall.";
            };
          };

          config = lib.mkIf cfg.enable {
            users.groups.isowind = { };
            users.users.isowind = {
              isSystemUser = true;
              group = "isowind";
              description = "Isowind multiplayer server";
            };

            systemd.services.isowind = {
              description = "Isowind multiplayer server (tes3mp-server)";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              path = [ pkgs.coreutils ];
              # The server runs from its folder (it finds
              # tes3mp-server-default.cfg there; the release's "isowind.sh host"
              # does the same). Its output goes to the journal (it is run with
              # --no-logs, which turns off its own log files).
              serviceConfig =
              let
                # With the default data directory, systemd creates it and gives
                # it to the service's user (another path must already exist and
                # be writable by the isowind user):
                stateDirOption = lib.optionalAttrs (cfg.dataDir == "/var/lib/isowind/server") {
                  StateDirectory = "isowind/server";
                };
                # This server's settings, in the file's own format:
                serverConfigFile = pkgs.writeText "tes3mp-server.cfg" configText;
                # Seeds the state directory with the release's settings and
                # CoreScripts, writes this server's settings, then runs the
                # server from there:
                execStart = "${pkgs.writeShellScriptBin "isowind-server" ''
                  set -eu
                  STATE_DIR="${cfg.dataDir}"
                  SERVER_DIR="${serverPackage}/server"
                  ENGINE_LIB="${serverPackage}/engine/usr/lib"

                  mkdir -p "$STATE_DIR/CoreScripts/data"
                  cp -f "$SERVER_DIR/tes3mp-server-default.cfg" "$STATE_DIR/"
                  cp -rn "$SERVER_DIR/CoreScripts/." "$STATE_DIR/CoreScripts/"
                  cp "${serverConfigFile}" "$STATE_DIR/tes3mp-server.cfg"

                  cd "$STATE_DIR"
                  exec env LD_LIBRARY_PATH="$ENGINE_LIB" "$SERVER_DIR/engine/usr/bin/tes3mp-server" --no-logs
                ''}/bin/isowind-server";
              in
              {
                User = "isowind";
                Group = "isowind";
                WorkingDirectory = cfg.dataDir;
                Restart = "on-failure";
                ExecStart = execStart;
              } // stateDirOption;
            };

            networking.firewall.allowedUDPPorts =
              lib.optional cfg.openFirewall port;
          };
        };

        default = isowind;
      };
    };
}
