{
  pkgs,
  lib,
  inputs,
  hostname,
  ...
}:
{
  imports = [
    inputs.chaotic.nixosModules.nyx-cache
    inputs.chaotic.nixosModules.nyx-overlay
    inputs.chaotic.nixosModules.nyx-registry
  ]
  ++ (lib.scanPath.toList { path = ../common/users; })
  ++ (lib.scanPath.toList { path = ../common/global; });

  boot = {
    plymouth = {
      enable = true;
    };
    kernelPackages = pkgs.linuxPackages_cachyos;
    loader = {
      timeout = 1;
      systemd-boot = {
        enable = false;
        configurationLimit = 5;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        configurationLimit = 5;
      };
    };
  };

  services.scx.enable = true; # by default uses scx_rustland scheduler

  xdg.mime.enable = true;
  xdg.mime = {
    addedAssociations = {
      # This shouldn't be necessary, but just for good measure...
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
    defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };

  security.pam.services.krezh.enableGnomeKeyring = true;
  security.pam.services.gdm-password.enableGnomeKeyring = true;
  security.pam.services.hyprlock.enableGnomeKeyring = true;
  programs.seahorse.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.dbus.packages = with pkgs; [
    gnome-keyring
    gcr
    seahorse
    libsecret
    libgnome-keyring
    libnotify
  ];

  nixosModules.desktop = {
    openssh.enable = true;
    fonts.enable = true;
    steam.enable = true;
    openrgb.enable = false;
  };

  services = {
    displayManager = {
      sddm = {
        enable = false;
        wayland.enable = true;
        autoNumlock = true;
        package = pkgs.kdePackages.sddm;
      };
      gdm = {
        enable = true;
        wayland = true;
      };
      defaultSession = "hyprland";
    };

    fstrim.enable = true;

    libinput = {
      enable = true;
      mouse = {
        accelProfile = "flat";
      };
      touchpad = {
        accelProfile = "flat";
      };
    };

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
      audio.enable = true;
    };
  };

  services.udev.packages = [ pkgs.headsetcontrol ];

  networking.networkmanager.enable = true;

  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

  networking.firewall =
    let
      kde-connect = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    in
    {
      allowedTCPPortRanges = kde-connect;
      allowedUDPPortRanges = kde-connect;
    };

  programs.hyprland = {
    enable = true;
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    amdgpu = {
      # rocm clr drivers
      opencl.enable = true;
    };
  };

  security.rtkit.enable = true;

  environment = {
    sessionVariables = {
      NIXOS_OZONE_WL = 1;
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
      WLR_BACKEND = "vulkan";
      PROTON_FSR4_UPGRADE = 1;
      AMD_VULKAN_ICD = "RADV";
      MESA_SHADER_CACHE_MAX_SIZE = "50G";
      __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = 1;
    };
    systemPackages = with pkgs; [
      amdgpu_top
      age-plugin-yubikey
      headsetcontrol
      lutris
      protonup
      heroic
      lact
      wootility
      nautilus
      # Steam
      mangohud
      gamemode
      # WINE
      wine
      winetricks
      protontricks
      vulkan-tools
      # Audio
      pwvucontrol
      better-control
    ];
  };
  networking.hostName = "${hostname}";
}
