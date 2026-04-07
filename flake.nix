{
  description = "PolicyPress - Policy documentation and compliance tooling";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
    zig2nix.url = "https://flakehub.com/f/Cloudef/zig2nix/0.1.*.tar.gz";
    eisvogel-tex.url = "github:sc2in/eisvogel-tex";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks.url = "github:cachix/git-hooks.nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      zig2nix,
      eisvogel-tex,
      flake-parts,
      git-hooks,
      treefmt-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        git-hooks.flakeModule
        treefmt-nix.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          pkgs,
          system,
          lib,
          inputs,
          ...
        }:
        let
          # Version from build.zig.zon — single source of truth
          version =
            let
              zon = builtins.readFile ./build.zig.zon;
              match = builtins.match ''.*\.version = "([^"]+)".*'' zon;
            in
            if match != null then builtins.head match else "0.0.0";

          env = zig2nix.outputs.zig-env.${system} { zig = pkgs.zig; };

          # Only include files that affect the build so that content, docs, and
          # theme changes don't bust the Nix build cache.
          buildSrc = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions (
              [
                ./build.zig
                ./build.zig.zon
                ./src
                ./templates
              ]
              ++ lib.optional (builtins.pathExists ./build.zig.zon2json-lock) ./build.zig.zon2json-lock
            );
          };

          fontsConf = pkgs.makeFontsConf {
            fontDirectories = [
              pkgs.source-sans
              pkgs.source-code-pro
            ];
          };

          runtimeDeps =
            with pkgs;
            [
              pandoc
              zola
              imagemagick
              eisvogel-tex.packages.${system}.default
            ]
            ++ lib.optional (system != "aarch64-darwin") pkgs.mermaid-filter;

          withDesc =
            drv: desc:
            drv.overrideAttrs (old: {
              meta = (old.meta or { }) // {
                description = desc;
              };
            });

          mkPolicypress =
            optimize:
            env.package (
              {
                pname = "policypress";
                inherit version;
                src = buildSrc;
                zigBuildFlags = lib.optional (optimize != null) "-Doptimize=${optimize}";
              }
              // lib.optionalAttrs (builtins.pathExists ./build.zig.zon2json-lock) {
                zigBuildZonLock = ./build.zig.zon2json-lock;
              }
            );

          policypress = mkPolicypress "ReleaseSafe";
        in
        {
          # --- Formatting (nix fmt) -------------------------------------------

          treefmt.config = {
            projectRootFile = "flake.nix";
            programs = {
              nixfmt.enable = true;
              prettier = {
                enable = true;
                includes = [
                  "*.scss"
                  "*.js"
                  "*.yaml"
                  "*.yml"
                ];
                excludes = [
                  "sass/bootstrap/.*"
                  "static/plugins/.*"
                  "static/[^/]+\\.js"
                ];
              };
              taplo.enable = true;
            };
          };

          # --- Pre-commit hooks (git commit) ------------------------------------

          pre-commit.settings.hooks =
            let
              vendorExcludes = [
                "^sass/bootstrap/"
                "^static/plugins/"
                "^static/[^/]+\\.js$"
              ];
            in
            {
              treefmt = {
                enable = true;
                package = config.treefmt.build.wrapper;
              };
              trim-trailing-whitespace = {
                enable = true;
                excludes = vendorExcludes ++ [ "\\.md$" ];
              };
              end-of-file-fixer = {
                enable = true;
                excludes = vendorExcludes;
              };
              mixed-line-endings = {
                enable = true;
                args = [ "--fix=lf" ];
                excludes = vendorExcludes;
              };
            };

          # --- Packages --------------------------------------------------------

          packages = {
            default = withDesc (mkPolicypress null) "PolicyPress — compliance policy management toolchain";
            policypress-safe = withDesc policypress "PolicyPress (ReleaseSafe)";
            policypress-small = withDesc (mkPolicypress "ReleaseSmall") "PolicyPress (ReleaseSmall)";
            policypress-fast = withDesc (mkPolicypress "ReleaseFast") "PolicyPress (ReleaseFast)";
          };

          # --- Checks (nix flake check) ----------------------------------------

          checks.formatting = config.treefmt.build.check inputs.self;

          checks.test = (mkPolicypress null).overrideAttrs (old: {
            pname = "policypress-test";
            buildPhase = "zig build test";
            installPhase = "touch $out";
            meta = (old.meta or { }) // {
              description = "Run zig build test";
            };
          });

          # --- Apps (nix run .#<name>) -----------------------------------------

          formatter = config.treefmt.build.wrapper;

          apps.default = {
            type = "app";
            program = "${policypress}/bin/policypress";
            meta.description = "Run policypress (ReleaseSafe)";
          };

          apps.serve =
            let
              app = pkgs.writeShellApplication {
                name = "policypress-serve";
                meta.description = "Live dev server: generate PDFs and serve site with hot reload";
                runtimeInputs = [
                  policypress
                  pkgs.zola
                  pkgs.watchexec
                ]
                ++ runtimeDeps;
                text = ''
                  export FONTCONFIG_FILE="${fontsConf}"
                  mkdir -p static/pdfs
                  policypress -o static/pdfs || true
                  policypress -o static/pdfs --draft || true
                  zola serve &
                  ZOLA_PID=$!
                  trap 'kill "$ZOLA_PID" 2>/dev/null' EXIT INT TERM
                  watchexec -w content -e md -- sh -c \
                    'policypress -o static/pdfs; policypress -o static/pdfs --draft'
                  wait
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/policypress-serve";
              meta.description = "Live development server";
            };

          apps.preview =
            let
              app = pkgs.writeShellApplication {
                name = "policypress-preview";
                meta.description = "Build site and PDFs, then serve the output locally";
                runtimeInputs = [
                  policypress
                  pkgs.zola
                ]
                ++ runtimeDeps;
                text = ''
                  export FONTCONFIG_FILE="${fontsConf}"
                  zola build --base-url "http://0.0.0.0:1111"
                  policypress -o static/pdfs
                  policypress -o static/pdfs --draft
                  zola serve
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/policypress-preview";
              meta.description = "Build and serve a full local preview";
            };

          apps.clean =
            let
              app = pkgs.writeShellApplication {
                name = "policypress-clean";
                meta.description = "Remove all build artifacts";
                text = ''
                  echo "Cleaning build artifacts..."
                  rm -rf .zig-cache zig-out node_modules public resources \
                    static/pdfs .pnpm-store *.err *.log *.core 2>/dev/null || true
                  echo "Done."
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/policypress-clean";
              meta.description = "Remove all build artifacts";
            };

          apps.docs =
            let
              app = pkgs.writeShellApplication {
                name = "policypress-docs";
                meta.description = "Build Zig API documentation and serve it locally";
                runtimeInputs = [ pkgs.zola ];
                text = ''
                  zig build docs
                  zola serve --root zig-out/docs
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/policypress-docs";
              meta.description = "Build and serve Zig API documentation";
            };

          apps.release =
            let
              app = pkgs.writeShellApplication {
                name = "policypress-release";
                meta.description = "Cross-compile policypress for all supported targets";
                text = ''
                  targets=(
                    x86_64-linux
                    x86_64-windows
                    x86_64-macos
                    aarch64-macos
                    aarch64-linux
                    aarch64-windows
                  )
                  for t in "''${targets[@]}"; do
                    echo "▸ Building $t..."
                    zig build -Doptimize=ReleaseSafe -Dtarget="$t"
                  done
                  echo "✓ Release builds complete in zig-out/"
                '';
              };
            in
            {
              type = "app";
              program = "${app}/bin/policypress-release";
              meta.description = "Cross-compile for all supported targets";
            };

          # --- Dev shell -------------------------------------------------------

          devShells.default = pkgs.mkShell {
            buildInputs =
              runtimeDeps
              ++ config.pre-commit.settings.enabledPackages
              ++ [
                policypress
                pkgs.zig
                pkgs.act
                pkgs.omnix
                pkgs.watchexec
                pkgs.typst
                pkgs.zls
                (pkgs.writeShellScriptBin "update-zon" ''
                  set -euo pipefail
                  echo "Updating build.zig.zon dependencies..."
                  zig fetch --save .
                  echo "Regenerating build.zig.zon2json-lock..."
                  zig2nix zon2lock
                  echo "Done."
                '')
              ];

            shellHook = config.pre-commit.installationScript + ''
              export FONTCONFIG_FILE="${fontsConf}"
              export ZIG_GLOBAL_CACHE_DIR=.zig-cache

              # Keep zon2json-lock in sync with build.zig.zon
              if [ -f build.zig.zon ]; then
                if [ ! -f build.zig.zon2json-lock ] || [ build.zig.zon -nt build.zig.zon2json-lock ]; then
                  echo "zig2nix: regenerating build.zig.zon2json-lock..."
                  zig2nix zon2lock
                fi
              fi

              echo "PolicyPress development environment"
              echo ""
              echo "  nix fmt                — format all files"
              echo "  nix build .#           — build policypress (default)"
              echo "  nix run .#serve        — live dev server (PDFs + hot reload)"
              echo "  nix run .#preview      — full build + local preview"
              echo "  nix run .#clean        — remove build artifacts"
              echo "  nix run .#docs         — build and serve API docs"
              echo "  nix run .#release      — cross-compile release builds"
              echo "  nix flake check        — run formatting check + tests"
              echo "  om ci                  — run full CI locally"
            '';
          };
        };
    };
}
