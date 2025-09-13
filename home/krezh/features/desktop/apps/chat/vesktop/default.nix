{ ... }:
{
  hmModules.desktop.vesktop = {
    enable = true;
    service.enable = true;
    settings = {
      appBadge = true;
      arRPC = true;
      enableSplashScreen = false;
      customTitleBar = false;
      disableMinSize = true;
      minimizeToTray = true;
      tray = true;
      staticTitle = false;
      hardwareAcceleration = true;
      hardwareVideoAcceleration = true;
      clickTrayToShowHide = true;
      discordBranch = "stable";
    };
    vencord.settings = {
      autoUpdate = false;
      autoUpdateNotification = true;
      frameless = true;
      notifyAboutUpdates = true;
      transparent = false;
      useQuickCss = true;
      winCtrlQ = false;
      winNativeTitleBar = false;
      plugins = {
        # https://vencord.dev/plugins
        GameActivityToggle.enabled = true;
        NoF1.enabled = true;
        FakeNitro.enabled = true;
        "WebRichPresence (arRPC)".enabled = true;
        WebScreenShareFixes.enabled = true;
      };
      # themeLinks = [
      #   "https://catppuccin.github.io/discord/dist/catppuccin-mocha-lavender.theme.css"
      # ];
    };
  };
}
