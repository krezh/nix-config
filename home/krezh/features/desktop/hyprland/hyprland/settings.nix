{
  # monitor = [
  #   ", preferred, auto, 1"
  # ];

  env = [ "QT_WAYLAND_DISABLE_WINDOWDECORATION,1" ];

  source = [ "~/.config/hypr/monitors.conf" ]; # nwg displays

  cursor = {
    enable_hyprcursor = true;
  };

  misc = {
    enable_swallow = true;
    mouse_move_enables_dpms = true;
    animate_manual_resizes = false;
  };

  gestures = {
    workspace_swipe = true;
    workspace_swipe_cancel_ratio = 0.15;
  };

  input = {
    kb_layout = "se";
    follow_mouse = 2;
    accel_profile = "flat";
    touchpad = {
      natural_scroll = false;
    };
    sensitivity = "0.4"; # -1.0 - 1.0, 0 means no modification.
  };

  plugins = { };

  general = {
    gaps_in = 3;
    gaps_out = 3;
    border_size = 1;
    "col.active_border" = "$blue";
    "col.inactive_border" = "$base";
    layout = "dwindle";
  };

  decoration = {
    rounding = 15;
    blur = {
      enabled = true;
      size = 4;
      passes = 2;
      new_optimizations = true;
      ignore_opacity = true;
      noise = 1.17e-2;
      contrast = 1.3;
      brightness = 1;
      xray = true;
    };
  };

  animations = {
    enabled = true;
    bezier = [ "1, 0.23, 1, 0.32, 1" ];
    animation = [
      "windows, 1, 5, 1"
      "windowsIn, 1, 5, 1, slide"
      "windowsOut, 1, 5, 1, slide"
      "border, 1, 5, default"
      "borderangle, 1, 5, default"
      "fade, 1, 5, default"
      "workspaces, 1, 5, 1, slidefade 30%"
    ];
  };

  misc = {
    vfr = true; # misc:no_vfr -> misc:vfr. bool, heavily recommended to leave at default on. Saves on CPU usage.
    vrr = false; # misc:vrr -> Adaptive sync of your monitor. 0 (off), 1 (on), 2 (fullscreen only). Default 0 to avoid white flashes on select hardware.
    disable_hyprland_logo = true;
    disable_splash_rendering = true;
  };

  dwindle = {
    pseudotile = true; # enable pseudotiling on dwindle
    force_split = 0;
    preserve_split = true;
    default_split_ratio = 1.0;
    special_scale_factor = 0.8;
    split_width_multiplier = 1.0;
    use_active_for_splits = true;
  };

  master = {
    mfact = 0.5;
    orientation = "right";
    special_scale_factor = 0.8;
    new_status = "slave";
  };

  debug = {
    damage_tracking = 2; # leave it on 2 (full) unless you hate your GPU and want to make it suffer!
  };
}
