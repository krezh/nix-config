{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
}:

buildGoModule rec {
  pname = "gowall";
  # renovate: datasource=github-releases depName=Achno/gowall
  version = "0.1.9";

  src = fetchFromGitHub {
    owner = "Achno";
    repo = "gowall";
    rev = "v${version}";
    hash = "sha256-r2IvwpvtWMlIKG0TNM4cLUPKFRgUV8E06VzkPSVCorI=";
  };

  vendorHash = "sha256-H2Io1K2LEFmEPJYVcEaVAK2ieBrkV6u+uX82XOvNXj4=";

  ldflags = [
    "-s"
    "-w"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd gowall \
      --bash <($out/bin/gowall completion bash) \
      --fish <($out/bin/gowall completion fish) \
      --zsh <($out/bin/gowall completion zsh)
  '';

  meta = with lib; {
    description = "A tool to convert a Wallpaper's color scheme / palette";
    homepage = "https://github.com/Achno/gowall";
    license = licenses.mit;
    mainProgram = "gowall";
  };
}
