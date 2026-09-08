{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "sofka";
  # renovate: datasource=github-releases depName=nklmilojevic/sofka
  version = "0.25.1";

  src = fetchFromGitHub {
    owner = "nklmilojevic";
    repo = "sofka";
    tag = "v${version}";
    hash = "sha256-lgVen2tJRNT2my+YoeKI+NPSARmKxFokp9TGsoVn93c=";
  };

  cargoHash = "sha256-+nezDRqbLHpSFlElnIu1EjBRryhSqbfB1CGcgv1I+f4=";

  doCheck = false;

  meta = {
    description = "Kubernetes TUI, reimagined in Rust - built on kube-rs and ratatui, async-first from the ground up";
    homepage = "https://github.com/nklmilojevic/sofka";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "sofka";
  };
}
