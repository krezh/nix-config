{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users = {
    mutableUsers = false;
    users = {
      krezh = {
        hashedPasswordFile = config.sops.secrets."passwords/krezh".path;
        isNormalUser = true;
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = lib.strings.splitString "\n" (
          builtins.readFile inputs.ssh-keys.outPath
        );
        extraGroups =
          [
            "wheel"
            "video"
            "audio"
            "sshusers"
          ]
          ++ ifTheyExist [
            "network"
            "networkmanager"
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
}
