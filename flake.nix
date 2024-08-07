{
  description = "Krezh's NixOS Flake";

  nixConfig = {
    extra-trusted-substituters = [
      "https://krezh.cachix.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://anyrun.cachix.org"
    ];
    extra-trusted-public-keys = [
      "krezh.cachix.org-1:0hGx8u/mABpZkzJEBh/UMXyNon5LAXdCRqEeVn5mff8="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haumea.url = "github:nix-community/haumea/v0.2.2";
    # stylix.url = "github:danth/stylix";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.90.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-update = {
      url = "github:Mic92/nix-update";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-inspect.url = "github:bluskript/nix-inspect";
    nix-inspect.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";
    catppuccin.url = "github:catppuccin/nix";

    nix-index = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixd = {
      url = "github:nix-community/nixd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nh = {
      url = "github:viperml/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland
    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      ref = "refs/tags/v0.41.2";
      submodules = true;
    };

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      inputs.hyprland.follows = "hyprland";
    };

    hyprfocus = {
      url = "github:/pyt0xic/hyprfocus";
      inputs.hyprland.follows = "hyprland";
    };

    hyprhook = {
      url = "github:/Hyprhook/Hyprhook";
      inputs.hyprland.follows = "hyprland";
    };

    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hypridle = {
      url = "github:hyprwm/hypridle";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprlock = {
      url = "github:hyprwm/hyprlock";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprkeys = {
      url = "github:hyprland-community/hyprkeys";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    xdg-portal-hyprland = {
      url = "github:hyprwm/xdg-desktop-portal-hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    swww = {
      url = "github:LGFae/swww";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gBar = {
      url = "github:scorpion-26/gBar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ags = {
      url = "github:Aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server.url = "github:nix-community/nixos-vscode-server";

    wezterm = {
      url = "github:wez/wezterm?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    anyrun = {
      url = "github:anyrun-org/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-grub-themes.url = "github:jeslie0/nixos-grub-themes";

    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell.url = "github:numtide/devshell";
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      self,
      ...
    }:
    let
      inherit (self) outputs;

      lib = nixpkgs.lib // import ./lib { inherit lib; };

      nixosSystem =
        hostName:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit
              self
              inputs
              outputs
              lib
              ;
          };
          modules = [ ] ++ (lib.scanPath.toList { path = ./hosts/${hostName}; });
        };

      mapToGha =
        system:
        if system == "x86_64-linux" then
          "ubuntu-latest"
        else if "x86_64-darwin" then
          "ubuntu-latest"
        else if "aarch64-darwin" then
          "macos-14.0"
        else
          system;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.pre-commit-hooks.flakeModule
        inputs.devshell.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "x86_64-darwin"
      ];

      flake = {
        nixosConfigurations = {
          thor-wsl = nixosSystem "thor-wsl";
          odin = nixosSystem "odin";
        };

        # Used by CI
        top = nixpkgs.lib.genAttrs (builtins.attrNames self.nixosConfigurations) (
          attr: self.nixosConfigurations.${attr}.config.system.build.toplevel
        );
        # Lists hosts with their system kind for use in github actions
        evalHosts = {
          include = builtins.map (host: {
            inherit host;
            system = self.nixosConfigurations.${host}.pkgs.system;
            ghSystem = mapToGha self.nixosConfigurations.${host}.pkgs.system;
          }) (builtins.attrNames self.nixosConfigurations);
        };

        commonModules = (lib.scanPath.toList { path = ./modules/common; });

        overlays = import ./overlays { inherit inputs lib; };
      };

      perSystem =
        { pkgs, config, ... }:
        {
          pre-commit = {
            settings = {
              hooks = {
                nixfmt.enable = true;
                nixfmt.package = pkgs.nixfmt-rfc-style;
                deadnix.enable = true;
                shellcheck.enable = true;
              };
            };
          };

          devshells.default = {
            devshell.startup.pre-commit-hook.text = config.pre-commit.installationScript;
            devshell = {
              name = "Krezh";
              motd = ''
                ❄️ Welcome to {14}{bold}Krezh{reset}'s shell ❄️
              '';
            };
          };

          packages = import ./pkgs { inherit pkgs lib; };
          formatter = pkgs.nixfmt-rfc-style;
        };
    };

}
