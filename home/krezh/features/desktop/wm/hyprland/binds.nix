{
  inputs,
  pkgs,
  config,
  ...
}:
let
  hyprlockConfig = config.programs.hyprlock.package;
  anyrunFlake = inputs.anyrun.packages.${pkgs.system};
  anyrun = {
    stdin = "${anyrunFlake.stdin}/lib/libstdin.so";
    applications = "${anyrunFlake.applications}/lib/libapplications.so";
    bin = "${anyrunFlake.default}/bin/anyrun";
  };
  hyprkeysFlake = inputs.hyprkeys.packages.${pkgs.system}.hyprkeys;
  weztermConfig = config.programs.wezterm.package;
in
{
  wayland.windowManager.hyprland = {
    settings = {
      "$mainMod" = "SUPER";
      "$SupShft" = "SUPER SHIFT";

      bind = [
        "$mainMod,ESCAPE,exec,${pkgs.wlogout}/bin/wlogout"
        "$mainMod,L,exec,${hyprlockConfig}/bin/hyprlock"
        "$mainMod,R,exec,${anyrunFlake.default}/bin/anyrun --plugins ${anyrun.applications}"
        "$mainMod,K,exec,${hyprkeysFlake}/bin/hyprkeys -b -r | anyrun --plugins ${anyrun.stdin}"
        # Applications
        "$mainMod,B,exec,${pkgs.firefox}/bin/firefox"
        "$mainMod,E,exec,${pkgs.cinnamon.nemo}/bin/nemo"
        "$mainMod,RETURN,exec,${weztermConfig}/bin/wezterm"
        "$SupShft,RETURN,exec,${weztermConfig}/bin/wezterm"
        "$mainMod,C,exec,${pkgs.clipman}/bin/clipman pick -t rofi"
        "$mainMod,O,exec,${pkgs.obsidian}/bin/obsidian"

        # Hyprland binds
        "$mainMod,Q,killactive"
        "$mainMod,V,togglefloating"
        "$mainMod,P,pseudo"
        "$mainMod,J,togglesplit"
        "$mainMod,F,fullscreen,1"
        "$SupShft,F,fullscreen,2"
        "$SupShft,LEFT,movewindow,l"
        "$SupShft,RIGHT,movewindow,r"
        "$SupShft,UP,movewindow,u"
        "$SupShft,DOWN,movewindow,d"

        # Move focus with mainMod + arrow keys
        "$mainMod,left,movefocus,l"
        "$mainMod,right,movefocus,r"
        "$mainMod,up,movefocus,u"
        "$mainMod,down,movefocus,d"

        # Switch workspaces with mainMod + [0-9]
        "$mainMod,1,workspace,1"
        "$mainMod,2,workspace,2"
        "$mainMod,3,workspace,3"
        "$mainMod,4,workspace,4"
        "$mainMod,5,workspace,5"
        "$mainMod,6,workspace,6"
        "$mainMod,7,workspace,7"
        "$mainMod,8,workspace,8"
        "$mainMod,9,workspace,9"
        "$mainMod,0,workspace,10"

        # Scratchpad
        "$mainMod,S,togglespecialworkspace"
        "$mainModSHIFT,S,movetoworkspace,special"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainModSHIFT,1,movetoworkspace,1"
        "$mainModSHIFT,2,movetoworkspace,2"
        "$mainModSHIFT,3,movetoworkspace,3"
        "$mainModSHIFT,4,movetoworkspace,4"
        "$mainModSHIFT,5,movetoworkspace,5"
        "$mainModSHIFT,6,movetoworkspace,6"
        "$mainModSHIFT,7,movetoworkspace,7"
        "$mainModSHIFT,8,movetoworkspace,8"
        "$mainModSHIFT,9,movetoworkspace,9"
        "$mainModSHIFT,0,movetoworkspace,10"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod,mouse_down,workspace,e+1"
        "$mainMod,mouse_up,workspace,e-1"
        # Hyprland Plugins
        # "$mainMod,TAB,hyprexpo:expo,toggle" # can be: toggle, off/disable or on/enable
      ];

      bindm = [
        # Move/resize windows with mainMod + SHIFT and dragging
        "$mainMod,       mouse:272, movewindow"
        "$mainMod SHIFT, mouse:272, resizewindow"
      ];
    };
  };
}