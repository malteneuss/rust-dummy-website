{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    # Dev tools
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.treefmt-nix.flakeModule
      ];
      flake = {
        nixosModules.module-rust-dummy-website = {
          systemd.services.rust-dummy-website = {
            enable = true;
            # package = rustapp.packages.${system}.rust-dummy-website;
            serviceConfig = {
              ExecStart = "${self.packages.rust-dummy-website}/bin/rust-dummy-website";
              Restart = "always";
              DynamicUser = true;
              Environment = "RUST_LOG=info";
            };
            wantedBy = [ "multi-user.target" ];
          };
          networking.firewall.allowedTCPPorts = [ 8080 ];
        };
      };
      #      .test = {};
      perSystem = { config, self', pkgs, lib, system, ... }:
        let
          cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
          nonRustDeps = with pkgs; [
            libiconv
            zlib
            openssl.dev
            pkg-config
          ];
          rust-toolchain = pkgs.symlinkJoin {
            name = "rust-toolchain";
            paths = with pkgs; [
              rustc
              cargo
              cargo-watch
              rust-analyzer
              rustPlatform.rustcSrc
            ];
          };
        in
        {
          # Rust package
          packages.rust-dummy-website = pkgs.rustPlatform.buildRustPackage {
            inherit (cargoToml.package) name version;
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;
          };

          packages.default = self'.packages.rust-dummy-website;


          # Rust dev environment
          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.treefmt.build.devShell
            ];
            shellHook = ''
              # For rust-analyzer 'hover' tooltips to work.
              export RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}

              echo
              echo "🍎🍎 Run 'just <recipe>' to get started"
              just
            '';
            buildInputs = nonRustDeps;
            nativeBuildInputs = with pkgs; [
              just
              rust-toolchain
              rustup
              # needed for command line tools like pg_config and psql
              postgresql_15
              # manage database schema and migrations
              dbmate
            ];
            RUST_BACKTRACE = 1;
          };

          # Add your auto-formatters here.
          # cf. https://numtide.github.io/treefmt/
          treefmt.config = {
            projectRootFile = "flake.nix";
            programs = {
              nixpkgs-fmt.enable = true;
              rustfmt.enable = true;
            };
          };
        };
    };
}
