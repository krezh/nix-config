# Provides a set of helper functions to abstract away the complexity of
# building NixOS and home-manager configurations. This library is designed for
# a directory-based, modular configuration structure.
{
  inputs,
  outputs,
  lib,
  ...
}:

let
  # Loads and recursively merges all .nix files from the `vars/` directory.
  # This provides a centralized place for common variables.
  var = builtins.foldl' lib.recursiveUpdate { } (
    map import (lib.scanPath.toList { path = lib.relativeToRoot "vars"; })
  );

  # Creates a `nixpkgs` instance for a given system.
  # Applies the flake's overlays and a default configuration.
  mkPkgsWithSystem =
    system:
    import inputs.nixpkgs {
      inherit system;
      overlays = builtins.attrValues outputs.overlays;
      config = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
      };
      hostPlatform = system;
    };

  # Constructs a full NixOS system configuration.
  #
  # Args:
  #   - `hostname`: The name of the host.
  #   - `config`: An attribute set defining the system's properties, such as
  #     `system`, `homeUsers`, `desktop`, `ci`, and `extraModules`.
  mkSystem =
    hostname: config:
    let
      homeUsers = config.homeUsers or [ ];
      desktop = config.desktop or true;
      ci = config.ci or true;
      # Support profiles, fallback to desktop flag for backward compat
      userProfiles = config.profiles or (if desktop then [ "desktop" ] else [ ]);
      system = lib.nixosSystem {
        pkgs = mkPkgsWithSystem config.system;
        specialArgs = {
          inherit
            inputs
            outputs
            lib
            hostname
            homeUsers
            var
            ;
        };
        modules =
          # Discovers and imports modules from the host's directory.
          (getHostModules {
            inherit hostname;
            commonHost = config.commonHost or true;
          })
          # Appends any extra modules defined in the host's configuration.
          ++ (config.extraModules or [ ])
          # Generates and appends the home-manager configuration.
          ++ mkHomeUsers {
            users = homeUsers;
            profiles = userProfiles;
            inherit hostname;
          };
      };
    in
    # Add ci flag as an accessible attribute
    system // { inherit ci; };

  # Discovers and returns a list of modules for a given host.
  # Includes modules from `hosts/common` if `commonHost` is true.
  getHostModules =
    {
      hostname,
      commonHost ? true,
    }:
    let
      hostPath = lib.relativeToRoot "hosts/${hostname}";
      commonPath = lib.relativeToRoot "hosts/common";
      commonModules = if commonHost then [ (lib.scanPath.toImports commonPath) ] else [ ];
    in
    if lib.pathExists hostPath then commonModules ++ [ (lib.scanPath.toImports hostPath) ] else [ ];

  # Generates the home-manager configuration for a list of users.
  # Automatically imports modules from:
  #   - `home/<username>/base` (always)
  #   - `home/<username>/<profile>` (for each profile in list)
  mkHomeUsers =
    {
      users,
      hostname,
      profiles ? [ ],
    }:
    lib.optionals (users != [ ]) [
      {
        config.home-manager = {
          users = lib.genAttrs users (
            name:
            let
              basePath = lib.relativeToRoot "home/${name}/base";
              # Map profile names to paths
              profilePaths = map (profile: lib.relativeToRoot "home/${name}/${profile}") profiles;
            in
            {
              imports =
                # Always load base
                [ (lib.scanPath.toImports basePath) ]
                # Load each profile in order
                ++ (map (path: lib.scanPath.toImports path) profilePaths)
                # Load shared modules
                ++ outputs.homeManagerModules;
              config.home.username = name;
            }
          );
          backupFileExtension = "bk";
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit
              inputs
              outputs
              hostname
              var
              ;
          };
          sharedModules = [
            inputs.sops-nix.homeManagerModules.sops
          ];
        };
      }
    ];

in
{
  # Creates the final `nixosConfigurations` attribute set for the flake.
  # Takes an attribute set of hosts and their configurations.
  mkSystems = hosts: lib.mapAttrs (hostname: config: mkSystem hostname config) hosts;
}
