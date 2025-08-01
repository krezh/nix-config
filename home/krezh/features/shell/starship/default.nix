{ pkgs, lib, ... }:
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      format = "$kubernetes\${custom.talos}\n$username$hostname$git_branch$git_commit$git_state$git_metrics$git_status$fill$cmd_duration$time\n$all";
      kubernetes = {
        format = "\\[[$context:$namespace](bold blue)\\] ";
        symbol = "⎈";
        disabled = false;
        contexts = [
          {
            context_pattern = "admin@talos-plexuz";
            symbol = "⎈";
            context_alias = "talos";
          }
          {
            context_pattern = "^(?<url>[^-]+)-(?<cluster>.+)$";
            symbol = "⎈";
            context_alias = "tp-$cluster";
          }
        ];
      };
      custom.talos = {
        command = "${lib.getExe pkgs.talosctl} config info --output json | ${lib.getExe pkgs.jq} --raw-output '.context'";
        format = "\\[[$output](bold blue)\\] ";
        when = "command -v ${lib.getExe pkgs.talosctl} &>/dev/null";
        disabled = false;
      };
      fill = {
        symbol = " ";
      };
      direnv = {
        disabled = false;
      };
      time = {
        disabled = false;
        style = "bold bright-black";
        format = "[$time]($style)";
      };
      nix_shell = {
        disabled = false;
        impure_msg = "[$name](bold red)";
        pure_msg = "[$name](bold green)";
        unknown_msg = "[$name](bold yellow)";
        format = "\\[[$state](bold blue)\\] ";
        heuristic = true;
      };
      cmd_duration = {
        format = "took [$duration]($style) ";
        style = "yellow bold";
        show_notifications = true;
        min_time_to_notify = 45000;
      };
      username = {
        style_user = "green bold";
        style_root = "red bold";
        format = "[$user]($style)";
        disabled = false;
        show_always = true;
      };
      hostname = {
        ssh_only = false;
        format = "@[$hostname](blue bold) ";
        disabled = false;
      };
      jobs = {
        symbol = " ";
        format = "[$number$symbol]($style) ";
        style = "bold blue";
      };
      sudo = {
        format = "[$symbol ]()";
        symbol = "💀";
        disabled = false;
      };
      container = {
        disabled = true;
      };
      git_branch = {
        symbol = " ";
        format = "[$symbol$branch(:$remote_branch)]($style) ";
      };
      palettes = {
        catppuccin_mocha = {
          rosewater = "#f5e0dc";
          flamingo = "#f2cdcd";
          pink = "#f5c2e7";
          mauve = "#cba6f7";
          red = "#f38ba8";
          maroon = "#eba0ac";
          peach = "#fab387";
          yellow = "#f9e2af";
          green = "#a6e3a1";
          teal = "#94e2d5";
          sky = "#89dceb";
          sapphire = "#74c7ec";
          blue = "#89b4fa";
          lavender = "#b4befe";
          text = "#cdd6f4";
          subtext1 = "#bac2de";
          subtext0 = "#a6adc8";
          overlay2 = "#9399b2";
          overlay1 = "#7f849c";
          overlay0 = "#6c7086";
          surface2 = "#585b70";
          surface1 = "#45475a";
          surface0 = "#313244";
          base = "#1e1e2e";
          mantle = "#181825";
          crust = "#11111b";
        };
      };
    };
  };
}
