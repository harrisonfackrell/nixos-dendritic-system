# MySQL provisioning for the AzerothCore module: the set of databases the
# servers need, the idempotent init SQL (CREATE USER + GRANT) written to the
# store, and the nixpkgs `services.mysql` / users / tmpfiles configuration
# that backs them.
{ lib, pkgs, cfg }:
let
    # Every MySQL database the servers need: the three core databases plus
    # one per module that declares `database`.
    allDatabases =
        [ "acore_auth" "acore_world" "acore_characters" ]
        ++ lib.filter (d: d != null) (lib.map (m: m.database) (lib.attrValues cfg.modules));

    # SQL that (idempotently) creates the app DB user and grants it access
    # to every database. Written to the store and fed to the mysql client by
    # the azerothcore-mysql-init oneshot (which connects over the unix socket
    # as root, so it authenticates as root@localhost via auth_socket and has
    # the CREATE USER / GRANT privileges). nixpkgs' services.mysql
    # `ensureUsers` only supports unix-socket authentication and cannot
    # create a password-authenticated user, which is why this is done here.
    # Note: no backslash before the backticks - `\`` is not a Nix escape in
    # multi-line strings, the backslash is preserved verbatim and the MySQL
    # client rejects it (`Unknown command '\`'`), which silently left the
    # app user without its GRANTs. The database names are fixed `acore_*`
    # identifiers, so bare backticks are safe.
    grantSql = lib.concatMapStrings (db: ''
        GRANT ALL PRIVILEGES ON `${db}`.* TO '${cfg.mysqlUser}'@'localhost';
        GRANT ALL PRIVILEGES ON `${db}`.* TO '${cfg.mysqlUser}'@'127.0.0.1';
    '') allDatabases;
    mysqlInitSql = pkgs.writeText "azerothcore-mysql-init.sql" ''
        CREATE USER IF NOT EXISTS '${cfg.mysqlUser}'@'localhost' IDENTIFIED BY '${cfg.mysqlPassword}';
        CREATE USER IF NOT EXISTS '${cfg.mysqlUser}'@'127.0.0.1' IDENTIFIED BY '${cfg.mysqlPassword}';
        ${grantSql}
    '';
in
{
    inherit allDatabases mysqlInitSql;

    # nixpkgs services.mysql + runtime user + writable directories.
    config = {
        services.mysql = {
            enable = true;
            package = pkgs.mysql84;
            settings = {
                # nixpkgs' mysql `settings` is an INI type: every key must
                # live inside a section, so bind-address goes under [mysqld]
                # (a top-level key is rejected).
                mysqld.bind-address = "127.0.0.1";
                mysqld.max_connections = 300;
            };
            ensureDatabases = allDatabases;
        };

        users.users.${cfg.user} = {
            isSystemUser = true;
            group = cfg.user;
            home = "/var/lib/azerothcore";
        };
        users.groups.${cfg.user} = { };

        systemd.tmpfiles.rules = [
            "d /var/lib/azerothcore 0750 ${cfg.user} ${cfg.user} - -"
            "d /var/lib/azerothcore/logs 0750 ${cfg.user} ${cfg.user} - -"
            "d /var/lib/azerothcore/data 0750 ${cfg.user} ${cfg.user} - -"
            "d /var/lib/azerothcore/data/dbc 0750 ${cfg.user} ${cfg.user} - -"
            "d /var/lib/azerothcore/data/maps 0750 ${cfg.user} ${cfg.user} - -"
            "d /var/lib/azerothcore/data/vmaps 0750 ${cfg.user} ${cfg.user} - -"
            "d /var/lib/azerothcore/data/mmaps 0750 ${cfg.user} ${cfg.user} - -"
        ];
    };
}
