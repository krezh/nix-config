{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixosModules.desktop.steam;
in
{
  options.nixosModules.desktop.steam = {
    enable = lib.mkEnableOption "steam";
  };

  config = lib.mkIf cfg.enable {
    programs.gamemode.enable = true;
    programs = {
      gamescope = {
        enable = true;
        capSysNice = true;
      };
      steam = {
        enable = true;
        remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
        localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
        gamescopeSession.enable = true;
      };
    };
    systemd.user.services.steam = {
      enable = true;
      description = "Steam (no-GUI background startup)";
      #after = [ "graphical-session.target" ]; # wait for networking
      wantedBy = [ "graphical-session.target" ]; # run when your session starts
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.steam} -nochatui -nofriendsui -silent %U";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
