{
  description = "PolicyPress - Policy documentation and compliance tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    eisvogel-tex.url = "github:sc2in/eisvogel-tex";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    zig-overlay,
    eisvogel-tex,
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        pkgs,
        system,
        lib,
        ...
      }: let
        pkgsWithOverlay = import nixpkgs {
          inherit system;
          overlays = [zig-overlay.overlays.default];
        };

        # Extract version from build.zig.zon (single source of truth)
        version = let
          zon = builtins.readFile ./build.zig.zon;
          match = builtins.match ''.*\.version = "([^"]+)".*'' zon;
        in
          if match != null
          then builtins.head match
          else "0.0.0";

        # Runtime dependencies for PDF generation
        runtimeDeps = with pkgsWithOverlay; [
          pandoc
          zola
          imagemagick
          eisvogel-tex.packages.${system}.default
        ];

        zig = pkgsWithOverlay.zigpkgs."0.15.2";

        # Fetch Zig dependencies as a fixed-output derivation
        zigDeps = pkgsWithOverlay.stdenv.mkDerivation {
          pname = "policypress-zig-deps";
          inherit version;
          src = ./.;

          nativeBuildInputs = [zig pkgsWithOverlay.curl pkgsWithOverlay.git pkgsWithOverlay.cacert];

          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-Tgr0ki9qehIMGuQipUopPVXMGo1uzR/ErB3HocJaOBc=";

          impureEnvVars = pkgsWithOverlay.lib.fetchers.proxyImpureEnvVars;

          SSL_CERT_FILE = "${pkgsWithOverlay.cacert}/etc/ssl/certs/ca-bundle.crt";

          buildPhase = ''
            export HOME=$TMPDIR
            export ZIG_GLOBAL_CACHE_DIR=$out
            zig build --fetch
          '';

          dontInstall = true;
          dontFixup = true;
        };

        policypress = pkgsWithOverlay.stdenv.mkDerivation {
          pname = "policypress";
          inherit version;
          meta.mainProgram = "policypress";
          meta.description = "PolicyPress - Policy documentation and compliance tooling";

          src = ./.;

          nativeBuildInputs = [zig];
          buildInputs = [];

          dontConfigure = true;

          buildPhase = ''
            export HOME=$TMPDIR

            # Copy deps to writable location
            cp -r ${zigDeps} $TMPDIR/zig-cache
            chmod -R u+w $TMPDIR/zig-cache
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache

            zig build \
              -Doptimize=ReleaseSafe \
              -Dtarget=native \
              --prefix $out \
              --color off \
              --cache-dir $TMPDIR/.cache \
              --global-cache-dir $ZIG_GLOBAL_CACHE_DIR
          '';

          installPhase = ''
          '';

          fixupPhase = ''
            chmod -R u+w "$out" 2>/dev/null || true
          '';
        };
      in {
        packages = {
          default = policypress;
        };

        apps.default = {
          type = "app";
          program = "${lib.getExe policypress}";
          inherit (policypress) meta;
        };

        devShells.default = pkgsWithOverlay.mkShell {
          buildInputs =
            runtimeDeps
            ++ [
              zig
              pkgsWithOverlay.zls
              pkgsWithOverlay.watchexec
              pkgsWithOverlay.omnix
            ];

          shellHook = ''
            echo "PolicyPress development environment"
            echo ""
            echo "Commands:"
            echo "  om ci          - Run CI locally (builds & checks all flake outputs)"
            echo "  nix build .#   - Build production artifacts"
            echo "  nix run .#     - Run policypress"
          '';
        };
      };
    };
}
