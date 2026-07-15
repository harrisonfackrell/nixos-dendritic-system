{ self, inputs, ... }: {
    flake.nixosModules.firefox = { pkgs, lib, ... }: {
        programs.firefox = {
            enable = true;
            policies = {
                AppAutoUpdate = false;
                DisableTelemetry = true;
                DisableFirefoxStudies = true;
                DisablePocket = true;
                DisableFirefoxAccounts = true;
                DisableAccounts = true;
                DisableFirefoxScreenshots = true;
                DontCheckDefaultBrowser = true;
                EnableTrackingProtection = {
                    Value= true;
                    Locked = true;
                    Cryptomining = true;
                    Fingerprinting = true;
                };
                GenerativeAI.Enabled = false;
                Homepage.StartPage = "homepage-locked";
                ManualAppUpdateOnly = true;
                NoDefaultBookmarks = true;
                OverrideFirstRunPage = "";
                OverridePostUpdatePage = "";
                DefaultDownloadDirectory = "\${home}/Downloads";
                AIControls.Default = {
                    Value = "blocked";
                    Locked = true;
                };
                FirefoxHome = {
                    TopSites = false;
                    SponsoredTopSites = false;
                    Highlights = false;
                    Pocket = false;
                    Stories = false;
                    SponsoredPocket = false;
                    SponsoredStories = false;
                    Snippets = false;
                    Locked = true;
                };
                FirefoxSuggest = {
                    SponsoredSuggestions = false;
                    ImproveSuggest = false;
                };
                Preferences = {
                    "browser.newtabpage.activity-stream.widgets.enabled" = false;
                };
                ExtensionSettings = {
                    "uBlock0@raymondhill.net" = {
                        default_area = "menupanel";
                        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
                        installation_mode = "force_installed";
                        private_browsing = true;
                    };
                };
            };
        };
    };
}