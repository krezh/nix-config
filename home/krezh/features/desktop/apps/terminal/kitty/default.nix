{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    # https://sw.kovidgoyal.net/kitty/conf/
    settings = {
      cursor_trail = 1;
      cursor_shape = "block";
      font_size = 11;
      font_family = "family=\"CaskaydiaCove Nerd Font\"";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";
      enable_audio_bell = "no";
      sync_to_monitor = "yes";
      scrollback_lines = 10000;
      extraConfig = ''
        mouse_map right press grabbed,ungrabbed no-op
        mouse_map right click grabbed,ungrabbed paste_from_clipboard
      '';
    };
  };
}
