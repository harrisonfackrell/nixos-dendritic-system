# Work Mac

The `workMac` nix-darwin target is for the Apple Silicon Mac and the
`harrison.fackrell` account. It installs devenv and a current Bash through
Home Manager and manages Nix, its daemon and `/etc/nix/nix.conf` with
nix-darwin. It does not manage system-wide shell files, SSH configuration, or
the user zsh configuration. No macOS preferences are configured.

## First activation

Review your employer's policies before installing or activating system
configuration. nix-darwin activation requires administrator privileges and
changes system files and the Nix daemon.

From the repository root, make sure new files are tracked by Git before
building: Git-backed flakes do not include untracked files. Then run:

```sh
# Use the full path if nix is not yet on your PATH.
export PATH="/nix/var/nix/profiles/default/bin:$PATH"
nix build .#darwinConfigurations.workMac.system --no-link
sudo /nix/var/nix/profiles/default/bin/nix run --inputs-from . \
  nix-darwin#darwin-rebuild -- switch --flake "$PWD#workMac"
```

The installed `nix.conf` and `nix.custom.conf` match nix-darwin's known
installer defaults. Activation backs them up with a `.before-nix-darwin`
suffix and takes over the daemon. If they have changed since inspection, review
the settings and migrate any needed changes into `nix.settings` before
handling the reported conflicts. Keep secrets out of the Nix store.

Activation can stop if an existing `/etc` file or Home Manager file conflicts
with a generated file. Review any reported conflict and back it up or resolve
it deliberately; do not overwrite work-managed configuration blindly.

Since the existing zsh configuration remains unmanaged, add the following
near the end of `~/.zshrc`, after any existing PATH modifications:

```zsh
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"
if [ -r "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh" ]; then
  . "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
fi
eval "$(devenv hook zsh)"
```

Restart zsh, then run `nix --version` and `devenv --version`. To use devenv,
run `devenv init` in a new project or `devenv shell` in an existing one.
For automatic activation, run `devenv allow` in a trusted project; use
`devenv revoke` to remove that trust.

## Updating

Edit this host's configuration, then run
`sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$PWD#workMac"`
from the repository root.
Update the locked nixpkgs input to update Nix and devenv, and update nix-darwin
and Home Manager as appropriate with `nix flake update`. Do not use
`nix upgrade-nix` to update the nix-darwin-managed daemon. The original
installer receipt and store volume remain in place; do not run the installer
uninstaller on an active nix-darwin installation. Keep the existing
`system.stateVersion` and `home.stateVersion` values unless you have read
the relevant migration notes.

An optional GitHub access token can reduce Nix GitHub API rate limiting; put
it in your private `~/.config/nix/nix.conf`, never in this repository.
