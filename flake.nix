{
  description = "noise TUI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    fenix = {
      url = "github:nix-community/fenix/monthly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ fenix.overlays.default ];
            };
          }
        );
    in
    {
      packages = forEachSupportedSystem (
        { pkgs, ... }:
        let
          manifest = (pkgs.lib.importTOML ./Cargo.toml).package;
        in
        {
          default = pkgs.rustPlatform.buildRustPackage {
            pname = manifest.name;
            version = manifest.version;
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;
            nativeBuildInputs = with pkgs; [ pkg-config ];
            buildInputs =
              with pkgs;
              [ ]
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ alsa-lib ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ libiconv ];
          };
        }
      );

      devShells = forEachSupportedSystem (
        { pkgs, system }:
        let
          toolchain = pkgs.fenix.combine [
            (pkgs.fenix.complete.withComponents [
              "cargo"
              "clippy"
              "rust-src"
              "rustc"
              "rustfmt"
            ])
          ];
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs =
              with pkgs;
              [
                self.formatter.${system}
                toolchain
                cargo-expand
                evcxr
                pkg-config
                python3
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ alsa-lib ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ libiconv ];
          };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt-rfc-style);
    };
}
