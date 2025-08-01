{
  buildGo124Module,
  fetchFromGitHub,
  fetchzip,
  installShellFiles,
  lib,
  stdenv,
}:
buildGo124Module rec {
  pname = "fluxcd";
  # renovate: datasource=github-releases depName=fluxcd/flux2
  version = "2.6.4";

  src = fetchFromGitHub {
    owner = "fluxcd";
    repo = "flux2";
    rev = "v${version}";
    hash = "sha256-uUjdS0vcg6XgHBGEr2A+nc9y0QS7cuMLiOckKm+eio4=";
  };

  vendorHash = "sha256-U37QdGfj7+YXIARORo0AHqgdzrODyUe5DA+eefxzTWA=";

  manifests = fetchzip {
    url = "https://github.com/fluxcd/flux2/releases/download/v${version}/manifests.tar.gz";
    hash = "sha256-PdhR+UDquIJWtpSymtT6V7qO5fVJOkFz6RGzAx7xeb4=";
    stripRoot = false;
  };

  postUnpack = ''
    cp -r ${manifests} source/cmd/flux/manifests

    # disable tests that require network access
    rm source/cmd/flux/create_secret_git_test.go
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.VERSION=${version}"
  ];

  subPackages = [ "cmd/flux" ];

  # Required to workaround test error:
  #   panic: mkdir /homeless-shelter: permission denied
  HOME = "$TMPDIR";

  nativeBuildInputs = [ installShellFiles ];

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/flux --version | grep ${version} > /dev/null
  '';

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    for shell in bash fish zsh; do
      $out/bin/flux completion $shell > flux.$shell
      installShellCompletion flux.$shell
    done
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    changelog = "https://github.com/fluxcd/flux2/releases/tag/v${version}";
    description = "Open and extensible continuous delivery solution for Kubernetes";
    downloadPage = "https://github.com/fluxcd/flux2/";
    longDescription = ''
      Flux is a tool for keeping Kubernetes clusters in sync
      with sources of configuration (like Git repositories), and automating
      updates to configuration when there is new code to deploy.
    '';
    homepage = "https://fluxcd.io";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "flux";
  };
}
