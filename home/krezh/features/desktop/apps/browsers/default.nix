{
  lib,
  inputs,
  pkgs,
  ...
}:
let
  zen = inputs.zen-browser.packages.${pkgs.system}.default;
in
{
  home = {
    sessionVariables = {
      #DEFAULT_BROWSER = lib.getExe config.programs.chromium.package;
      DEFAULT_BROWSER = lib.getExe zen;
    };
  };

  programs = {
    chromium.enable = true;
    chromium.package = pkgs.vivaldi;
    chromium.commandLineArgs = [
      "--enable-blink-features=MiddleClickAutoscroll"
    ];
  };

  home.packages = [ zen ];
}
