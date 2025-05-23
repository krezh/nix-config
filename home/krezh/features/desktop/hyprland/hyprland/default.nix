{ pkgs, ... }:
{
  imports = [
    #inputs.hyprland.homeManagerModules.default
    ./binds.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = false;
    #package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    systemd = {
      enable = true;
      variables = [
        "--all"
      ]; # https://wiki.hyprland.org/Nix/Hyprland-on-Home-Manager/#programs-dont-work-in-systemd-services-but-do-on-the-terminal
    };
    settings = import ./settings.nix;
    plugins = [ ];
  };

  home.packages = with pkgs; [
    brightnessctl
    (flameshot.override { enableWlrSupport = true; })
    nwg-displays
  ];
}
