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

        version = "6.14.3";  # You can update this version as needed

        # Define a map of hashes for each platform and architecture combination
        # nix hash to-sri --type sha256  $(nix-prefetch-url https://github.com/stoplightio/spectral/releases/download/v6.14.3/spectral-alpine-arm64)
        hashes = {
          "macos-x64" = "sha256-OdjiwkO3GnocQSLcTLDLgVEw0IPxAP18fWNaJ4c/nP0=";
          "macos-arm64" = "sha256-NQUpOTjCAFtJvPOJBlkf91IpZPqxCm6wF9UDt269YAI=";
          "linux-x64" = "sha256-Kad4Ot7j462pntDroOmxN62BVVN7AnKQM6JCX16e+00=";
          "linux-arm64" = "sha256-D4a7mgh2PIRK3rl/Y2L96F0HqgeHc9OCOQiy47oAiaM=";
          "alpine-x64" = "sha256-INw/q/ZxwSE/D6n2Yo/5AUpR9i5eGi4eL4dlb7GrCOM=";
          "alpine-arm64" = "sha256-Vmw0LO36mflBEe0+U3JqbtsCB7AG2M5PPGGT3rjE+2M=";
        };

        # Get the hash for the current os and arch
        hash = builtins.getAttr "${os}-${arch}" hashes;
      in
      {
        packages = {
          spectral-cli = pkgs.runCommand "spectral-cli-${version}" {
            src = pkgs.fetchurl {
              url = "https://github.com/stoplightio/spectral/releases/download/v${version}/spectral-${os}-${arch}";
              hash = hash;
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
