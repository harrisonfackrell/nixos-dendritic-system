# stormwind — AzerothCore (WotLK) + mod-playerbots

Proxmox LXC host running a World of Warcraft: Wrath of the Lich King private
server, built from the [mod-playerbots/azerothcore-wotlk](https://github.com/mod-playerbots/azerothcore-wotlk)
fork (`Playerbot` branch) with
[mod-playerbots](https://github.com/mod-playerbots/mod-playerbots) compiled in.

## Components

| Piece | Where |
|---|---|
| Package definition (nixpkgs-style) | `modules/services/azerothcore/_lib/package.nix` |
| Servers (authserver, worldserver, dbimport) + modules | built from GitHub via `pkgs.fetchFromGitHub` (pinned rev + hash), in the Nix store; exposed as `pkgs.azerothcoreWotlk` |
| Server configs (generated) | `/etc/azerothcore/` via `environment.etc`; the package carries symlinks to them |
| MySQL 8.4 with `acore_auth`, `acore_world`, `acore_characters`, `acore_playerbots` | `services.mysql` (localhost only) |
| systemd units | `azerothcore-mysql-init`, `azerothcore-dbimport`, `azerothcore-authserver`, `azerothcore-worldserver` |
| Logs | `/var/lib/azerothcore/logs/` |
| **Game client data (you must copy this manually)** | `/var/lib/azerothcore/data/` |

Firewall ports when `services.azerothcore.openFirewall = true` (set in
`configuration.nix`): 3724 (auth), 8085 (world).

## First-time setup

1. **Build & deploy** (from this repo):

   ```bash
   nixos-rebuild build --flake .#stormwind
   # then deploy the result to the LXC with your usual mechanism
   ```

   The first build compiles AzerothCore from source (~1 GB of store,
   30–60 min). This is expected and happens once per flake revision.

2. **Copy WoW WotLK client data** into `/var/lib/azerothcore/data/`.
   The worldserver expects the AzerothCore data layout — `dbc/`, `maps/`,
   `vmaps/`, `mmaps/` — under the configured `DataDir`
   (default `/var/lib/azerothcore/data`). Generate it from a legitimate
   *WoW 3.3.5 (WotLK)* client install using AzerothCore's data tooling
   (e.g. `map_extractor` / the client-data import in the upstream
   wiki) and place the result accordingly.

3. **Start the services**:

   ```bash
   systemctl start azerothcore-dbimport.service
   systemctl start azerothcore-authserver.service
   systemctl start azerothcore-worldserver.service
   journalctl -u azerothcore-worldserver -f
   ```

   `azerothcore-mysql-init` runs first (idempotent): it creates the
   `acore` MySQL user with a password and grants it on all of the core +
   module databases. `dbimport` then seeds auth/world/characters from the
   SQL in the Nix store. The `acore_playerbots` database is created by
   NixOS and populated automatically by the worldserver on first boot —
   the playerbots module runs its own DB updater, reading
   `modules/mod-playerbots/data/sql` from the store.

## Day-2 notes

- **Choosing the core and modules**: the AzerothCore source tree and the
  set of compiled-in modules are options, so you can substitute a fork of
  the core or add/remove modules without touching the module. This host
  does both: `source.src` substitutes the mod-playerbots fork of the core
  for the module's upstream azerothcore/azerothcore-wotlk default, and
  `modules` compiles mod-playerbots in:

  ```nix
  services.azerothcore = {
      # The core defaults to a pinned commit of upstream
      # azerothcore/azerothcore-wotlk `master` (pkgs.fetchFromGitHub, in
      # the module's option default). Substitute a fork, as here:
      source = {
          src = pkgs.fetchFromGitHub {
              owner = "mod-playerbots"; repo = "azerothcore-wotlk";
              rev = "…"; hash = "sha256-…";
          };
          version = "17.0.0";
      };
      # Modules are keyed by the directory name they're installed as
      # (modules/<name>/); the module must contain a src/ subdirectory.
      modules = {
          mod-playerbots = {
              # Fetch the latest commit with a pinned rev + content hash:
              src = pkgs.fetchFromGitHub {
                  owner = "mod-playerbots"; repo = "mod-playerbots";
                  rev = "…"; hash = "sha256-…";
              };
              database = "acore_playerbots";
          };
          # mod-another = { src = pkgs.fetchFromGitHub { … }; };
      };
  };
  ```

  `database` ensures the MySQL database and auto-generates the module's
  `<Base>DatabaseInfo` connection string in its conf (base = name without
  the `mod-` prefix). `modules = {}` builds the core with no modules.
- **Tuning the server**: all config is declarative. The contents of each
  `.conf` file are exposed as an attribute-set option, so you can override
  any single key (or add new ones) without disturbing the module's defaults:

  | Option | File written |
  |---|---|
  | `services.azerothcore.authserverConfig` | `/etc/azerothcore/authserver.conf` |
  | `services.azerothcore.worldserverConfig` | `/etc/azerothcore/worldserver.conf` |
  | `services.azerothcore.dbimportConfig` | `/etc/azerothcore/dbimport.conf` |
  | `services.azerothcore.modules.<name>.config` | `/etc/azerothcore/modules/<base>.conf` |

  Each is a set of `key = value` pairs (values are strings or integers;
  numbers are stringified). AzerothCore's config parser is flat, so every
  key is a single literal name and AzerothCore keys containing a dot
  (e.g. `GM.StartLevel`) must be quoted in Nix — nested attribute sets are
  not possible. e.g.:

  ```nix
  services.azerothcore.worldserverConfig = {
      MaxPlayers = "200";
      "GM.StartLevel" = "50";                  # override/add a single key
      "Visibility.Distance.Continents" = 100;  # dotted key stays quoted
  };
  ```

  Keys you don't list keep their module defaults (RealmServerPort,
  WorldServerPort, DataDir, the `*DatabaseInfo` connection strings,
  LogsDir, TempDir, MySQLExecutable). `SourceDirectory` is not a conf
  key: it is the package's own store path, so the systemd units supply
  it as the `AC_SOURCE_DIRECTORY` environment variable instead (the
  servers check env vars before the conf file). The generated configs
  are installed to `/etc/azerothcore/` at activation time and the
  package holds symlinks to them, so a config edit is a cheap `writeText`
  + activation — no AzerothCore rebuild — and the services restart
  automatically (the units reference the conf store paths). You can
  also edit the files under `/etc/azerothcore/` directly and
  `systemctl restart azerothcore-worldserver` for immediate effect; a
  later `nixos-rebuild` reconciles them back to the Nix-declared
  content.
- **Updating AzerothCore / playerbots**: bump the `rev` + `hash` of the
  `pkgs.fetchFromGitHub` derivations in `configuration.nix` (the core
  fork in `source.src`, the module in `modules.mod-playerbots.src`), then
  rebuild. (The module's upstream default in
  `modules/services/azerothcore/default.nix` only applies if you remove
  the `source` override.) To grab the latest commit, get the head of the
  branch with `git ls-remote`, download the matching
  `https://github.com/<owner>/<repo>/archive/<rev>.tar.gz` and use its
  `sha256` (Nix's `sha256-<base64>` form, i.e.
  `nix-prefetch-github <owner> <repo> <rev>` or `base64 -w0` of the digest).
  The DB updaters apply any pending SQL automatically on next start.
- **Creating the first account**: after the worldserver's first start,
  follow the AzerothCore wiki ("Accounts" — create an auth account and a
  realmlist entry), e.g. via `mysql -u acore -pacore acore_auth`.
- **Changing the DB password**: set `services.azerothcore.mysqlPassword`
  here and rebuild — the new value is baked into the generated configs and
  the `azerothcore-mysql-init` script re-applies it (the `GRANT`/`IDENTIFIED
  BY` statements are idempotent; note the user's password is only
  re-set if you also re-run `azerothcore-mysql-init`, which it does every
  boot before dbimport).
