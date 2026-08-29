<span class="badge-patreon"><a href="https://www.patreon.com/smartislav" title="Donate to this project using Patreon"><img src="https://img.shields.io/badge/patreon-donate-yellow.svg" alt="Patreon donate button" /></a></span>
![example workflow](https://github.com/gyroflow/gyroflow-ofx/actions/workflows/build.yml/badge.svg)

# Gyroflow OpenFX plugin

* Works with stabilization data exported with [gyroflow](http://gyroflow.xyz/)
* Allows you to apply the stabilization right in your OpenFX-capable video editor

# Installation

Grab the archive for your OS from the [releases page](https://github.com/gyroflow/gyroflow-ofx/releases).

## Linux

    mkdir -p /usr/OFX/Plugins
    cd /usr/OFX/Plugins
    sudo unzip ${PATH_TO}/gyroflow-ofx-linux.zip

## MacOS

Copy the `Gyroflow.ofx.bundle` from the archive into the `/Library/OFX/Plugins` directory.
Create the directory if it doesn't exist yet.
Then in Resolve, make sure to go to Preferences -> Video plugins and enable Gyroflow.ofx.bundle.

## Windows

Copy the `Gyroflow.ofx.bundle` from the archive into the `C:\Program Files\Common Files\OFX\Plugins` folder.
Create the folder if it doesn't exist yet.

## For more detailed instructions, see the [docs](https://docs.gyroflow.xyz/app/video-editor-plugins/davinci-resolve-openfx#installation)

# Building from source with Nix

The plugin can be built hermetically with [Nix](https://nixos.org/nix/). The build
fetches every dependency (crates.io, the `gyroflow-core` git dependency, and the
`ofx-rs` fork) outside the build sandbox and compiles fully offline, so the result
is reproducible.

```sh
# Build the plugin; the result is a `Gyroflow.ofx.bundle` in ./result/
nix build .#ofx

# Or, without flakes (uses the pinned nixpkgs + sources from default.nix):
nix-build
```

The produced bundle is at `result/Gyroflow.ofx.bundle/`. Copy it into your editor's
OFX plugins directory as described above. Note that the Nix-built bundle is **not
code-signed**, so on macOS you may need to bypass Gatekeeper, and on some editors
you may need to trust it manually.

To get a development shell (Rust, `just`, clang/libclang for `ofx_sys`'s bindgen,
OpenCL, pkg-config, zip) instead of the manual `just install-deps`:

```sh
nix develop
```

Currently only **Linux (x86_64)** is supported by the flake; macOS and Windows builds
are on the roadmap.

# Usage

### Export `.gyroflow` file in the Gyroflow app

Click the `Export project file (including gyro data)` in the Gyroflow app. You can also use `Ctrl+S` or `Command+S` shortcut

### Basic plugin usage

First you need to apply the plugin to the clip.
In DaVinci Resolve you can do that by going to the Fusion tab and inserting the "Warp -> Gyroflow" after the media input node.
You can also apply the plugin on the Edit or Color page - it should work faster this way.

### Load the .gyroflow file

In DaVinci Resolve, go to the `Gyroflow` plugin settings. Select the `.gyroflow` file in the `Project file` entry.
If your video file is from GoPro 8+, DJI or Insta360, you can also select video file directly. If it's from Sony or it's BRAW - you can also select the video file directly, but you need to load lens profile or preset after that.

## For more detailed instructions, see the [docs](https://docs.gyroflow.xyz/app/video-editor-plugins/general-plugin-workflow)


# License

This software is licensed under GNU General Public License version 3 ([LICENSE](LICENSE))

# Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the GNU General Public License version 3, shall be
licensed as above, without any additional terms or conditions.
