{
  writeShellApplication,
  pkgs,
  ...
}:
writeShellApplication {
  name = "zipline-wl-screenrec";

  runtimeInputs = with pkgs; [
    curl
    jq
    wl-clipboard
    wl-screenrec
  ];

  text = builtins.readFile ./script.sh;
}
