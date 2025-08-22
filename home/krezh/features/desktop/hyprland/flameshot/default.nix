{
  pkgs,
  ...
}:
{
  services.flameshot = {
    enable = true;
    package = pkgs.flameshot.override { enableWlrSupport = true; };
    settings = {
      General = {
        autoCloseIdleDaemon = true;
        disabledTrayIcon = true;
        contrastOpacity = 188;
        saveAsFileExtension = "png";
        savePath = "/home/krezh/Pictures/Screenshots";
        showAbortNotification = false;
        showDesktopNotification = true;
        showStartupLaunchMessage = false;
        startupLaunch = false;
        useGrimAdapter = true;
        disabledGrimWarning = true;
      };
    };
  };
}
