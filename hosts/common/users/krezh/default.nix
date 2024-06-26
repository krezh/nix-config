{
  pkgs,
  config,
  outputs,
  inputs,
  lib,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
  hostName = config.networking.hostName;
in
{
  users = {
    mutableUsers = false;
    users = {
      krezh = {
        hashedPasswordFile = config.sops.secrets.krezh-password.path;
        isNormalUser = true;
        shell = pkgs.fish;
        extraGroups =
          [
            "wheel"
            "video"
            "audio"
          ]
          ++ ifTheyExist [
            "minecraft"
            "network"
            "wireshark"
            "i2c"
            "mysql"
            "docker"
            "podman"
            "git"
            "libvirtd"
            "deluge"
          ];
      };
    };
  };

  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs hostName;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      # Import your home-manager configuration
      krezh = import ../../../../home/krezh;
    };
  };

  services.tailscale.enable = true;

  environment = {
    noXlibs = lib.mkForce false;
    etc = lib.mapAttrs' (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    }) config.nix.registry;
    systemPackages = with pkgs; [
      wget
      git
      inputs.deadnix.packages.${pkgs.system}.deadnix
    ];
  };
}
