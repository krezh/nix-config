{
  inputs,
  ...
}:
{
  flake.modules.nixos.thor-wsl =
    {
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      imports = with inputs.self.modules.nixos; [
        # System hierarchy
        system-base

        # User
        krezh

        # External modules
        inputs.nixos-wsl.nixosModules.wsl
        (modulesPath + "/profiles/minimal.nix")
      ];

      networking.hostName = "thor-wsl";

      # WSL configuration
      wsl = {
        enable = true;
        defaultUser = "krezh";
        wslConf.network = {
          hostname = "thor-wsl";
          generateResolvConf = true;
        };
        startMenuLaunchers = false;
        interop.includePath = true;
        useWindowsDriver = true;
        usbip = {
          enable = true;
          autoAttach = [ "7-4" ];
        };
      };

      services.udev.enable = lib.mkForce true;

      programs.nix-ld = {
        enable = true;
        package = pkgs.nix-ld;
      };

      environment.sessionVariables = {
        PODMAN_IGNORE_CGROUPSV1_WARNING = "true";
      };

      boot.isContainer = true;

      services = {
        dbus.apparmor = "disabled";
        resolved.enable = false;
      };

      networking.networkmanager.enable = false;

      security = {
        apparmor.enable = false;
        audit.enable = false;
        auditd.enable = false;
        sudo.wheelNeedsPassword = false;
      };
    };
}
