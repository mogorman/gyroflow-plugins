# Builds the Gyroflow OpenFX plugin (openfx/) into a Gyroflow.ofx.bundle.
#
# We use nixpkgs' rustPlatform.buildRustPackage with useFetchCargoVendor, which
# is the standard, hermetic way to build a Rust project under Nix's build
# sandbox (sandbox = true): nix fetches every dependency (crates.io, the
# gyroflow-core git dep, and the ofx-rs fork) into a local vendor dir *outside*
# the sandbox, and the build itself runs fully offline against it.
#
# The only non-cargo input is the lens-profiles bundle (profiles.cbor.gz), a
# data file that gyroflow-core's build.rs downloads at build time if missing and
# that its compile-time include_bytes!() requires. We fetch it (pinned by hash)
# and drop it into the vendored gyroflow-core tree before the build.

{ stdenv, rustPlatform, pkg-config, ocl-icd, libglvnd, clang, libclang, lib, profiles-cbor, ... }:

# Read the version straight from openfx/Cargo.toml so it never drifts.
# The file layout is: line 0 `[package]`, line 1 blank, line 2 `name = ...`,
# line 3 blank, line 4 `version = "x.y.z"`. We read line 4 and extract the
# value; if the layout ever changes and the match fails, fall back to
# "unknown" so the build still proceeds.
let
  toml = builtins.readFile (./../openfx/Cargo.toml);
  lines = lib.split "\n" toml;
  m = builtins.match "version = \"([0-9][^\"]*)\"" (builtins.elemAt lines 4);
  version = if m == null || builtins.length m == 0 then "unknown" else builtins.head m;
in
rustPlatform.buildRustPackage {
  pname = "gyroflow-ofx";
  inherit version;

  # Build the openfx crate (a single cdylib crate). It lives in openfx/ and
  # has a path dependency on ../common, so we keep the whole repo as the
  # source (so common/ is present) and point sourceRoot at the openfx/ subdir.
  # The unpacked source is placed in a directory named after the src, so the
  # source root is "<src-name>/openfx".
  src = ./..;
  sourceRoot = "${builtins.baseNameOf (./..)}/openfx";

  # The Cargo.lock lets buildRustPackage determine the exact set of
  # dependencies to fetch. buildRustPackage runs importCargoLock on this, which
  # expects an attrset with `lockFile` (the path to the lockfile). With
  # useFetchCargoVendor (on by default since nixpkgs 25.05), every dep
  # (crates.io + git deps) is fetched hermetically outside the sandbox into a
  # local vendor dir the build uses offline.
  #
  # `outputHashes` supplies the NAR hashes for the git dependencies, which
  # importCargoLock needs to verify each `fetchGit` (crates.io deps already
  # carry their checksum in the lockfile, but git deps do not).
  cargoLock = {
    lockFile = ../openfx/Cargo.lock;
    outputHashes = {
      "akaze-0.7.0" = "sha256-LZzUpY1512pE4/VVp2wvSVSIFpYrAqWdTpKIsIfJa6I=";
      "app_dirs2-2.5.5" = "sha256-nQ5Cs9r1k/3zjqXJ18Oilk8ErLKim7bGwCXDlQW4GRQ=";
      "cv-core-0.15.0" = "sha256-LZzUpY1512pE4/VVp2wvSVSIFpYrAqWdTpKIsIfJa6I=";
      "cv-pinhole-0.6.0" = "sha256-LZzUpY1512pE4/VVp2wvSVSIFpYrAqWdTpKIsIfJa6I=";
      "eight-point-0.8.0" = "sha256-LZzUpY1512pE4/VVp2wvSVSIFpYrAqWdTpKIsIfJa6I=";
      "fc-blackbox-0.2.0" = "sha256-82DuI0KuHhDVhCMUsnDqk6Fk774VpvoJ1qYFLO+n1X4=";
      "gyroflow-core-1.6.3" = "sha256-w5yG7HL3TjDtdJIhxu0wD5lDZbFIqskXU8hpzi+36s4=";
      "mp4parse-0.17.0" = "sha256-3WsOLuxwFlh2J5gS/DY8MpN3IbBVFim/InyvdKGHO/w=";
      "ofx-0.3.0" = "sha256-syLpTfCpjcOOswFajLtPgNMsoc59wmU9MNErAZfvQaw=";
      "ofx_sys-0.2.0" = "sha256-syLpTfCpjcOOswFajLtPgNMsoc59wmU9MNErAZfvQaw=";
      "rs-sync-0.1.0" = "sha256-VYHvCU4iLTh1wrKvSEL0JsnFRW9FtG5jBo85l3Ftls4=";
      "spirv-std-0.9.0" = "sha256-2paUl8fXUr2mse4j+TSN6et/AH4QTJFEWToZt679maY=";
      "spirv-std-macros-0.9.0" = "sha256-2paUl8fXUr2mse4j+TSN6et/AH4QTJFEWToZt679maY=";
      "spirv-std-types-0.9.0" = "sha256-2paUl8fXUr2mse4j+TSN6et/AH4QTJFEWToZt679maY=";
      "stabilize_spirv-0.0.0" = "sha256-w5yG7HL3TjDtdJIhxu0wD5lDZbFIqskXU8hpzi+36s4=";
      "telemetry-parser-0.3.0" = "sha256-yWrkw2IWKeZO1K+7mewCKttT9mrBOdiE5ozIjIKmYls=";
    };
  };

  # ofx_sys's build script uses bindgen, which needs clang + libclang.
  nativeBuildInputs = [
    clang
    libclang
    pkg-config
    # OpenCL: the `ocl` crate links against libOpenCL at build time; ocl-icd
    # provides the ICD loader's libOpenCL.so.
    ocl-icd
    # OpenGL: the build links against libGL (pulled in transitively); libglvnd
    # provides the libGL.so stub.
    libglvnd
  ];

  # bindgen (used by ofx_sys's build script) locates libclang via
  # LIBCLANG_PATH. The actual libclang.so lives in the *lib* output of the
  # clang package, which lib.getLib extracts.
  LIBCLANG_PATH = "${lib.getLib libclang}/lib";

  # The Justfile exports a vcpkg-specific RUSTFLAGS (-L .../vcpkg/...); we are
  # not invoking `just`, but make sure nothing stale leaks in. We add explicit
  # -L paths so the linker can find libGL (libglvnd) and libOpenCL (ocl-icd),
  # which the cc wrapper does not always put on the linker search path.
  RUSTFLAGS = "-L native=${libglvnd}/lib -L native=${ocl-icd}/lib";

  # The lens-profiles bundle must be present before gyroflow-core's
  # include_bytes! runs. gyroflow-core's source does:
  #   include_bytes!(concat!(env!("CARGO_MANIFEST_DIR"), "/../../resources/camera_presets/profiles.cbor.gz"))
  # When vendored, CARGO_MANIFEST_DIR is <build-root>/cargo-vendor-dir/gyroflow-core-1.6.3,
  # so the bundle must live at <build-root>/resources/camera_presets/. After the
  # unpack phase the cwd is the source root (<build-root>/<src>/openfx), so the
  # build root is two levels up. We drop the bundle there.
  preConfigure = ''
    # The build root is two levels above the source root (cwd).
    build_root="$(cd ../.. && pwd)"
    mkdir -p "$build_root/resources/camera_presets"
    cp ${profiles-cbor} "$build_root/resources/camera_presets/profiles.cbor.gz"
  '';

  # Build with the project's `deploy` profile (LTO + strip, defined in
  # openfx/Cargo.toml). buildRustPackage derives the `--profile <X>` flag from
  # `buildType`, so we set buildType to "deploy" rather than passing a second
  # --profile flag ourselves (which cargo rejects).
  buildType = "deploy";

  # We do NOT define installPhase: that would override nixpkgs' cargoInstallHook,
  # which is what copies the built cdylib (libgyroflow_ofx.so) into $out/lib.
  # Instead we assemble the OpenFX bundle in postInstall, which runs after
  # cargoInstallHook has placed the cdylib in $out/lib.
  postInstall = ''
    # Assemble the OpenFX bundle, mirroring the layout produced by `just deploy`
    # on Linux (openfx/Justfile:78-90). cwd here is the source root
    # (<src>/openfx); the repo root (with LICENSE) is one level up.
    mkdir -p "$out/Gyroflow.ofx.bundle/Contents/Linux-x86-64"
    cp "$out/lib/libgyroflow_ofx.so" \
       "$out/Gyroflow.ofx.bundle/Contents/Linux-x86-64/Gyroflow.ofx"
    cp "res/Info.plist" "$out/Gyroflow.ofx.bundle/Contents/Info.plist"
    cp "../LICENSE" "$out/Gyroflow.ofx.bundle/Contents/LICENSE"

    # Also expose the raw cdylib for convenience.
    cp "$out/lib/libgyroflow_ofx.so" "$out/libgyroflow_ofx.so"

    chmod -R a+rX "$out"
  '';

  meta = {
    description = "Gyroflow OpenFX plugin";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "Gyroflow.ofx";
  };
}
