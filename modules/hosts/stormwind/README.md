# stormwind — AzerothCore (WotLK) + mod-playerbots

Proxmox LXC host running a World of Warcraft: Wrath of the Lich King private
server, built from the [mod-playerbots/azerothcore-wotlk](https://github.com/mod-playerbots/azerothcore-wotlk)
fork (`Playerbot` branch) with
[mod-playerbots](https://github.com/mod-playerbots/mod-playerbots) compiled in.

## Components

| Piece | Where |
|---|---|
| Servers (authserver, worldserver, dbimport) | built from GitHub via flake inputs, in the Nix store |
| MySQL 8.4 with `acore_auth`, `acore_world`, `acore_characters`, `acore_playerbots` | `services.mysql` (localhost only) |
| systemd units | `azerothcore-dbimport`, `azerothcore-authserver`, `azerothcore-worldserver` |
| Config files (operator-owned, never clobbered by rebuilds) | `/var/lib/azerothcore/etc/*.conf` |
| Logs | `/var/lib/azerothcore/logs/` |
| **Game client data (you must copy this manually)** | `/var/lib/azerothcore/data/` |

Firewall ports when `services.azerothcore.openFirewall = true`:
3724 (auth), 8085 (world), 8089 (SOAP).

## First-time setup

1. **Build & deploy** (from this repo):

   ```bash
   nixos-rebuild build --flake .#stormwind
   # then copy result to the LXC and unpack, or use your usual
   # deployment mechanism (rsync of /nix/store + nix-env / switch-to-configuration)
   ```

   The first build compiles AzerothCore from source (~1–2 GB of store,
   30–60 min). This is expected and happens only once per flake revision.

2. **Copy WoW WotLK client data** into `/var/lib/azerothcore/data/`.
   From a legitimate *WoW 3.3.5 (WotLK)* client install you need:

   ```
   Interface/   -> /var/lib/azerothcore/data/dbc/... (see below)
   maps/        -> /var/lib/azerothcore/data/maps/
   wmo/ vartmp  -> used to generate vmaps (optional)
   ```

   The worldserver expects the extracted AzerothCore data layout:
   `dbc/`, `maps/`, `vmaps/`, `mmaps/` under the configured `DataDir`
   (default `/var/lib/azerothcore/data`). The easiest way to obtain it is
   AzerothCore's `map_extractor` tool or a pre-extracted data archive;
   place the result so that `DataDir` points at it.

3. **Start the services**:

   ```bash
   systemctl start azerothcore-dbimport.service
   systemctl start azerothcore-authserver.service
   systemctl start azerothcore-worldserver.service
   journalctl -u azerothcore-worldserver -f
   ```

   `dbimport` seeds auth/world/characters from the SQL in the Nix store.
   The `acore_playerbots` database is created automatically by the
   worldserver on first boot (the playerbots module runs its own DB
   updater, reading `modules/mod-playerbots/data/sql` from the store).

## Day-2 notes

- **Tuning the server**: edit `/var/lib/azerothcore/etc/worldserver.conf`
  (or `extraWorldConf` / `extraOverrides` in this host's
  `configuration.nix` — the NixOS-managed block is appended once and
  marker-guarded, so hand edits survive rebuilds).
- **Updating AzerothCore / playerbots**: `nix flake update azerothcore
  playerbots` in the flake, then rebuild. The worldserver's DB updater
  applies any pending SQL automatically on next start.
- **Creating the first account**: after first worldserver start,
  `mysql -u acore -pacore acore_auth` and `CREATE TABLE` if needed, or
  use the in-game/DB flow described in the AzerothCore wiki
  (account + realmlist entries).
- **Changing the DB password**: set `services.azerothcore.mysqlPassword`
  here and drop the existing databases (or manually `ALTER USER`) — the
  password is baked into the materialised `.conf` files on first
  creation only, so after a password change delete the `*.conf` files in
  `/var/lib/azerothcore/etc` once to regenerate them.
