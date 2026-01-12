{
  flake.modules.homeManager.krezh =
    {
      config,
      ...
    }:
    {
      home = {
        username = "krezh";
        sessionVariables = {
          FLAKE = "${config.home.homeDirectory}/nix-config";
          NH_FLAKE = "${config.home.homeDirectory}/nix-config";
          SOPS_AGE_KEY_FILE = "${config.sops.age.keyFile}";
        };
      };
    };
}
