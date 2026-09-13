{ self, inputs, ... }:
{
    # Open WebUI is the *public* front end of this host (served on
    # sith.khetanna.party, port-forwarded to this LXC's 0.0.0.0:8080). Its LLM
    # agents perform web searches against the internal-only SearXNG instance
    # from searx.nix, reachable over loopback at http://127.0.0.1:8888 —
    # SearXNG itself has no firewall port and no public hostname.
    flake.nixosModules.openwebui = { config, lib, pkgs, ... }: {
        services.open-webui = {
            enable = true;
            port = 8080;
            host = "0.0.0.0";
            openFirewall = true;
            environment = {
                # Public URL the instance is reached at; used for OAuth and
                # self-referencing links.
                WEBUI_URL = "https://sith.khetanna.party";
            };
        };
    };
}
