{
  description = "PolicyPress - Policy documentation and compliance tooling";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
    zig2nix.url = "https://flakehub.com/f/Cloudef/zig2nix/0.1.*.tar.gz";
    flake-parts.url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*.tar.gz";
    git-hooks.url = "https://flakehub.com/f/cachix/git-hooks.nix/0.1.*.tar.gz";
    treefmt-nix.url = "https://flakehub.com/f/numtide/treefmt-nix/0.1.*.tar.gz";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      zig2nix,
      flake-parts,
      git-hooks,
      treefmt-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }: {
        imports = [
          git-hooks.flakeModule
          treefmt-nix.flakeModule
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        perSystem =
          {
            config,
            pkgs,
            system,
            lib,
            ...
          }:
          let
            # Version from build.zig.zon - single source of truth
            version =
              let
                zon = builtins.readFile ./build.zig.zon;
                match = builtins.match ''.*\.version = "([^"]+)".*'' zon;
              in
              if match != null then builtins.head match else "0.0.0";

            # Pin Zig 0.16.0 from zig2nix rather than nixpkgs' `pkgs.zig`, which
            # tracks an older release than this project's minimum_zig_version.
            zig = zig2nix.outputs.packages.${system}."zig-0_16_0";
            env = zig2nix.outputs.zig-env.${system} { inherit zig; };

            # Only include files that affect the build so that content, docs, and
            # theme changes don't bust the Nix build cache.
            buildSrc = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions (
                [
                  ./build.zig
                  ./build.zig.zon
                  ./src
                  # Golden Typst-markup snapshot test: the test lives at the repo
                  # root (for @embedFile path resolution), the regenerator under
                  # tools/, and the committed baselines under tests/golden/.
                  ./golden_test.zig
                  ./tools
                  ./tests/golden
                  # Report-PDF fixtures (catalogs + policies) read at test time
                  # by the golden report snapshots; the control-report test also
                  # reads the real data/ catalogs and demo policies.
                  ./tests/report-fixtures
                  ./data
                  ./content/policies
                  # logo.png and draft.png are referenced at test time by the
                  # typst pdf-rendering tests (header/title-page logo and the
                  # draft watermark background).
                  ./static/logo.png
                  ./static/draft.png
                ]
                ++ lib.optional (builtins.pathExists ./build.zig.zon2json-lock) ./build.zig.zon2json-lock
              );
            };

            # Only git-tracked files - excludes generated PDFs, zig-cache, etc.
            zolaCheckSrc = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.intersection (lib.fileset.gitTracked ./.) (
                lib.fileset.unions (
                  [
                    ./config.toml
                    ./content
                    ./templates
                    ./sass
                    ./static
                  ]
                  ++ lib.optional (builtins.pathExists ./theme.toml) ./theme.toml
                )
              );
            };

            # Source for the PDF-accessibility check: the buildable Zig sources
            # plus everything the binary needs to compile the demo policies to
            # PDF (config.toml, content, static). Templates/sass are web-only.
            pdfCheckSrc = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.intersection (lib.fileset.gitTracked ./.) (
                lib.fileset.unions (
                  [
                    ./build.zig
                    ./build.zig.zon
                    ./src
                    ./config.toml
                    ./content
                    ./static
                    # Control catalogs: the build generates the coverage report
                    # PDFs from these, and veraPDF validates every PDF in the
                    # output directory, report PDFs included.
                    ./data
                  ]
                  ++ lib.optional (builtins.pathExists ./build.zig.zon2json-lock) ./build.zig.zon2json-lock
                  ++ lib.optional (builtins.pathExists ./theme.toml) ./theme.toml
                )
              );
            };

            # Source for the redaction-leak-check flake check: it runs a full
            # `zola build` plus PDF generation, so it needs both the web inputs
            # and the buildable Zig sources, plus the test script and control data.
            leakCheckSrc = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.intersection (lib.fileset.gitTracked ./.) (
                lib.fileset.unions (
                  [
                    ./build.zig
                    ./build.zig.zon
                    ./src
                    ./config.toml
                    ./content
                    ./templates
                    ./sass
                    ./static
                    ./data
                    ./tests
                  ]
                  ++ lib.optional (builtins.pathExists ./build.zig.zon2json-lock) ./build.zig.zon2json-lock
                  ++ lib.optional (builtins.pathExists ./theme.toml) ./theme.toml
                )
              );
            };

            # Fonts for typst (Source Sans 3 body, Source Code Pro mono).
            # TYPST_FONT_PATHS is walked recursively by typst-cli; typst falls
            # back to its embedded fonts when a family is missing.
            typstFonts = pkgs.symlinkJoin {
              name = "policypress-typst-fonts";
              paths = [
                pkgs.source-sans
                pkgs.source-code-pro
              ];
            };

            runtimeDeps = with pkgs; [
              # typst with the mitex package vendored into its offline package
              # cache, so `@preview/mitex` resolves in the hermetic build (opt-in
              # policy math renders TeX via mitex). Keep the mitex version here in
              # lock-step with the `#import "@preview/mitex:X"` line in src/typst.zig.
              (typst.withPackages (p: [ p.mitex ]))
              zola
            ];

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
                    "*.json"
                  ];
                  excludes = [
                    "sass/bootstrap/.*"
                    "static/plugins/.*"
                    "static/[^/]+\\.js"
                    # Vendored third-party assets - keep upstream (minified) form
                    ".*\\.min\\.(css|js)$"
                    "static/fontawesome/.*"
                    "static/katex/.*"
                    # Vendored PDF fonts embedded into the binary (@embedFile)
                    "src/fonts/.*"
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
                  ".*\\.min\\.(css|js)$"
                  "^static/fontawesome/"
                  "^static/katex/"
                  "^src/fonts/"
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
              default = withDesc (mkPolicypress null) "PolicyPress - compliance policy management toolchain";
              policypress-safe = withDesc policypress "PolicyPress (ReleaseSafe)";
              policypress-small = withDesc (mkPolicypress "ReleaseSmall") "PolicyPress (ReleaseSmall)";
              policypress-fast = withDesc (mkPolicypress "ReleaseFast") "PolicyPress (ReleaseFast)";
              # The pinned Zig 0.16 toolchain (prebuilt). Exposed so lightweight
              # consumers (e.g. the macOS CI `zig build check`) can get just the
              # compiler without the full devShell, whose zig2nix source-built
              # inputs currently drag glibc into the aarch64-darwin closure.
              zig = withDesc zig "Zig 0.16 toolchain (pinned via zig2nix)";
            };

            # --- Checks (nix flake check) ----------------------------------------

            checks.formatting = config.treefmt.build.check self;

            checks.test =
              # The pdf-rendering tests spawn `typst compile` in the sandbox;
              # mermaid diagrams render in-process via pozeiden (pure Zig), so
              # no Chromium or fontconfig plumbing is needed anymore.
              (mkPolicypress null).overrideAttrs (old: {
                pname = "policypress-test";
                buildPhase = "zig build test";
                installPhase = "touch $out";
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ runtimeDeps;
                TYPST_FONT_PATHS = "${typstFonts}/share/fonts";
                # Deterministic font resolution in and out of the sandbox
                # (typst accepts only "true"/"false" here).
                TYPST_IGNORE_SYSTEM_FONTS = "true";
                meta = (old.meta or { }) // {
                  description = "Run zig build test";
                };
              });

            # Zola validates templates, content, and internal links in the sandbox.
            # PDF links use hardcoded hrefs so they are not checked here.
            checks.zola-check =
              pkgs.runCommand "zola-check"
                {
                  nativeBuildInputs = [ pkgs.zola ];
                }
                ''
                  cp -r ${zolaCheckSrc}/. .
                  chmod -R u+w .
                  zola check --skip-external-links
                  touch $out
                '';

            # Validate the tagged PDFs actually conform to PDF/UA-1, using
            # veraPDF (the PDF Association's reference validator). Builds the
            # demo policies (config.toml has pdf_standard = "ua-1") and fails if
            # any PDF is non-conformant — a regression gate so a rendering change
            # can't silently break accessibility. Runs headless (no GUI).
            #
            # The check's $out carries the validation reports (text + JSON), so
            # the published attestation evidence is literally the CI gate's own
            # hermetic output: any workflow can fetch the identical report via
            # `nix build .#checks.<system>.pdf-accessibility --print-out-paths`
            # (a cache hit on an already-checked commit).
            checks.pdf-accessibility = (mkPolicypress null).overrideAttrs (old: {
              pname = "policypress-pdf-accessibility";
              src = pdfCheckSrc;
              buildPhase = ''
                export HOME="$TMPDIR"
                zig build
                mkdir -p public/pdfs
                ./zig-out/bin/policypress -c config.toml -o public/pdfs
                echo "Validating PDF/UA-1 conformance with veraPDF…"
                mkdir -p "$out"
                # No pipe: veraPDF's nonzero exit on nonconformance must fail
                # the check (a `| tee` would mask it without pipefail).
                verapdf --flavour ua1 --format text public/pdfs/*.pdf > "$out/verapdf-report.txt"
                cat "$out/verapdf-report.txt"
                verapdf --flavour ua1 --format json public/pdfs/*.pdf > "$out/verapdf-report.json"
              '';
              installPhase = "true";
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ runtimeDeps ++ [ pkgs.verapdf ];
              TYPST_FONT_PATHS = "${typstFonts}/share/fonts";
              TYPST_IGNORE_SYSTEM_FONTS = "true";
              # Keep veraPDF's JVM off any display in the sandbox.
              _JAVA_OPTIONS = "-Djava.awt.headless=true";
              meta = (old.meta or { }) // {
                description = "Validate demo PDFs against PDF/UA-1 with veraPDF";
              };
            });

            # zig fmt is not covered by treefmt; check it in CI. Fast, no deps.
            checks.zig-fmt = (mkPolicypress null).overrideAttrs (old: {
              pname = "policypress-zig-fmt";
              buildPhase = "zig fmt --check build.zig src";
              installPhase = "touch $out";
              meta = (old.meta or { }) // {
                description = "zig fmt --check build.zig src";
              };
            });

            # The shipped binary is ReleaseSafe, but `checks.test` runs Debug.
            # Also exercise the tests under ReleaseSafe.
            checks.test-release-safe = (mkPolicypress null).overrideAttrs (old: {
              pname = "policypress-test-release-safe";
              buildPhase = "zig build test -Doptimize=ReleaseSafe";
              installPhase = "touch $out";
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ runtimeDeps;
              TYPST_FONT_PATHS = "${typstFonts}/share/fonts";
              TYPST_IGNORE_SYSTEM_FONTS = "true";
              meta = (old.meta or { }) // {
                description = "Run zig build test -Doptimize=ReleaseSafe";
              };
            });

            # Smoke-run the fuzz targets once each (no coverage-guided fuzzing).
            checks.fuzz-smoke = (mkPolicypress null).overrideAttrs (old: {
              pname = "policypress-fuzz-smoke";
              buildPhase = "zig build fuzz";
              installPhase = "touch $out";
              meta = (old.meta or { }) // {
                description = "Run zig build fuzz (smoke test)";
              };
            });

            # Run the redaction-leak integration check in the sandbox, so it
            # gates `om ci` / `nix flake check` and not only the GitHub step.
            checks.redaction-leak = (mkPolicypress null).overrideAttrs (old: {
              pname = "policypress-redaction-leak";
              src = leakCheckSrc;
              buildPhase = ''
                zig build
                bash tests/redaction-leak-check.sh
              '';
              installPhase = "touch $out";
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ runtimeDeps;
              TYPST_FONT_PATHS = "${typstFonts}/share/fonts";
              TYPST_IGNORE_SYSTEM_FONTS = "true";
              meta = (old.meta or { }) // {
                description = "Run tests/redaction-leak-check.sh";
              };
            });

            # --- Apps (nix run .#<name>) -----------------------------------------

            formatter = config.treefmt.build.wrapper;

            apps.default =
              let
                app = pkgs.writeShellApplication {
                  name = "policypress";
                  runtimeInputs = [ policypress ] ++ runtimeDeps;
                  text = ''
                    export TYPST_FONT_PATHS="${typstFonts}/share/fonts"
                    exec policypress "$@"
                  '';
                };
              in
              {
                type = "app";
                program = "${app}/bin/policypress";
                meta.description = "Run policypress with all runtime dependencies in PATH";
              };

            # Attestation-evidence generators, exposed as flake apps so they run
            # identically in CI and locally (`nix run .#sbom`, `.#check-evidence`,
            # `.#a11y-scan`) with their tools pinned by this flake rather than a
            # floating `nixpkgs#…` reference. Each is a thin wrapper: it puts the
            # required tools on PATH (keeping the ambient PATH so an outer `nix`
            # stays reachable for check-evidence) and runs the script in tools/,
            # which remains the source of truth and directly runnable.
            apps.sbom = {
              type = "app";
              program = "${pkgs.writeShellScript "policypress-sbom" ''
                export PATH="${
                  lib.makeBinPath (
                    [
                      pkgs.jq
                      pkgs.git
                    ]
                    ++ runtimeDeps
                  )
                }:$PATH"
                cd "$(git rev-parse --show-toplevel)"
                exec bash tools/sbom.sh "$@"
              ''}";
              meta.description = "Generate the CycloneDX SBOM (tools/sbom.sh)";
            };

            apps.check-evidence = {
              type = "app";
              program = "${pkgs.writeShellScript "policypress-check-evidence" ''
                export PATH="${
                  lib.makeBinPath [
                    pkgs.jq
                    pkgs.git
                  ]
                }:$PATH"
                cd "$(git rev-parse --show-toplevel)"
                exec bash tools/check-evidence.sh "$@"
              ''}";
              meta.description = "Record flake-check evidence (tools/check-evidence.sh)";
            };

            apps.a11y-scan = {
              type = "app";
              program = "${pkgs.writeShellScript "policypress-a11y-scan" ''
                export PATH="${
                  lib.makeBinPath (
                    [
                      pkgs.chromium
                      pkgs.nodejs
                      pkgs.curl
                      pkgs.coreutils
                    ]
                    ++ runtimeDeps
                  )
                }:$PATH"
                cd "$(git rev-parse --show-toplevel)"
                exec bash tests/a11y/scan.sh "$@"
              ''}";
              meta.description = "axe-core WCAG scan of the served site (tests/a11y/scan.sh)";
            };

            apps.check-release = {
              type = "app";
              program = "${pkgs.writeShellScript "policypress-check-release" ''
                export PATH="${
                  lib.makeBinPath [
                    pkgs.git
                    pkgs.gnugrep
                    pkgs.coreutils
                  ]
                }:$PATH"
                cd "$(git rev-parse --show-toplevel)"
                exec bash tools/check-release.sh "$@"
              ''}";
              meta.description = "Release-tag guards: CHANGELOG + version stamp (tools/check-release.sh)";
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
                    export TYPST_FONT_PATHS="${typstFonts}/share/fonts"
                    mkdir -p static/pdfs

                    # Run the official and draft compilations in parallel on
                    # startup. Both pass --redact to match the demo's deployment
                    # (deploy-docs.yml sets redact_mode = true): with
                    # redact_web = true the policy pages link the "__Redacted__"
                    # filenames, so a non-redacted local build 404s every PDF
                    # link. The random-suffixed temp filenames in policypress
                    # prevent the two processes from colliding on .typ sources.
                    policypress -o static/pdfs --redact &
                    policypress -o static/pdfs --redact --draft &
                    wait

                    zola serve &
                    ZOLA_PID=$!
                    trap 'kill "$ZOLA_PID" 2>/dev/null' EXIT INT TERM

                    watchexec -w content -e md -- sh -c \
                      'policypress -o static/pdfs --redact & policypress -o static/pdfs --redact --draft & wait'
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
                    export TYPST_FONT_PATHS="${typstFonts}/share/fonts"
                    zola build --base-url "http://0.0.0.0:1111"
                    # --redact matches the demo deployment (redact_mode = true);
                    # with redact_web = true the pages link "__Redacted__" PDFs.
                    policypress -o static/pdfs --redact
                    policypress -o static/pdfs --redact --draft
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
                      static/pdfs .pnpm-store -- *.err *.log *.core 2>/dev/null || true
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

            # `nix run .#bump -- <version|patch|minor|major>` performs the manual
            # pre-release steps in one shot: bumps the version in build.zig.zon
            # AND config.toml (kept in sync), rolls the CHANGELOG `[Unreleased]`
            # section into a dated release section, and commits. Pushing the tag
            # is left to you; CI then builds binaries, cuts the GitHub release
            # (auto-generated notes), and publishes to FlakeHub.
            apps.bump =
              let
                app = pkgs.writeShellApplication {
                  name = "policypress-bump";
                  runtimeInputs = with pkgs; [
                    coreutils
                    gnused
                    gawk
                    git
                  ];
                  meta.description = "Bump version (build.zig.zon + config.toml) and roll the CHANGELOG";
                  text = ''
                    dry=0
                    commit=1
                    arg=""
                    for a in "$@"; do
                      case "$a" in
                        --dry-run) dry=1 ;;
                        --no-commit) commit=0 ;;
                        -h | --help)
                          echo "usage: nix run .#bump -- <version|patch|minor|major> [--dry-run] [--no-commit]"
                          exit 0
                          ;;
                        *) arg="$a" ;;
                      esac
                    done

                    if [ -z "$arg" ]; then
                      echo "usage: nix run .#bump -- <version|patch|minor|major> [--dry-run] [--no-commit]" >&2
                      exit 1
                    fi

                    cur=$(sed -nE 's/^[[:space:]]*\.version = "([^"]+)",/\1/p' build.zig.zon | head -n1)
                    if [ -z "$cur" ]; then
                      echo "error: could not read current version from build.zig.zon" >&2
                      exit 1
                    fi

                    cfg=$(sed -nE 's/^version = "([^"]+)"/\1/p' config.toml | head -n1)
                    if [ "$cfg" != "$cur" ]; then
                      echo "note: config.toml version ($cfg) differed from build.zig.zon ($cur); both set to the new version"
                    fi

                    case "$arg" in
                      major | minor | patch)
                        IFS=. read -r ma mi pa <<< "$cur"
                        case "$arg" in
                          major)
                            ma=$((ma + 1))
                            mi=0
                            pa=0
                            ;;
                          minor)
                            mi=$((mi + 1))
                            pa=0
                            ;;
                          patch) pa=$((pa + 1)) ;;
                        esac
                        new="$ma.$mi.$pa"
                        ;;
                      *) new="$arg" ;;
                    esac

                    if ! [[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                      echo "error: invalid version '$new' (expected X.Y.Z or patch|minor|major)" >&2
                      exit 1
                    fi

                    today=$(date +%F)
                    echo "Release: $cur -> $new ($today)"

                    if [ "$dry" = 1 ]; then
                      echo "[dry-run] would update:"
                      echo "  build.zig.zon  .version = \"$new\""
                      echo "  config.toml    version = \"$new\""
                      echo "  CHANGELOG.md   roll [Unreleased] into [$new] - $today"
                      exit 0
                    fi

                    sed -i -E "s/^([[:space:]]*\.version = )\"[^\"]+\",/\1\"$new\",/" build.zig.zon
                    sed -i -E "s/^version = \"[^\"]+\"/version = \"$new\"/" config.toml
                    awk -v ver="$new" -v dt="$today" '
                      !done && /^## \[Unreleased\]/ {
                        print "## [Unreleased]";
                        print "";
                        print "## [" ver "] - " dt;
                        done = 1;
                        next
                      }
                      { print }
                    ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md

                    echo "Updated build.zig.zon, config.toml, CHANGELOG.md"

                    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

                    if [ "$commit" = 1 ]; then
                      git add build.zig.zon config.toml CHANGELOG.md
                      git commit -m "chore: release $new"
                      echo ""
                      echo "Committed 'chore: release $new' on '$branch'."
                    else
                      echo ""
                      echo "Files edited (not committed). Commit with:"
                      echo "  git add build.zig.zon config.toml CHANGELOG.md && git commit -m 'chore: release $new'"
                    fi

                    echo ""
                    echo "Releasing (main is protected: direct pushes are rejected — a PR + green CI is required):"
                    if [ "$branch" = "main" ]; then
                      echo "  ! You are on 'main'. Move the release work onto a branch first:"
                      echo "      git switch -c release-$new"
                      if [ "$commit" = 1 ]; then
                        echo "      git branch --force main origin/main   # rewind local main back to origin"
                      fi
                      echo ""
                    fi
                    echo "  1. Push the release branch and open a PR:"
                    echo "       git push -u origin release-$new"
                    echo "  2. Wait for ci (ubuntu-latest) + ci (macos-latest) to pass, then squash- or rebase-merge."
                    echo "  3. Tag the merged commit on main and push the tag:"
                    echo "       git switch main && git pull"
                    echo "       git tag v$new && git push origin v$new"
                    echo ""
                    echo "The tag push triggers CI to build binaries, cut the GitHub release, and publish to FlakeHub."
                  '';
                };
              in
              {
                type = "app";
                program = "${app}/bin/policypress-bump";
                meta.description = "Bump version and roll the CHANGELOG for a release";
              };

            # --- Dev shells ------------------------------------------------------

            # Minimal shell used by the GitHub Action: runtime build tools only.
            # The policypress binary is installed separately from the release.
            devShells.ci = pkgs.mkShell {
              buildInputs = runtimeDeps;
              shellHook = ''
                export TYPST_FONT_PATHS="${typstFonts}/share/fonts"
              '';
            };

            devShells.default = pkgs.mkShell {
              # Note: the `policypress` package is deliberately NOT a devShell
              # input. Building it requires a valid build.zig.zon2json-lock, but
              # the shellHook below regenerates that lock on entry — so depending
              # on the package here would deadlock the shell whenever a dep bump
              # leaves the lock stale (the sandbox has no network to fetch the
              # new dep). Develop with `zig build` / `nix run .#` instead.
              buildInputs =
                runtimeDeps
                ++ config.pre-commit.settings.enabledPackages
                ++ [
                  zig
                  pkgs.act
                  pkgs.omnix
                  pkgs.watchexec
                  zig2nix.outputs.packages.${system}."zls-0_16_0"
                  (pkgs.writeShellScriptBin "update-zon" ''
                    set -euo pipefail
                    # Regenerate build.zig.zon2json-lock after a dependency bump.
                    #
                    # To bump a dep, first edit its URL in build.zig.zon and
                    # refresh that dep's hash (a bare `zig fetch --save .` hangs
                    # here, so update the one dep by name):
                    #   zig fetch --save=<name> "git+https://…?ref=vX.Y.Z#<commit>"
                    # then run `update-zon`.
                    echo "Fetching the full dependency graph…"
                    zig build --fetch
                    echo "Regenerating build.zig.zon2json-lock…"
                    # zig2nix has no plain `zig2nix` binary on PATH; its CLI is
                    # the flake app, pinned here so this never hits the network.
                    ${zig2nix.apps.${system}.default.program} zon2lock
                    # zon2lock omits the trailing newline that the end-of-file-fixer
                    # pre-commit hook requires; add exactly one.
                    [ -n "$(tail -c1 build.zig.zon2json-lock)" ] && printf '\n' >> build.zig.zon2json-lock
                    echo "Done. Review with: git diff build.zig.zon2json-lock"
                  '')
                ];

              shellHook = config.pre-commit.installationScript + ''
                export TYPST_FONT_PATHS="${typstFonts}/share/fonts"
                export ZIG_GLOBAL_CACHE_DIR=.zig-cache

                # Install the release-tag CHANGELOG guard. The pre-commit
                # framework manages only the pre-commit hook, so pre-push is
                # free for us. Kept in .githooks/ so it is version-controlled.
                hooks_dir="$(git rev-parse --git-path hooks 2>/dev/null || true)"
                if [ -n "$hooks_dir" ] && [ -f .githooks/pre-push ]; then
                  mkdir -p "$hooks_dir"
                  cp -f .githooks/pre-push "$hooks_dir/pre-push"
                  chmod +x "$hooks_dir/pre-push"
                fi

                # build.zig.zon2json-lock is committed and regenerated
                # deliberately on a dependency bump by running `update-zon`
                # inside this dev shell (it wraps `zig build --fetch` + the
                # pinned zig2nix `zon2lock` app; there is no plain `zig2nix`
                # binary on PATH). Not auto-run on shell entry — a stale lock
                # after a bump would otherwise need network the sandbox lacks.

                echo "PolicyPress development environment"
                echo ""
                echo "  nix fmt                - format all files"
                echo "  nix build .#           - build policypress (default)"
                echo "  nix run .#serve        - live dev server (PDFs + hot reload)"
                echo "  nix run .#preview      - full build + local preview"
                echo "  nix run .#clean        - remove build artifacts"
                echo "  nix run .#docs         - build and serve API docs"
                echo "  nix run .#release      - cross-compile release builds"
                echo "  nix flake check        - run formatting check + tests"
                echo "  om ci                  - run full CI locally"
                echo "  update-zon             - regenerate the zon lock after a dep bump"
              '';
            };
          };
      }
    );
}
