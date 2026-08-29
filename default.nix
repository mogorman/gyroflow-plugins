# Convenience wrapper so `nix-build` (non-flake) users can build the OpenFX
# plugin without a flake. It reuses the same derivation as the flake.
#
#   nix-build            # builds ./default.nix -> Gyroflow.ofx.bundle
#
# For a fully pinned/reproducible build prefer the flake:  nix build .#ofx
let
  system = builtins.currentSystem;
  nixpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/refs/heads/nixpkgs-unstable.tar.gz";
    # No sha256: this is a convenience entry point, not a pinned build. The
    # flake (flake.nix) is the pinned, reproducible path.
  }) { inherit system; };

  # The bundled lens-profiles database (see flake.nix for the pinned hash).
  profiles-cbor = builtins.fetchurl {
    url = "https://github.com/gyroflow/lens_profiles/releases/latest/download/profiles.cbor.gz";
    sha256 = "5b9136697b75ddf9cda20965f17e786b6c8530e3d59109f87505069602e7f676";
  };
in
nixpkgs.callPackage ./packages/ofx.nix {
  inherit (nixpkgs) stdenv rustPlatform pkg-config ocl-icd clang libclang lib;
  inherit profiles-cbor;
}
