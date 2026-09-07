{
  lib,
  craneLib,
  makeWrapper,
  installShellFiles,
  nix,
}:
craneLib.buildPackage rec {
  pname = "norn";
  version = "0.1.0";

  src = craneLib.cleanCargoSource ./.;
  strictDeps = true;
  cargoArtifacts = craneLib.buildDepsOnly { inherit src strictDeps; };

  nativeBuildInputs = [
    makeWrapper
    installShellFiles
  ];

  postInstall = ''
    wrapProgram $out/bin/norn \
      --prefix PATH : ${lib.makeBinPath [ nix ]}

    installShellCompletion --cmd norn \
      --bash <($out/bin/norn completion bash) \
      --fish <($out/bin/norn completion fish) \
      --zsh <($out/bin/norn completion zsh)
  '';

  meta = {
    description = "Rebuild NixOS and browse the changelogs of every package that changed";
    mainProgram = "norn";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
