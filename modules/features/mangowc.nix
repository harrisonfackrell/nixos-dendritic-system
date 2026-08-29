{ self, inputs, ... }: {
    flake.nixosModules.mangowc = { pkgs, lib, ... }: {
        imports = [
            inputs.noctalia.nixosModules.default
        ];
        programs.noctalia = {
            enable = true;
            recommendedServices.enable = true;
        };
        programs.uwsm = {
            enable = true; 
            waylandCompositors = {
                mango = {
                    prettyName = "Mango";
                    comment = "Mango compositor managed by UWSM";
                    binPath = "/run/current-system/sw/bin/mango";
                };
            };
        };
        security.pam.services.swaylock.text = "auth include login";
        services.logind.settings.Login = {
            HandlePowerKey = "suspend";
            HandleLidSwitch = "ignore";
            HandleLidSwitchExternalPower = "ignore";
            HandleLidSwitchDocked = "ignore";
        };
        services.pipewire = {
            enable = true;
            pulse.enable = true;
        };
        environment.systemPackages = [
            pkgs.brightnessctl
            pkgs.playerctl
            pkgs.pavucontrol
            pkgs.firefox
            pkgs.pcmanfm-qt
            pkgs.ashell
            pkgs.kdePackages.dolphin
            pkgs.kdePackages.breeze
            pkgs.kdePackages.breeze-icons
            pkgs.kdePackages.ark
            self.packages.${pkgs.stdenv.hostPlatform.system}.neomango
            inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
    };

    perSystem = { pkgs, lib, ... }: {
        packages.neomango = inputs.wrapper-modules.wrappers.mangowc.wrap {
            inherit pkgs;
            package = pkgs.mango; #necessary until wrapper-modules references correct package
            settings = {
                bind = [
                    "SUPER,1,view,1"
                    "SUPER,2,view,2"
                    "SUPER,3,view,3"
                    "SUPER,4,view,4"
                    "SUPER,5,view,5"
                    "SUPER,6,view,6"
                    "SUPER,7,view,7"
                    "SUPER,8,view,8"
                    "SUPER,9,view,9"
                    "SUPER+SHIFT,1,tagsilent,1"
                    "SUPER+SHIFT,2,tagsilent,2"
                    "SUPER+SHIFT,3,tagsilent,3"
                    "SUPER+SHIFT,4,tagsilent,4"
                    "SUPER+SHIFT,5,tagsilent,5"
                    "SUPER+SHIFT,6,tagsilent,6"
                    "SUPER+SHIFT,7,tagsilent,7"
                    "SUPER+SHIFT,8,tagsilent,8"
                    "SUPER+SHIFT,9,tagsilent,9"
                    "SUPER,w,spawn,firefox"
                    "SUPER,d,spawn,noctalia msg panel-toggle launcher"
                    "SUPER,t,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.neofoot}"
                    "SUPER,f,spawn,pcmanfm-qt"
                    "SUPER+SHIFT,q,killclient"
                    "SUPER+SHIFT,up,zoom"
                    "SUPER,left,focusstack,prev"
                    "SUPER+SHIFT,left,exchange_stack_client,prev"
                    "SUPER,right,focusstack,next"
                    "SUPER+SHIFT,right,exchange_stack_client,next"
                    "SUPER,up,toggleoverview"
                    "SUPER+SHIFT,f,togglefullscreen"
                    "SUPER+ALT,down,incnmaster,-1"
                    "SUPER+ALT,up,incnmaster,+1"
                    "SUPER+ALT,left,setmfact,-0.05"
                    "SUPER+SHIFT+ALT,left,setmfact,0.5"
                    "SUPER+ALT,right,setmfact,+0.05"
                    "SUPER+SHIFT+ALT,right,setmfact,0.05"
                    "NONE,XF86MonBrightnessUp,spawn,brightnessctl s +2%"
                    "SHIFT,XF86MonBrightnessUp,spawn,brightnessctl s 100%"
                    "NONE,XF86MonBrightnessDown,spawn,brightnessctl s 2%-"
                    "SHIFT,XF86MonBrightnessDown,spawn,brightnessctl s 1%"
                    "NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_SINK@ 5%+"
                    "SHIFT,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_SINK@ 100%"
                    "NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_SINK@ 5%-"
                    "SHIFT,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_SINK@ 0%"
                    "NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_SINK@ toggle"
                    "SHIFT,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_SOURCE@ toggle"
                    "NONE,XF86AudioNext,spawn,playerctl next"
                    "NONE,XF86AudioPrev,spawn,playerctl previous"
                    "NONE,XF86AudioPlay,spawn,playerctl play-pause"
                    "SUPER+ALT,t,setlayout,tile"
                    "SUPER+ALT,b,setlayout,vertical_tile"
                    "SUPER,x,spawn,noctalia msg bar-toggle"
                    "SUPER+SHIFT,l,spawn,${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.neoswaylock}"
                    "SUPER+SHIFT,p,spawn,noctalia msg panel-toggle session"
                    "SUPER,b,spawn,noctalia msg panel-toggle control-center power"
                    "SUPER,c,spawn,noctalia msg panel-toggle control-center home"
                    "SUPER,v,spawn,noctalia msg panel-toggle control-center audio"
                ];
                gesturebind = [
                    "none,left,3,viewtoleft"
                    "none,right,3,viewtoright"
                    "none,up,3,toggleoverview"
                ];
                switchbind = [
                    "fold,spawn,mmsg dispatch disable_monitor,eDP-1"
                    "unfold,spawn,mmsg dispatch enable_monitor,eDP-1"
                ];
                monitorrule = [
                    "name:^eDP-1$,width:2560,height:1600,refresh:60,x:0,y:10,scale:1.5"
                ];
                exec-once = [
                    ''${lib.getExe pkgs.swaybg} -i "${pkgs.fetchurl {
                        url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/refs/heads/master/wallpapers/nixos-wallpaper-catppuccin-mocha.png";
                        hash = "sha256-fmKFYw2gYAYFjOv4lr8IkXPtZfE1+88yKQ4vjEcax1s=";
                    }}" -m fill''
                    "noctalia"
                ];
                new_is_master = 0;
                sloppyfocus = 1;
                warpcursor = 1;
                gappih = 0;
                gappiv = 0;
                gappoh = 0;
                gappov = 0;
                smartgaps = 1;
                borderpx = 1;
                default_mfact = 0.5;
            };
        };
        packages.neofuzzel = inputs.wrapper-modules.wrappers.fuzzel.wrap {
            inherit pkgs;
            settings = {
                main = {
                    dpi-aware = "no";
                };
            };
        };
        packages.neofoot = inputs.wrapper-modules.wrappers.foot.wrap {
            inherit pkgs;
            settings = {
                main = {
                    dpi-aware = "yes";
                };
                colors-dark = {
                    alpha = 0.8;
                    alpha-mode = "all";
                };
            };
        };
        packages.neoswaylock = inputs.wrapper-modules.wrappers.swaylock.wrap {
            inherit pkgs;
            settings = {
                image = "${pkgs.fetchurl {
                    url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/9d2cdedd73d64a068214482902adea3d02783ba8/wallpapers/nixos-wallpaper-catppuccin-latte.svg";
                    hash = "sha256-rR2XXN82UBPPxWoLn5DppZO8ei9m8nrO/y3VxSKDP2k=";
                }}";
                scaling = "fill";
            };
        };
    };
}