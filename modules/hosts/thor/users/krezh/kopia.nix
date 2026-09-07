let
  user = "krezh";
in
{
  flake.modules.nixos.thor = {
    home-manager.users.${user} =
      { config, ... }:
      {
        homeModules.kopia = {
          enable = true;
          repository = {
            type = "filesystem";
            path = "/mnt/kopia";
            passwordFile = config.sops.secrets."kopia/password".path;
            requireMountPoint = true;
          };
          backups = {
            downloads = {
              paths = [ "${config.home.homeDirectory}/Downloads" ];
              schedule = "daily";
            };
            obsidian = {
              paths = [ "${config.home.homeDirectory}/Obsidian" ];
              schedule = "daily";
            };
          };
        };
      };
  };
}
