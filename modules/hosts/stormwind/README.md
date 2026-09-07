# stormwind — AzerothCore (WotLK) + mod-playerbots

Proxmox LXC host running a World of Warcraft: Wrath of the Lich King private
server, built from the [mod-playerbots/azerothcore-wotlk](https://github.com/mod-playerbots/azerothcore-wotlk)
fork (`Playerbot` branch) with
[mod-playerbots](https://github.com/mod-playerbots/mod-playerbots) compiled in.

## Components

| Piece | Where |
|---|---|
| Servers (authserver, worldserver, dbimport) | built from GitHub via flake inputs, in the Nix store |
| Server configs (generated, immutable) | inside the built package (`…/etc/*.conf`) |
| MySQL 8.4 with `acore_auth`, `acore_world`, `acore_characters`, `acore_playerbots` | `services.mysql` (localhost only) |
| systemd units | `azerothcore-dbimport`, `azerothcore-authserver`, `azerothcore-worldserver` |
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

   `dbimport` seeds auth/world/characters from the SQL in the Nix store.
   The `acore_playerbots` database is populated automatically by the
   worldserver on first boot — the playerbots module runs its own DB
   updater, reading `modules/mod-playerbots/data/sql` from the store.

## Day-2 notes

- **Tuning the server**: all config is declarative. Set
  `services.azerothcore.extraWorldConf` (raw lines) or
  `extraOverrides` (attrset of key → value) in
  `configuration.nix`, e.g.:

  ```nix
  services.azerothcore.extraOverrides = {
      GM.StartLevel = "50";
  };
  ```

  The generated configs live in the Nix store and are rebuilt with the
  system, so there are no operator-owned conf files to drift.
- **Updating AzerothCore / playerbots**:
  `nix flake update azerothcore playerbots` in this flake, then rebuild.
  The DB updaters apply any pending SQL automatically on next start.
- **Creating the first account**: after the worldserver's first start,
  follow the AzerothCore wiki ("Accounts" — create an auth account and a
  realmlist entry), e.g. via `mysql -u acore -pacore acore_auth`.
- **Changing the DB password**: set `services.azerothcore.mysqlPassword`
  here and rebuild — the new value is baked into the generated configs
  and the `ensureUsers` entry (existing DB users are updated by NixOS).
