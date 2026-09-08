# systemd units + firewall + convenience packages for the AzerothCore
# module. The units run the binaries from `azerothcorePkg` (the local
# derivation built in default.nix), so this file receives it as an argument.
{ lib, pkgs, cfg, azerothcorePkg, sourceDir, mysqlInitSql }:
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

            # Re-point the SourceDirectory symlink at the merged source tree
            # shipped by the package (<prefix>/source, core + modules) on
            # every (re)start, so a package upgrade picks up the new tree
            # before anything resolves SQL paths against it. Idempotent and
            # cheap; restartIfChanged re-runs it whenever the package
            # changes.
            azerothcore-source = {
                description = "AzerothCore source tree symlink";
                wantedBy = [ "multi-user.target" ];
                restartIfChanged = true;
                serviceConfig = {
                    Type = "oneshot";
                };
                path = [ pkgs.bash pkgs.coreutils ];
                script = ''
                    ln -sfn ${azerothcorePkg}/source ${sourceDir}
                '';
            };

            azerothcore-dbimport = {
                description = "AzerothCore database import (auth/world/characters)";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" "mysql.service" "azerothcore-mysql-init.service" "azerothcore-source.service" ];
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
                    ];
                };
                path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                script = ''
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
                    Environment = [ "AC_DISABLE_INTERACTIVE=1" ];
                    Restart = "on-failure";
                    RestartSec = "5";
                };
                path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                script = ''
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
                    Environment = [ "AC_DISABLE_INTERACTIVE=1" ];
                    Restart = "on-failure";
                    RestartSec = "10";
                    # First start loads all maps (and any module populates its
                    # own DB); allow a generous start timeout.
                    TimeoutStartSec = "600";
                };
                path = [ pkgs.bash pkgs.coreutils pkgs.mysql84 ];
                script = ''
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
