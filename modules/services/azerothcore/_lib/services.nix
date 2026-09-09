# systemd units + firewall + convenience packages for the AzerothCore
# module. The units run the binaries from `azerothcorePkg` (the local
# derivation built in default.nix), so this file receives it as an argument.
#
# The DB-updater processes (dbimport, authserver, worldserver) resolve
# SourceDirectory through the AC_SOURCE_DIRECTORY environment variable
# (ConfigMgr checks env vars before the conf file, even for keys the
# conf file does not define). It is set per unit to the merged source
# tree the package installs at <prefix>/source, so the value is always
# the current package's store path without a symlink or an oneshot.
#
# The package's conf paths are symlinks into /etc/azerothcore, so the
# package no longer changes when the conf content does. Each unit
# therefore references the store paths of the confs it reads (in its
# startup script, below), which (a) fails the start fast if a target is
# missing - a missing or mis-named conf would otherwise make the server
# silently fall back to compiled-in defaults - and (b) changes the unit
# whenever the conf changes, so restartIfChanged re-runs the oneshots
# and restarts the servers after a conf edit.
{ lib, pkgs, cfg, azerothcorePkg, mysqlInitSql, configFiles }:
let
    # The store path of the generated conf with the given
    # /etc/azerothcore relative path (the core confs are always present).
    confPathOf = etcRel:
        (lib.head (lib.filter (f: f.etcRel == etcRel) configFiles)).file;
    confGuards = etcRels:
        lib.concatStringsSep "\n" (lib.map (rel: "test -r ${confPathOf rel}") etcRels);
    # The worldserver reads its own conf plus every module conf.
    moduleConfRels =
        lib.map (f: f.etcRel) (lib.filter (f: lib.hasPrefix "modules/" f.etcRel) configFiles);
in
{
    config = {
        systemd.services = {
            azerothcore-mysql-init = {
                description = "AzerothCore MySQL user and grants";
                wantedBy = [ "multi-user.target" ];
                after = [ "mysql.service" ];
                wants = [ "mysql.service" ];
                # Idempotent (CREATE USER IF NOT EXISTS + repeatable GRANT),
                # cheap to re-run every boot so DB user/password/database
                # changes take effect without manual SQL.
                serviceConfig = {
                    Type = "oneshot";
                    # Runs as root so the unix-socket connection authenticates
                    # as root@localhost (auth_socket), which can CREATE USER
                    # and GRANT. nixpkgs' ensureUsers cannot do this (it only
                    # creates socket-auth users).
                };
                path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                script = ''
                    ${pkgs.mysql84}/bin/mysql --socket=/run/mysqld/mysqld.sock < ${mysqlInitSql}
                '';
            };

            azerothcore-dbimport = {
                description = "AzerothCore database import (auth/world/characters)";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" "mysql.service" "azerothcore-mysql-init.service" ];
                wants = [ "mysql.service" ];
                # Hash-based and idempotent - cheap to re-run every boot,
                # keeps the DBs in sync with source updates.
                # NOTE: dbimport only seeds Login/Character/World; any module
                # that ships its own base SQL (e.g. mod-playerbots) runs its
                # own DB updater from the worldserver.
                serviceConfig = {
                    Type = "oneshot";
                    User = cfg.user;
                    Environment = [
                        # Databases are pre-created by NixOS; never block on
                        # an interactive prompt.
                        "AC_DISABLE_INTERACTIVE=1"
                        # Root for the runtime SQL base/update lookups
                        # (merged source tree shipped by the package).
                        "AC_SOURCE_DIRECTORY=${azerothcorePkg}/source"
                    ];
                };
                path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                script = ''
                    # Fail fast if the generated conf is missing (its
                    # in-package path is a symlink to /etc/azerothcore),
                    # and reference the conf's store path so the unit
                    # changes - and re-runs - when the conf does.
                    ${confGuards [ "dbimport.conf" ]}
                    # The core installs its apps/tools to <prefix>/bin.
                    # (lib.getExe' cannot be used: the package is built
                    # from source, so its contents are unknown until it is
                    # built, and the unit's ExecStart is rendered at eval
                    # time, before the build.)
                    ${azerothcorePkg}/bin/dbimport
                '';
            };

            azerothcore-authserver = {
                description = "AzerothCore auth server";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" "mysql.service" "azerothcore-dbimport.service" ];
                wants = [ "mysql.service" ];
                restartIfChanged = true;
                serviceConfig = {
                    User = cfg.user;
                    Environment = [
                        "AC_DISABLE_INTERACTIVE=1"
                        "AC_SOURCE_DIRECTORY=${azerothcorePkg}/source"
                    ];
                    Restart = "on-failure";
                    RestartSec = "5";
                };
                path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                script = ''
                    ${confGuards [ "authserver.conf" ]}
                    ${azerothcorePkg}/bin/authserver
                '';
            };

            azerothcore-worldserver = {
                description = "AzerothCore world server (WotLK, statically compiled modules)";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" "mysql.service" "azerothcore-authserver.service" ];
                wants = [ "mysql.service" ];
                restartIfChanged = true;
                serviceConfig = {
                    User = cfg.user;
                    # The WotLK worldserver opens thousands of map/DB handles.
                    LimitNOFILE = 16384;
                    Environment = [
                        "AC_DISABLE_INTERACTIVE=1"
                        # Also feeds the modules' DB updaters (e.g.
                        # mod-playerbots' own data/sql under
                        # modules/<name>/ inside the merged tree).
                        "AC_SOURCE_DIRECTORY=${azerothcorePkg}/source"
                    ];
                    Restart = "on-failure";
                    RestartSec = "10";
                    # First start loads all maps (and any module populates its
                    # own DB); allow a generous start timeout.
                    TimeoutStartSec = "600";
                };
                path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                script = ''
                    # Own conf plus every module conf (the worldserver loads
                    # them all at startup).
                    ${confGuards ( [ "worldserver.conf" ] ++ moduleConfRels )}
                    ${azerothcorePkg}/bin/worldserver
                '';
            };
        };

        networking.firewall = lib.mkIf cfg.openFirewall {
            allowedTCPPorts = [ cfg.authPort cfg.worldPort ];
        };

        environment.systemPackages = [
            pkgs.mysql84 # convenient for manual DB work
        ];
    };
}
