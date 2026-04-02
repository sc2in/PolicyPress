{
  description = "PolicyPress - Policy documentation and compliance tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    eisvogel-tex.url = "github:sc2in/eisvogel-tex";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    zig-overlay,
    eisvogel-tex,
    git-hooks,
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.git-hooks.flakeModule
      ];

      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        config,
        pkgs,
        system,
        lib,
        ...
      }: let
        pkgsWithOverlay = import nixpkgs {
          inherit system;
          overlays = [zig-overlay.overlays.default];
        };
        fontsConf = pkgs.makeFontsConf {
          fontDirectories = [
            pkgs.source-sans # "Source Sans 3" (was "Source Sans Pro")
            pkgs.source-code-pro # "Source Code Pro"
            # Add any additional fonts your documents need:
            # pkgs.source-serif-pro
            # pkgs.noto-fonts
            # pkgs.liberation_ttf
          ];
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
        runtimeDeps = with pkgs; [
          source-sans-pro
          source-code-pro
          pandoc
          zola
          imagemagick
          mermaid-filter
          eisvogel-tex.packages.${system}.default
        ];

        zig = pkgsWithOverlay.zigpkgs."0.15.2";

        # Map Nix system to Zig target triple to avoid native detection in sandbox
        zigTarget =
          {
            "x86_64-linux" = "x86_64-linux-gnu";
            "aarch64-linux" = "aarch64-linux-gnu";
            "x86_64-darwin" = "x86_64-macos";
            "aarch64-darwin" = "aarch64-macos";
          }.${
            system
          };

        # Fetch Zig dependencies as a fixed-output derivation
        zigDeps = pkgsWithOverlay.stdenv.mkDerivation {
          pname = "policypress-zig-deps";
          inherit version;
          src = ./.;

          nativeBuildInputs = [zig pkgsWithOverlay.curl pkgsWithOverlay.git pkgsWithOverlay.cacert];

          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-1ohqMPtZOgDiM+qAoOXcXbiJxz/yCVrrcPJdcFmxhHA=";

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
          FONTCONFIG_FILE = fontsConf;

          buildPhase = ''
            export HOME=$TMPDIR
            # Copy deps to writable location
            cp -r ${zigDeps} $TMPDIR/zig-cache
            chmod -R u+w $TMPDIR/zig-cache
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache

            zig build \
              -Doptimize=ReleaseSafe \
              -Dtarget=${zigTarget} \
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
        pre-commit.settings.hooks = {
          trim-trailing-whitespace = {
            enable = true;
            excludes = ["\\.md$"];
          };
          end-of-file-fixer.enable = true;
          check-yaml.enable = true;
          check-toml.enable = true;
          mixed-line-endings = {
            enable = true;
            args = ["--fix=lf"];
          };
          prettier = {
            enable = true;
            types_or = ["scss" "javascript"];
            args = ["--write"];
          };
        };

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
              policypress
              zig
              pkgsWithOverlay.act
              pkgsWithOverlay.omnix
              pkgsWithOverlay.watchexec
              pkgsWithOverlay.typst
              pkgsWithOverlay.zls
            ];

          shellHook =
            config.pre-commit.installationScript
            + ''
              export FONTCONFIG_FILE="${fontsConf}"
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
