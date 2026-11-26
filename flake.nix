{
  description = "A flake that downloads Spectral CLI binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Determine OS and architecture based on system
        os =
          if pkgs.stdenv.isDarwin then
            "macos"
          else if pkgs.stdenv.isLinux then
            (if pkgs.stdenv.buildPlatform.isMusl then "alpine" else "linux")
          else
            throw "Unsupported system";

        arch =
          if pkgs.stdenv.hostPlatform.isAarch64 then
            "arm64"
          else if pkgs.stdenv.hostPlatform.isx86_64 then
            "x64"
          else
            throw "Unsupported architecture";

        version = "6.17.1";  # You can update this version as needed

        # Define a map of hashes for each platform and architecture combination
        # nix hash to-sri --type sha256  $(nix-prefetch-url https://github.com/stoplightio/spectral/releases/download/v6.17.1/spectral-alpine-arm64)
        hashes = {
          "macos-x64" = "sha256-QjVebdhhupWRZMbySHf8d0MAAeJjhV5zebuTXmVm2DY=";
          "macos-arm64" = "sha256-rAgU+oavO1e7gC8ikLt05Vi5UiuZKO8WrCbA0Brm+cU=";
          "linux-x64" = "sha256-AZbHIjRHjk4j3yi2Yq+nyfgKR8/THcaX5nQVGtBguzU=";
          "linux-arm64" = "sha256-cwAFZku+lWgPazSHkLsE2iIOgktuCmdo0WoamIqGsx4=";
          "alpine-x64" = "sha256-DFj/EO9PE6Ahqkpa2TNlAsHeIKhyCo9C2LrkfdLF4h0=";
          "alpine-arm64" = "sha256-+onpAuEhm2/+gvPXdEvT/sKq1Hd4Ks6Lxl//fF7hbhE=";
        };

        # Get the hash for the current os and arch
        hash = builtins.getAttr "${os}-${arch}" hashes;

        name = "spectral-cli";

        src = pkgs.fetchurl {
          url = "https://github.com/stoplightio/spectral/releases/download/v${version}/spectral-${os}-${arch}";
          inherit hash;
        };
      in
      {
        packages = {
          spectral-cli = pkgs.stdenv.mkDerivation {
            inherit name src version;

            dontUnpack = true;

            installPhase = ''
              mkdir -p $out/bin
              cp $src $out/bin/spectral
              chmod +x $out/bin/spectral
            '';

            # pkg records the byte offsets of the JavaScript appended to this binary,
            # so the fixup phase must not strip or patch it
            dontFixup = true;
          };

          default = self.packages.${system}.spectral-cli;
        };
      }
    );
}
