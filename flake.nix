{
  description = "Gyroflow video-editor plugins (OpenFX)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;

      # Linux-only for now; add aarch64-linux / aarch64-darwin / x86_64-darwin later.
      systems = [ "x86_64-linux" ];

      forAllSystems = f: lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));

      # The bundled lens-profiles database. gyroflow-core's build.rs downloads
      # this at build time if it is missing, and its compile-time
      # include_bytes!() requires it to be present. The build sandbox has no
      # network access, so we fetch it here (outside the sandbox) with a pinned
      # hash and hand it to the derivation, which just copies it into place.
      #
      # All of cargo's *code* dependencies (crates.io, the gyroflow-core git
      # dep, and the ofx-rs fork) are fetched hermetically by nixpkgs'
      # buildRustPackage (useFetchCargoVendor), which runs outside the build
      # sandbox; the build itself then compiles fully offline against the
      # resulting local vendor dir. See packages/ofx.nix.
      profiles-cbor = builtins.fetchurl {
        url = "https://github.com/gyroflow/lens_profiles/releases/latest/download/profiles.cbor.gz";
        sha256 = "5b9136697b75ddf9cda20965f17e786b6c8530e3d59109f87505069602e7f676";
      };
    in
    {
      packages = forAllSystems (pkgs: {
        ofx = pkgs.callPackage ./packages/ofx.nix {
          inherit (pkgs) stdenv rustPlatform pkg-config ocl-icd libglvnd clang libclang lib;
          inherit profiles-cbor;
        };
      });

      devShells = forAllSystems (pkgs: {
        # Drop-in replacement for `just install-deps`: gives you rust, cargo,
        # just, clang/libclang (for ofx_sys's bindgen), OpenCL, pkg-config, zip.
        default = pkgs.mkShell {
          packages = with pkgs; [
            rustPlatform.rust.rustc
            rustPlatform.rust.cargo
            just
            clang
            llvm
            libclang
            pkg-config
            ocl-icd
            zip
          ];
        };
      });
    };
}
