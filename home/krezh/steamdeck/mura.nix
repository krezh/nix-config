{ config, lib, ... }:
let
  cfg = config.programs.steamdeck-mura;
in
{
  options.programs.steamdeck-mura = {
    enable = lib.mkEnableOption "Steam Deck OLED mura correction";

    serialNumber = lib.mkOption {
      type = lib.types.str;
      default = "24F70865C8";
      description = "Steam Deck serial number for mura correction file";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".config/gamescope/mura/${cfg.serialNumber}.tar".source = ./${cfg.serialNumber}.tar;
  };
}
