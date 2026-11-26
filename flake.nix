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
