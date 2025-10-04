{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.nixosModules.desktop.mount;

  mountOptions =
    { name, ... }:
    {
      options = {
        enable = mkEnableOption "this mount";

        type = mkOption {
          type = types.enum [
            "smb"
            "nfs"
          ];
          description = "Mount type (SMB/CIFS or NFS)";
        };

        server = mkOption {
          type = types.str;
          description = "Server address (hostname or IP)";
        };

        share = mkOption {
          type = types.str;
          description = "Share/export name or path";
        };

        mountPoint = mkOption {
          type = types.str;
          default = "/mnt/${name}";
          description = "Local mount point";
        };

        credentialsFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to the credentials file (SMB only)";
        };

        domain = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Domain for authentication (SMB only, optional)";
        };

        securityMethod = mkOption {
          type = types.str;
          default = "ntlmssp";
          description = "Security method for SMB (ntlmssp, ntlm, krb5, etc.)";
        };

        smbVersion = mkOption {
          type = types.nullOr types.str;
          default = "3.1.1";
          description = "SMB protocol version (1.0, 2.0, 2.1, 3.0, 3.1.1).";
        };

        uid = mkOption {
          type = types.int;
          default = 1000;
          description = "User ID for mounted files";
        };

        gid = mkOption {
          type = types.int;
          default = 100;
          description = "Group ID for mounted files";
        };

        nfsVersion = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "NFS version (3, 4, 4.1, 4.2, etc.) - NFS only";
        };

        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional mount options";
        };

        timeoutIdleSec = mkOption {
          type = types.int;
          default = 600;
          description = "Idle timeout in seconds before unmounting";
        };

        autoMount = mkOption {
          type = types.bool;
          default = true;
          description = "Enable automounting";
        };
      };
    };

  enabledMounts = filterAttrs (_name: mount: mount.enable) cfg.mounts;

  mkSmbOptions =
    mount:
    let
      opts = [
        "uid=${toString mount.uid}"
        "gid=${toString mount.gid}"
        "sec=${mount.securityMethod}"
      ]
      ++ (optional (mount.smbVersion != null) "vers=${mount.smbVersion}")
      ++ (optional (mount.credentialsFile != null) "credentials=${mount.credentialsFile}")
      ++ (optional (mount.domain != null) "domain=${mount.domain}")
      ++ mount.extraOptions;
    in
    concatStringsSep "," opts;

  mkNfsOptions =
    mount:
    let
      opts =
        (optional (mount.nfsVersion != null) "vers=${mount.nfsVersion}")
        ++ [
          "rsize=1048576"
          "wsize=1048576"
          "hard"
          "timeo=10"
          "retrans=2"
          "noatime"
          "async"
        ]
        ++ mount.extraOptions;
    in
    concatStringsSep "," opts;

  mkSystemdMount = _name: mount: {
    type = if mount.type == "smb" then "cifs" else "nfs";
    what =
      if mount.type == "smb" then
        "//${mount.server}/${mount.share}"
      else
        "${mount.server}:${mount.share}";
    where = mount.mountPoint;
    mountConfig.Options = [
      (if mount.type == "smb" then mkSmbOptions mount else mkNfsOptions mount)
    ];
  };

  mkSystemdAutoMount = _name: mount: {
    wantedBy = [ "multi-user.target" ];
    where = mount.mountPoint;
    automountConfig.TimeoutIdleSec = toString mount.timeoutIdleSec;
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

in
{
  options.nixosModules.desktop.mount = {
    enable = mkEnableOption "SMB/CIFS and NFS mount service";

    mounts = mkOption {
      type = types.attrsOf (types.submodule mountOptions);
      default = { };
      description = "SMB and NFS mounts configuration";
    };
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems =
      (optional (any (m: m.type == "smb") (attrValues enabledMounts)) "cifs")
      ++ (optional (any (m: m.type == "nfs") (attrValues enabledMounts)) "nfs");

    services.rpcbind.enable = mkIf (any (m: m.type == "nfs") (attrValues enabledMounts)) true;

    systemd.tmpfiles.rules = map (
      mount: "d ${mount.mountPoint} 0755 ${toString mount.uid} ${toString mount.gid} -"
    ) (attrValues enabledMounts);

    systemd.mounts = mapAttrsToList mkSystemdMount enabledMounts;

    systemd.automounts = mapAttrsToList mkSystemdAutoMount (
      filterAttrs (_name: mount: mount.autoMount) enabledMounts
    );

    environment.systemPackages = mkIf (any (m: m.type == "nfs") (attrValues enabledMounts)) [
      pkgs.nfs-utils
    ];

    systemd.services = mkIf (enabledMounts != { }) {
      "network-online.target" = {
        wantedBy = [ "multi-user.target" ];
      };
    };
  };
}
