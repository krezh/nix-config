{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./udev-rules
  ];
  console = {
    earlySetup = false;
  };

  services.xserver.videoDrivers = [ "modesetting" ];
  boot = {
    initrd = {
      verbose = false;
      availableKernelModules = [
        "vmd"
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
    };
    consoleLogLevel = 0;
    #kernelModules = [ "amdgpu" ];
    kernelParams = [
      "ipv6.disable=1"
      "split_lock_detect=off"
      "quiet"
      "loglevel=3"
      "systemd.show_status=auto"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
    ];
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
