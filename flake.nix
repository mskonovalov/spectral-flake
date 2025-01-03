{
  description = "A flake that downloads Spectral CLI binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Determine OS and architecture based on system
        os = if pkgs.stdenv.isDarwin then "macos"
             else if pkgs.stdenv.isLinux then 
               (if pkgs.stdenv.buildPlatform.isMusl then "alpine" else "linux")
             else throw "Unsupported system";
             
        arch = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64"
               else if pkgs.stdenv.hostPlatform.isx86_64 then "x64"
               else throw "Unsupported architecture";

        version = "6.11.0";  # You can update this version as needed
      in
      {
        packages = {
          spectral-cli = pkgs.runCommand "spectral-cli-${version}" {
            src = pkgs.fetchurl {
              url = "https://github.com/stoplightio/spectral/releases/download/v${version}/spectral-${os}-${arch}";
              hash = "sha256-Kucw/kR4a8U/l/jcypT7PRsbpfjZLpK25/pMXFxJZ+E=";
            };
          } ''
            mkdir -p $out/bin
            cp $src $out/bin/spectral
            chmod +x $out/bin/spectral
          '';

          default = self.packages.${system}.spectral-cli;
        };
      });
}