{ buildGoModule, fetchFromGitHub }:
buildGoModule rec {
  pname = "gh-poi";
  # renovate: datasource=github-releases depName=seachicken/gh-poi
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "seachicken";
    repo = "gh-poi";
    rev = "v${version}";
    hash = "sha256-ZQkXXaa4n88bJdgP2FSXtgBrUi39teO98SzZq+I5doM=";
  };

  vendorHash = "sha256-D/YZLwwGJWCekq9mpfCECzJyJ/xSlg7fC6leJh+e8i0=";
  doCheck = false;
}
