# This is an example flake.nix for a Switch project based on devkitA64.
# It will work on any devkitPro example with a Makefile out of the box.
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devkitNix.url = "github:bandithedoge/devkitNix";
    zig-overlay.url = "github:mitchellh/zig-overlay";

    # Used for shell.nix
    flake-compat = {
      url = github:edolstra/flake-compat;
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    devkitNix,
    zig-overlay,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          devkitNix.overlays.default
          zig-overlay.overlays.default
        ];
      };
    in {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [pkgs.devkitNix.devkitARM];

        inherit (pkgs.devkitNix.devkitARM) shellHook;
      };
    });
}
