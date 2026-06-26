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

            dontStrip = true;

            preFixup = pkgs.lib.optionalString (pkgs.stdenv.isLinux) ''
                orig_size=$(stat --printf=%s $out/bin/spectral)
                patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/spectral
                patchelf --set-rpath ${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc ]} $out/bin/spectral
                chmod +x $out/bin/spectral
                new_size=$(stat --printf=%s $out/bin/spectral)
                ###### zeit-pkg fixing starts here.
                # we're replacing plaintext js code that looks like
                # PAYLOAD_POSITION = '1234                  ' | 0
                # [...]
                # PRELUDE_POSITION = '1234                  ' | 0
                # ^-----20-chars-----^^------22-chars------^
                # ^-- grep points here

              #
                # var_* are as described above
                # shift_by seems to be safe so long as all patchelf adjustments occur 
                # before any locations pointed to by hardcoded offsets
                var_skip=20
                var_select=22
                shift_by=$(expr $new_size - $orig_size)
                function fix_offset {
                  # $1 = name of variable to adjust
                  location=$(grep -obUam1 "$1" $out/bin/spectral | cut -d: -f1)
                  location=$(expr $location + $var_skip)
                  value=$(dd if=$out/bin/spectral iflag=count_bytes,skip_bytes skip=$location \
                             bs=1 count=$var_select status=none)
                  value=$(expr $shift_by + $value)
                  echo -n $value | dd of=$out/bin/spectral bs=1 seek=$location conv=notrunc
                }
                fix_offset PAYLOAD_POSITION
                fix_offset PRELUDE_POSITION
            '';

          };

          default = self.packages.${system}.spectral-cli;
        };
      }
    );
}
