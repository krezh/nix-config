{
  inputs,
  ...
}:
{
  flake.modules.homeManager.krezh.imports = with inputs.self.modules.homeManager; [
    # Programs (module definitions)
    kubernetes
    git
    atuin
    television
    aria2
    superfile
  ];
}
