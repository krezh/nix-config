{ pkgs, inputs, ... }:
{
  imports = [ ];
  environment.systemPackages = with pkgs; [
    wget
    git
    deadnix
    usbutils
    nix-init
    nix-update
    inputs.nixd.packages.${pkgs.system}.nixd
    nix-inspect
    # Thumbnails
    ffmpeg-headless
    ffmpegthumbnailer
    libheif
    libheif.out
    nufraw
    nufraw-thumbnailer
    gdk-pixbuf
  ];

  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

  environment.pathsToLink = [
    "share/thumbnailers"
  ];

  programs.nh = {
    enable = true;
  };
}
