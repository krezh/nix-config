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

  services.xserver.videoDrivers = [ "amdgpu" ];
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
    kernelModules = [ "amdgpu" ];
    kernelParams = [
      "ipv6.disable=1"
      "amdgpu.ppfeaturemask=0xfffd3fff"
      "split_lock_detect=off"
      "quiet"
      "udev.log_level=0"
    ];
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
