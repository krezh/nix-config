{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
{
  home = {
    sessionVariables = {
      DEFAULT_BROWSER = lib.getExe config.programs.chromium.package;
    };
  };

  programs = {
    chromium.enable = true;
    chromium.package = pkgs.vivaldi;
    chromium.commandLineArgs = [
      "--enable-blink-features=MiddleClickAutoscroll"
    ];
  };

  home.packages = [ inputs.zen-browser.packages.${pkgs.system}.default ];
}
