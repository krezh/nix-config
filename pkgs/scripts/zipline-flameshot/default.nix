{
  writeShellApplication,
  pkgs,
  ...
}:
writeShellApplication {
  name = "zipline-flameshot";

  runtimeInputs = with pkgs; [
    curl
    jq
    wl-clipboard
  ];

  text = builtins.readFile ./script.sh;
}
