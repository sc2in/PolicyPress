{
  description = "PolicyPress - Policy documentation and compliance tooling";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
    zig2nix.url = "https://flakehub.com/f/Cloudef/zig2nix/0.1.*.tar.gz";
    flake-parts.url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*.tar.gz";
    git-hooks.url = "https://flakehub.com/f/cachix/git-hooks.nix/0.1.*.tar.gz";
    treefmt-nix.url = "https://flakehub.com/f/numtide/treefmt-nix/0.1.*.tar.gz";
    # The Secure Controls Framework dataset (https://securecontrolsframework.com,
    # CC BY-ND 4.0) — SC2's validated canonical pipeline. Source of truth for
    # the flat control catalog in data/scf.{json,yml}.
    scf = {
      url = "github:sc2in/scf";
      flake = false;
    };
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

            # mitex version, parsed from the `#import "@preview/mitex:X"` line in
            # src/typst.zig — the single source of truth for the version the PDF
            # math path imports. `typstWithMath` below asserts the nixpkgs-vendored
            # package matches this, so a nixpkgs mitex bump fails loudly here at
            # eval time (with an actionable message) instead of as a non-obvious
            # typst "package not found" error deep in the pdf-accessibility build.
            mitexImportVersion =
              let
                src = builtins.readFile ./src/typst.zig;
                # The import lives in a Zig string literal, so its closing quote
                # is backslash-escaped in the source (`mitex:0.2.7\"`). Capture
                # just the version digits; `[0-9.]+` stops at the backslash.
                match = builtins.match ".*@preview/mitex:([0-9.]+).*" src;
              in
              if match != null then
                builtins.head match
              else
                throw "flake.nix: could not find the `@preview/mitex:X` import version in src/typst.zig";

            # Pin Zig 0.16.0 from zig2nix rather than nixpkgs' `pkgs.zig`, which
            # tracks an older release than this project's minimum_zig_version.
            zig = zig2nix.outputs.packages.${system}."zig-0_16_0";
            env = zig2nix.outputs.zig-env.${system} { inherit zig; };

            # `zig fetch` unpacks a package into `$PWD/zig-pkg/<hash>`, staging it
            # in `$PWD/zig-pkg/.tmp-<hex64>/` first. Because zig-pkg/ lives inside
            # the build root, fetching the build root itself (`zig fetch .`) walks
            # a source tree that contains its own destination: zig-pkg is copied
            # into the package being created, and each repeat doubles the tree —
            # size, inode count, and one more nesting level per run. One such run
            # left 38 nested copies of this repo in zig-pkg/.
            #
            # Nothing in this flake, build.zig.zon, or CI fetches a path, so this
            # only fires on a hand-typed `zig fetch .`. The devShell therefore
            # shadows `zig` with a wrapper that refuses exactly that case and
            # execs the real compiler for everything else. Nix builds keep the
            # unwrapped `zig`: they run in the sandbox against a read-only source
            # copy, where the destination can never be inside the source.
            zigGuarded = pkgs.writeShellScriptBin "zig" ''
              if [ "''${1:-}" = "fetch" ]; then
                cwd=$(pwd -P)
                for arg in "$@"; do
                  case "$arg" in
                    -*) continue ;;
                  esac
                  [ -d "$arg" ] || continue
                  src=$(cd -- "$arg" && pwd -P) || continue
                  case "$cwd/" in
                    "$src"/*)
                      echo "zig: refusing 'zig fetch $arg' — the fetch source contains the" >&2
                      echo "  build root, so it would copy zig-pkg/ into its own staging" >&2
                      echo "  dir and recurse until the disk fills." >&2
                      echo "" >&2
                      echo "  To refresh one dependency, fetch it by URL instead:" >&2
                      echo '    zig fetch --save=<name> "git+https://…?ref=vX.Y.Z#<commit>"' >&2
                      exit 1
                      ;;
                  esac
                done
              fi
              exec ${zig}/bin/zig "$@"
            '';

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
                    # Templates read the SCF catalog / praxis join at build time
                    # via `load_data` (e.g. the `control` shortcode's title
                    # tooltip and spine badge), so the check needs `data/`.
                    ./data
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

            # typst with the mitex package vendored into its offline package
            # cache, so `@preview/mitex` resolves in the hermetic build (opt-in
            # policy math renders TeX via mitex). typst's `@preview/mitex:X` import
            # is version-exact, so the vendored package MUST match the version in
            # src/typst.zig. Assert that here — reading the version off the same
            # `p.mitex` that gets vendored — so a nixpkgs bump that drifts the two
            # apart is a loud, actionable eval-time failure, not a cryptic compile.
            typstWithMath = pkgs.typst.withPackages (
              p:
              if p.mitex.version == mitexImportVersion then
                [ p.mitex ]
              else
                throw ''
                  mitex version mismatch: nixpkgs provides mitex ${p.mitex.version}, but src/typst.zig imports `@preview/mitex:${mitexImportVersion}`.
                  Update the `#import "@preview/mitex:X"` line in src/typst.zig to ${p.mitex.version} (and regenerate the math golden with `zig build update-golden`), or pin nixpkgs to a mitex ${mitexImportVersion} release.
                ''
            );

            runtimeDeps = with pkgs; [
              typstWithMath
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
                    # Generated by tools/gen-praxis-join.py (json.dumps, one array
                    # element per line); prettier would collapse short arrays and
                    # break the generator's byte-for-byte reproducible output.
                    "data/praxis-join\\.json"
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

            # data/scf.{json,yml} must never drift from the pinned scf
            # input (the praxis-facts-fresh analog).
            checks.scf-catalog-fresh =
              pkgs.runCommand "scf-catalog-fresh"
                {
                  nativeBuildInputs = [ pkgs.python3 ];
                }
                ''
                  python3 ${./tools/gen-scf-catalog.py} ${inputs.scf} $TMPDIR/data
                  for f in scf.json scf.yml; do
                    if ! diff -q $TMPDIR/data/$f ${./data}/$f; then
                      echo "data/$f has drifted from the pinned scf input." >&2
                      echo "Regenerate: nix run .#gen-scf-catalog" >&2
                      exit 1
                    fi
                  done
                  touch $out
                '';

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
            # GitHub validates the Marketplace metadata in action.yml only when
            # a release is published to the Marketplace, in the release UI — no
            # local tool or CI step looked at it. v1.7.2 delisted the action that
            # way: `description` had grown to 133 characters against a
            # 125-character cap, which merged green, released green, and showed
            # up only as the listing 404ing. This check runs on every PR.
            checks.action-metadata =
              pkgs.runCommand "action-metadata"
                {
                  nativeBuildInputs = [ pkgs.yq-go ];
                }
                ''
                  bash ${./tools/check-action-metadata.sh} ${./action.yml}
                  touch $out
                '';

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

            # praxis is an OPTIONAL overlay (#174): with no `praxis_join`
            # configured, the rendered site must contain ZERO praxis-overlay
            # markup, so praxis is provably removable. Build the demo web output
            # with `praxis_join` commented out and grep the HTML for the overlay
            # tokens; any hit fails. (Bare "praxis" in authored guide prose is
            # fine — only the overlay's own class/marker tokens are checked.)
            checks.praxis-optional =
              pkgs.runCommand "praxis-optional"
                {
                  nativeBuildInputs = [ pkgs.zola ];
                }
                ''
                  cp -r ${zolaCheckSrc}/. .
                  chmod -R u+w .
                  sed -i 's/^praxis_join =/# praxis_join =/' config.toml
                  zola build --output-dir public
                  if grep -rE 'praxis-badge|satisfies-tag--praxis|control-ref--praxis|In praxis control spine|praxis spine coverage' public --include='*.html'; then
                    echo "praxis overlay markup found in the rendered site despite no praxis_join (#174 invariant violated)." >&2
                    exit 1
                  fi
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
            apps.gen-scf-catalog = {
              type = "app";
              program = "${pkgs.writeShellScript "policypress-gen-scf-catalog" ''
                export PATH="${
                  lib.makeBinPath [
                    pkgs.python3
                    pkgs.git
                  ]
                }:$PATH"
                cd "$(git rev-parse --show-toplevel)"
                exec python3 tools/gen-scf-catalog.py ${inputs.scf} data
              ''}";
              meta.description = "Regenerate data/scf.{json,yml} from the pinned scf input";
            };

            # praxis is NOT a pinned input (public repo <-> private GRC repo; the
            # feature must work for any consumer), so this app takes the praxis
            # flake ref as a runtime argument rather than reading `inputs`:
            #   nix run .#gen-praxis-join -- github:sc2in/Praxis --rev <rev>
            # nix is on PATH for the tool's `nix eval` of praxis.joins.policypress;
            # pass --ids-json to skip the eval entirely (offline/CI).
            apps.gen-praxis-join = {
              type = "app";
              program = "${pkgs.writeShellScript "policypress-gen-praxis-join" ''
                export PATH="${
                  lib.makeBinPath [
                    pkgs.python3
                    pkgs.git
                    pkgs.nix
                  ]
                }:$PATH"
                cd "$(git rev-parse --show-toplevel)"
                exec python3 tools/gen-praxis-join.py "$@"
              ''}";
              meta.description = "Regenerate data/praxis-join.json from a praxis flake ref (pass it as an argument)";
            };

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

            # Regression guard: build the shipped starter/ through the full
            # pipeline and assert it produces a working, private-by-default site
            # and PDFs. Reproduces what the Action does for a user repo, so a
            # theme change that would break a real starter (an unguarded template
            # reference, a lost noindex) fails here first. Runnable locally and in
            # CI identically: `nix run .#build-starter`.
            apps.build-starter =
              let
                app = pkgs.writeShellApplication {
                  name = "policypress-build-starter";
                  meta.description = "Build the starter template and assert a working, private-by-default site + PDFs";
                  runtimeInputs = [
                    policypress
                    pkgs.zola
                  ]
                  ++ runtimeDeps;
                  text = ''
                    export TYPST_FONT_PATHS="${typstFonts}/share/fonts"
                    exec bash ${./tools/build-starter.sh}
                  '';
                };
              in
              {
                type = "app";
                program = "${app}/bin/policypress-build-starter";
                meta.description = "Build the starter template and verify it (CI regression guard)";
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
                # Single source of truth, shared with the CI release matrix
                # (.github/workflows/ci.yml reads the same file via jq).
                releaseTargets = (builtins.fromJSON (builtins.readFile ./release-targets.json)).targets;
                app = pkgs.writeShellApplication {
                  name = "policypress-release";
                  meta.description = "Cross-compile policypress for all supported targets";
                  text = ''
                    targets=(${lib.concatStringsSep " " releaseTargets})
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
                  zigGuarded
                  pkgs.act
                  pkgs.omnix
                  pkgs.watchexec
                  zig2nix.outputs.packages.${system}."zls-0_16_0"
                  (pkgs.writeShellScriptBin "update-zon" ''
                    set -euo pipefail
                    # Regenerate build.zig.zon2json-lock after a dependency bump.
                    #
                    # To bump a dep, first edit its URL in build.zig.zon and
                    # refresh that dep's hash by name — never with a bare
                    # `zig fetch --save .`, which recurses into zig-pkg/ and
                    # fills the disk (see zigGuarded above, which now blocks it):
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
                    # zon2lock unpacks every dependency into ./zig-pkg/<hash> and
                    # means to delete each one when it is done reading it, but its
                    # cleanup resolves the path against the dependency dir instead
                    # of the build root — `dir.deleteTree("zig-pkg/<hash>")` where
                    # `dir` already *is* that zig-pkg/<hash>. It silently matches
                    # nothing, so the unpacked trees leak and stale versions pile
                    # up across bumps. zig-pkg/ is a regenerable unpack area
                    # (gitignored; `zig build` re-extracts from the tarballs in
                    # .zig-cache/p), so clear it outright.
                    rm -rf zig-pkg
                    echo "Done. Review with: git diff build.zig.zon2json-lock"
                  '')
                ];

              shellHook = config.pre-commit.installationScript + ''
                export TYPST_FONT_PATHS="${typstFonts}/share/fonts"
                export ZIG_GLOBAL_CACHE_DIR=.zig-cache

                # A leftover zig-pkg/.tmp-* is the signature of a fetch that was
                # interrupted or that recursed into itself. One sat here unnoticed
                # until it had grown 38 levels deep, so say so on shell entry
                # rather than waiting for `dust` to report a 600G checkout.
                if [ -n "$(ls -d zig-pkg/.tmp-* 2>/dev/null)" ]; then
                  echo "warning: leftover zig-pkg/.tmp-* staging dir — a fetch was interrupted"
                  echo "         or recursed. Safe to clear: rm -rf zig-pkg"
                  echo ""
                fi

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
