{
  flake.modules.homeManager.krezh =
    { config, ... }:
    {
      programs.atuin.settings = {
        sync_address = "https://sh.talos.plexuz.xyz";
        key_path = config.sops.secrets."atuin/key".path;
      };
    };
}
