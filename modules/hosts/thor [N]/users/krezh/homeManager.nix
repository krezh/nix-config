{
  inputs,
  ...
}:
{
  flake.modules.homeManager.krezh.imports = with inputs.self.modules.homeManager; [
    # System hierarchy
    system-desktop

    # Programs (module definitions)
    terminal
    editors
    browsers
    media
    launchers
    mail
    ai

    # Desktop environment
    hyprland
    niri
    desktop-shell
    desktop-utils

    # Gaming
    steam
  ];
}
