{ inputs, ... }:
{
  flake.modules.nixos.thor-wsl = {
    home-manager.users.krezh = {
      imports = with inputs.self.modules.homeManager; [
        #System hierarchy
        system-base
        ai
        krezh
      ];
    };
  };
}
