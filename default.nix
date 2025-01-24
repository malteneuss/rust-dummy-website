{pkgs ? import <nixpkgs> {} }:
pkgs.rustPlatform.buildRustPackage {
  # inherit (cargoToml.package) name version;
  name = "rust-dummy-website";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  buildAndTestSubdir = "subpackage";
}