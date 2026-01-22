{
  description = "PolicyPress - Policy documentation and compliance tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pinned nixpkgs for zola 0.20.0
    nixpkgs-zola.url = "github:NixOS/nixpkgs/a421ac6595024edcfbb1ef950a3712b89161c359";
    flake-parts.url = "github:hercules-ci/flake-parts";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    eisvogel-tex.url = "github:sc2in/eisvogel-tex";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-zola,
    flake-parts,
    zig-overlay,
    eisvogel-tex,
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        pkgs,
        system,
        ...
      }: let
        pkgsWithOverlay = import nixpkgs {
          inherit system;
          overlays = [zig-overlay.overlays.default];
        };

        # Pinned zola 0.20.0
        pkgsZola = import nixpkgs-zola {inherit system;};

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
          pkgsZola.zola
          imagemagick
          eisvogel-tex.packages.${system}.default
        ];

        zig = pkgsWithOverlay.zigpkgs."0.15.2";

        # Fetch Zig dependencies as a fixed-output derivation
        zigDeps = pkgsWithOverlay.stdenv.mkDerivation {
          pname = "policypress-zig-deps";
          inherit version;
          src = ./.;

          nativeBuildInputs = [zig pkgsWithOverlay.curl pkgsWithOverlay.git];

          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-Tgr0ki9qehIMGuQipUopPVXMGo1uzR/ErB3HocJaOBc=";

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

          src = ./.;

          nativeBuildInputs = [zig];
          buildInputs = runtimeDeps;

          dontConfigure = true;
          dontInstall = true;

          buildPhase = ''
            export HOME=$TMPDIR

            # Copy deps to writable location
            cp -r ${zigDeps} $TMPDIR/zig-cache
            chmod -R u+w $TMPDIR/zig-cache
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache

            zig build \
              --prefix $out \
              -Doptimize=ReleaseSafe \
              --color off \
              --cache-dir $TMPDIR/.cache \
              --global-cache-dir $ZIG_GLOBAL_CACHE_DIR 2>&1 | grep -v "falling back to default ABI"
          '';
        };

        # Wrapper script for CI usage
        policypress-ci = pkgsWithOverlay.writeShellApplication {
          name = "policypress";
          runtimeInputs = runtimeDeps ++ [zig];
          text = ''
            set -euo pipefail

            CONFIG_FILE="''${CONFIG_FILE:-config.toml}"
            CONTENT_DIR="''${CONTENT_DIR:-content}"
            DRAFT_MODE="''${DRAFT_MODE:-true}"
            REDACT_MODE="''${REDACT_MODE:-true}"
            PREFIX="''${PREFIX:-zig-out}"

            BUILD_ARGS=("-Doptimize=ReleaseSafe" "--prefix" "$PREFIX")

            if [ "$DRAFT_MODE" = "true" ]; then
              BUILD_ARGS+=("-Ddraft=true")
            fi

            if [ "$REDACT_MODE" = "true" ]; then
              BUILD_ARGS+=("-Dredact=true")
            fi

            echo "Running PolicyPress with:"
            echo "  Config: $CONFIG_FILE"
            echo "  Content: $CONTENT_DIR"
            echo "  Draft: $DRAFT_MODE"
            echo "  Redact: $REDACT_MODE"
            echo "  Output: $PREFIX"

            zig build "''${BUILD_ARGS[@]}"

            echo "Build complete. Outputs:"
            echo "  PDFs: $PREFIX/pdfs"
            echo "  Site: $PREFIX/public"
          '';
        };
      in {
        packages = {
          default = policypress;
          ci = policypress-ci;
        };

        apps.default = {
          type = "app";
          program = "${policypress-ci}/bin/policypress";
        };

        devShells.default = pkgsWithOverlay.mkShell {
          buildInputs =
            runtimeDeps
            ++ [
              zig
              pkgsWithOverlay.zls
              pkgsWithOverlay.watchexec
              pkgsWithOverlay.act
            ];
        };
      };
    };
}
