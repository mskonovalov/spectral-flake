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

        version = "6.15.0";  # You can update this version as needed

        # Define a map of hashes for each platform and architecture combination
        # nix hash to-sri --type sha256  $(nix-prefetch-url https://github.com/stoplightio/spectral/releases/download/v6.15.0/spectral-alpine-arm64)
        hashes = {
          "macos-x64" = "sha256-42LXwXZvmHw8f03qtZAOonlGSqPSSV7nWSmOOY8eu0I=";
          "macos-arm64" = "sha256-3LO02JQm4vUywQ0BFdk6mwunizMA4IU7rBadcKKfDuY=";
          "linux-x64" = "sha256-TjdF86rPwPkZZXeiBMd3kNV9SUfjegUebDQvhbQyYY8=";
          "linux-arm64" = "sha256-TS35rIhal7Buu9B+4vrJIV3Jvu8oq/Tj/t5lF7fs8qE=";
          "alpine-x64" = "sha256-mkyoXFSQLGRGFRhIvo0XH91gUeMyig8+4uJZ7UNGW4Y=";
          "alpine-arm64" = "sha256-vsOyVZdaax3jxPx7KmgWjOkrCB9J0jrEx6HZrq/3mFM=";
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
