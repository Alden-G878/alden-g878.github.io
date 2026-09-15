#!/usr/bin/env bash
#
# Regenerate the CV artifacts from cv/cv.tex — the single source of truth.
#
#   assets/pdf/Alden_CV.pdf      the downloadable/fidelity view  (pdflatex)
#   _includes/cv-live.html       the in-page HTML view           (pandoc)
#
# Both are COMMITTED, because native GitHub Pages cannot compile LaTeX or run
# pandoc, and because Jekyll's `include` tag raises IOError when a file is
# missing — a CI-only cv-live.html would break every local build. GitHub Actions
# runs this same script (see .github/workflows/deploy.yml), so there is exactly
# one build path; CI just overwrites the committed copies before `jekyll build`.
#
# Toolchain selection, in order of preference:
#
#   1. Docker (default)  — pinned, reproducible, needs nothing else on the host.
#                          The first run builds a toolchain image (~45 s, once);
#                          later runs are ~0.5 s because TeX is baked in. Previously
#                          every run reinstalled texlive via apt, costing ~30 s.
#                          Bypass with --host to use host binaries instead.
#   2. Host binaries     — used when Docker is unavailable but `pdflatex` AND
#                          `pandoc` are on PATH. Instant, but unpinned: you get
#                          whatever versions you installed.
#   3. Otherwise         — exits with an explanation rather than a broken PDF.
#
# Both paths produce byte-identical artifacts for the same toolchain version
# (verified for the Docker path against the previous output).
#
# Usage:
#   cv/build.sh                  rebuild both artifacts
#   cv/build.sh --html-only      rebuild only _includes/cv-live.html
#   cv/build.sh --pdf-only       rebuild only the PDF
#   cv/build.sh --host           force the host toolchain (skip Docker)
#   cv/build.sh --docker         force Docker (ignore host binaries)
#   cv/build.sh --force-image    rebuild the Docker toolchain image too
#   cv/build.sh --print-image-tag  print the content-hash image tag and exit
#                                  (used by CI to cache the image under the
#                                  name this script looks for)
#
# See cv/BUILD.md for the gotchas that shaped this script.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PDF_OUT="assets/pdf/Alden_CV.pdf"
HTML_OUT="_includes/cv-live.html"

# pandoc, pinned to the version the committed HTML was produced with. A floating
# version would silently rewrite cv-live.html and turn the CI drift check red.
PANDOC_VERSION="3.11"
# sha256 of pandoc-3.11-linux-<arch>.tar.gz, from the GitHub release API. Checked
# so a truncated or tampered download fails instead of shipping a different parser.
PANDOC_SHA_AMD64="37edb3bbcf722f921a009941bf5874e2e0c09263226c9b4a2d980788cb062ab6"
PANDOC_SHA_ARM64="56ed5566ec41d22ec9ee0704e6ac0b98ba102e92384efd5306173a22d314c79a"
PANDOC_URL_BASE="https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}"

# Where the optional static pandoc binary is cached. Only used on the host path
# when `pandoc` is not already installed. XDG-compliant, so it survives reboots.
PANDOC_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cv-build/pandoc-${PANDOC_VERSION}"

IMAGE_TAG="cv-tex:local"

do_html=false
do_pdf=false
force_docker=false
force_host=false
force_image=false
PRINT_TAG=false
for arg in "$@"; do
  case "$arg" in
    --html-only)    do_html=true ;;
    --pdf-only)     do_pdf=true ;;
    --docker)       force_docker=true ;;
    --host)         force_host=true ;;
    --force-image)  force_image=true ;;
    --print-image-tag)
      # Prints the content-hash image tag build.sh will look for, so external
      # tooling (the CI workflow) can pre-build or cache the image under exactly
      # that name. Without this, CI would tag the image differently and build.sh
      # would rebuild it from scratch, silently wasting the cache. Defined below;
      # this flag only sets the mode.
      PRINT_TAG=true ;;
    --help | -h)
      # Print this file's own header comment block, which is the usage text.
      awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"
      exit 0 ;;
    *)
      echo "unknown option: $arg" >&2
      echo "usage: cv/build.sh [--html-only|--pdf-only] [--host|--docker] [--force-image]" >&2
      exit 2 ;;
  esac
done
if [[ "$do_html" == false && "$do_pdf" == false ]]; then
  do_html=true
  do_pdf=true
fi

log()  { printf '    %s\n' "$*"; }
step() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- toolchain selection -----------------------------------------------------

# Decided once, up front, so each step below only has to say *what* to run rather
# than *where*. `host_ready` also covers the case where pandoc must be fetched
# into the cache, which the HTML step handles.  USE_HOST=false | true
USE_HOST=false

docker_ok=false
have docker && docker_ok=true

if [[ "$force_host" == true ]]; then
  # --host means the user insists on the host toolchain, so hold them to it: a
  # missing binary should fail here, clearly, rather than mid-build. Missing
  # pandoc is not fatal yet — ensure_cached_pandoc() below may supply it (it is
  # defined further down, so the check is deferred to a flag consumed after the
  # function definitions, since bash resolves function calls at execution time
  # only if they already exist).
  have pdflatex || die "--host given, but pdflatex is not on PATH"
  HAVE_PANDOC=$(have pandoc && echo true || echo false)
  USE_HOST=true
elif [[ "$force_docker" == true ]]; then
  [[ "$docker_ok" == true ]] || die "--docker given, but docker is not on PATH"
elif have pdflatex && have pandoc; then
  USE_HOST=true
elif ! [[ "$docker_ok" == true ]]; then
  cat >&2 <<EOF
  error: no usable build toolchain found.

  Neither of these is available:

    * Docker            (the default path; gives pinned, reproducible output)
    * pdflatex + pandoc (the host path; both must be on PATH)

  Install one of them:

    - Docker:  https://docs.docker.com/get-docker/
               Then re-run this script; it builds its own toolchain image.
    - TeX:     see cv/BUILD.md, "Native build (if you already have a TeX
               distribution)". You also need pandoc $PANDOC_VERSION for the
               HTML view.

  On GitHub's runners Docker is already installed, so CI always uses the first
  path.
EOF
  exit 1
fi

if [[ "$USE_HOST" == true ]]; then
  log "toolchain: host binaries ($(pdflatex --version 2>/dev/null | head -1) / $(pandoc --version 2>/dev/null | head -1))"
  log "           unpinned — use --docker for reproducible, pinned output"
fi

# --- function definitions -----------------------------------------------------


# Fetch the pinned static pandoc binary, for the host path when `pandoc` is not
# already installed. The official Linux build is statically linked ("not a
# dynamic executable"), so it runs on any glibc or musl distribution with no
# dependencies — the most portable option available, and better than delegating
# to a package manager, which would install a different version (Ubuntu 24.04's
# `apt install pandoc` gives 3.1.3, not 3.11 — a silent output change).
ensure_cached_pandoc() {
  local bin="$PANDOC_CACHE/pandoc"
  if [[ -x "$bin" && "$("$bin" --version 2>/dev/null | head -1)" == "pandoc $PANDOC_VERSION" ]]; then
    return 0
  fi

  local arch sha
  case "$(uname -m)" in
    x86_64 | amd64)  arch="amd64"; sha="$PANDOC_SHA_AMD64" ;;
    aarch64 | arm64) arch="arm64"; sha="$PANDOC_SHA_ARM64" ;;
    *) warn "no pinned pandoc build for architecture $(uname -m)"; return 1 ;;
  esac

  have curl || { warn "curl is required to download pandoc"; return 1; }

  step "pandoc: downloading $PANDOC_VERSION for linux-$arch (one time, ~33 MB)"
  local tmp
  tmp="$(mktemp -d)"

  if ! curl -fsSL -o "$tmp/p.tar.gz" \
      "$PANDOC_URL_BASE/pandoc-${PANDOC_VERSION}-linux-${arch}.tar.gz"; then
    warn "pandoc download failed"
    rm -rf "$tmp"; return 1
  fi

  if ! echo "$sha  $tmp/p.tar.gz" | sha256sum -c - >/dev/null 2>&1; then
    warn "sha256 mismatch on the downloaded pandoc — refusing to use it"
    rm -rf "$tmp"; return 1
  fi

  tar -xzf "$tmp/p.tar.gz" -C "$tmp"
  # The archive nests the binary under pandoc-<version>/bin/.
  local extracted
  extracted="$(find "$tmp" -type f -name pandoc -perm -u+x | head -1)"
  if [[ -z "$extracted" ]]; then
    warn "pandoc binary not found inside the archive"
    rm -rf "$tmp"; return 1
  fi

  mkdir -p "$PANDOC_CACHE"
  cp "$extracted" "$bin"
  chmod +x "$bin"
  rm -rf "$tmp"

  # Make it usable by the rest of the script without touching PATH ordering.
  PATH="$PANDOC_CACHE:$PATH"
  export PATH
  log "cached at $bin"
  return 0
}

# --- Docker toolchain image --------------------------------------------------

# Tag the image by a hash of its build inputs, so editing the Dockerfile or
# warmup.tex automatically invalidates it. Without this a stale image would
# silently persist after a dependency change.
image_tag() {
  local hash_input
  if have sha256sum; then
    hash_input="$(cat cv/Dockerfile cv/warmup.tex | sha256sum | cut -c1-12)"
  else
    # Non-Linux hosts may only ship shasum.
    hash_input="$(cat cv/Dockerfile cv/warmup.tex | shasum -a 256 | cut -c1-12)"
  fi
  printf 'cv-tex:%s' "$hash_input"
}

# --print-image-tag is handled here, after image_tag() exists, so CI can ask for
# the exact tag without building anything.
if [[ "$PRINT_TAG" == true ]]; then
  image_tag
  exit 0
fi

ensure_image() {
  local tag
  tag="$(image_tag)"

  if [[ "$force_image" == false ]] && docker image inspect "$tag" >/dev/null 2>&1; then
    IMAGE_TAG="$tag"
    return 0
  fi

  step "docker: building the CV toolchain image (one time, ~45 s)"
  log "tag: $tag"
  # Context is cv/, so only the Dockerfile and warmup.tex are sent.
  if docker build --tag "$tag" cv/; then
    IMAGE_TAG="$tag"
    return 0
  fi

  # A failed build may still leave a previously hand-built image usable.
  if docker image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
    warn "image build failed; falling back to existing '$IMAGE_TAG'"
    return 0
  fi
  die "could not build the toolchain image, and no fallback image exists"
}

# --- steps -------------------------------------------------------------------

# Auto-identifiers must stay DISABLED: by default pandoc gives every heading an
# id derived from its text, so \section*{Education} becomes <h2 id="education"> —
# which collides with the interactive pane's <section id="education"> on the same
# page. Duplicate ids are invalid HTML and break in-page anchors. Don't "fix" it.
#
# --shift-heading-level-by=1 moves \section*{} from <h1> to <h2>, so it does not
# collide with the page's own <h1 class="page__title">.
PANDOC_ARGS=(-f latex-auto_identifiers -t html5 --wrap=none --shift-heading-level-by=1)

run_html() {
  step "pandoc: $HTML_OUT"

  # Expected, harmless warning on every run: "[WARNING] Could not load include
  # file glyphtounicode.tex" — pandoc resolves \input{} inside the preamble even
  # though it discards the preamble, and the preamble guard is what keeps the PDF
  # building everywhere. Do not add --quiet: it hides real warnings too.
  local body
  if [[ "$USE_HOST" == true ]]; then
    have pandoc || ensure_cached_pandoc || die "pandoc is not available"
    body="$(pandoc cv/cv.tex "${PANDOC_ARGS[@]}")"
  else
    ensure_image
    # `--user` matters: without it the container writes as root, and the redirect
    # below (running as the invoking user) gets "Permission denied" — the same
    # class of bug as the root-owned PDF. HOME=/tmp is safe here because pandoc
    # writes no font cache; it must NOT be passed to the PDF step (see run_pdf).
    body="$(docker run --rm --user "$(id -u):$(id -g)" \
      -v "$PWD":/work -w /work -e HOME=/tmp "$IMAGE_TAG" \
      pandoc cv/cv.tex "${PANDOC_ARGS[@]}")"
  fi

  # A parse failure can exit 0 while emitting nothing usable, so never trust the
  # exit code alone before overwriting a committed artifact.
  if ! grep -q "<h2" <<<"$body"; then
    die "pandoc produced no <h2> headings — cv.tex did not convert properly"
  fi

  # Banner so nobody hand-edits a generated file. Prepended here (not inside
  # cv.tex) so it is applied identically on every run, keeping the CI drift check
  # stable. Anything that writes this file without the banner fails that check
  # (which is how a stray ad-hoc "pandoc > _includes/cv-live.html" was caught).
  {
    echo '<!--'
    echo '  GENERATED FILE — do not edit by hand.'
    echo '  Produced by cv/build.sh from cv/cv.tex (pandoc, LaTeX -> HTML5).'
    echo '  Edit cv/cv.tex and re-run `cv/build.sh --html-only`; CI regenerates'
    echo '  this file on every deploy and fails if it drifts from cv.tex.'
    echo '-->'
    printf '%s\n' "$body"
  } > "$HTML_OUT"

  log "ok: $(wc -l < "$HTML_OUT") lines"
}

run_pdf() {
  step "pdflatex: $PDF_OUT"

  if [[ "$USE_HOST" == true ]]; then
    # Compile out-of-tree so no .aux/.log lands in cv/ — `cv/` is excluded from
    # Jekyll, not from git, so stray intermediates would get committed.
    local tmp
    tmp="$(mktemp -d)"
    cp cv/cv.tex "$tmp/"
    if ! ( cd "$tmp" && pdflatex -interaction=nonstopmode -halt-on-error cv.tex >/dev/null ); then
      rm -rf "$tmp"
      die "pdflatex failed"
    fi
    [[ -f "$tmp/cv.pdf" ]] || { rm -rf "$tmp"; die "pdflatex produced no PDF"; }
    cp "$tmp/cv.pdf" "$PDF_OUT"
    rm -rf "$tmp"
  else
    ensure_image
    # No -e HOME here, deliberately: the image's baked fonts live under root's
    # HOME (/root/.texlive2023/...). Overriding HOME makes TeX look elsewhere and
    # regenerate every font via mktexpk, turning a 0.44 s step into ~2 s.
    docker run --rm -v "$PWD":/work -w /work \
      -e HUID="$(id -u)" -e HGID="$(id -g)" "$IMAGE_TAG" bash -c '
        set -e
        cd /tmp && cp /work/cv/cv.tex .
        pdflatex -interaction=nonstopmode -halt-on-error cv.tex >/dev/null
        cp cv.pdf /work/assets/pdf/Alden_CV.pdf
        # The container runs as root; without this the PDF is root-owned and the
        # next local build cannot overwrite it.
        chown "$HUID:$HGID" /work/assets/pdf/Alden_CV.pdf
      '
  fi

  check_text_layer
  log "ok: $PDF_OUT"
}

# The PDF text layer is read by ATS parsers and copy-paste, so it is a
# correctness property, not cosmetics. Two distinct failure modes, both caught:
#
#  1. pdfTeX with T1 encoding emits fi/fl as ligature GLYPHS with no text mapping,
#     so "file" extracts as "le" and "profile" as "prole". cv.tex prevents this
#     via \DisableLigatures. Signature: the literal substring "prole le".
#
#  2. An XeTeX-based engine (e.g. Tectonic) instead emits the Unicode ligature
#     codepoints U+FB00..U+FB04, so "file" extracts as "ﬁle". That is equally
#     broken for an ATS and is NOT caught by check 1 — it passes cleanly there,
#     which is precisely why it needs its own check. Measured: under XeTeX the
#     pdfTeX signature never appears, so a single-check script would ship this
#     silently behind a green build.
#
# All five Latin ligatures begin with the same two UTF-8 bytes (EF AC), so one
# LC_ALL=C grep -F covers the whole range without regex or locale support.
# LC_ALL=C guarantees literal byte comparison.
check_text_layer() {
  local text
  if have pdftotext; then
    text="$(pdftotext "$PDF_OUT" - 2>/dev/null || true)"
  elif [[ "$USE_HOST" == false ]] && docker image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
    # poppler is baked into the toolchain image, so the check still works on hosts
    # without poppler — including GitHub's runners, which do not ship it.
    text="$(docker run --rm -v "$PWD":/work -w /work "$IMAGE_TAG" \
      pdftotext "/work/$PDF_OUT" - 2>/dev/null || true)"
  else
    warn "pdftotext unavailable and no toolchain image — skipping the text-layer check"
    return 0
  fi

  local status=0 lig
  lig="$(printf '\xef\xac')"

  if grep -qi "prole le" <<<"$text"; then
    printf 'error: PDF text layer is broken — ligatures extracting as "le".\n' >&2
    printf '       See the text-layer section of cv/BUILD.md.\n' >&2
    status=1
  fi

  if LC_ALL=C grep -qF "$lig" <<<"$text"; then
    printf 'error: PDF text layer contains Unicode ligatures (U+FB00-U+FB04).\n' >&2
    printf '       "file" extracts as "ﬁle", which breaks ATS parsing just as badly.\n' >&2
    printf '       Usually means a non-pdfTeX engine (XeTeX/Tectonic) was used;\n' >&2
    printf '       cv.tex is written for pdfTeX.\n' >&2
    status=1
  fi

  if [[ "$status" == 0 ]]; then
    if grep -qiE '\bfile\b' <<<"$text"; then
      log "ok: text layer clean (ASCII 'file' extractable, no Unicode ligatures)"
    else
      # Not fatal: the CV may legitimately contain no word with an fi/fl pair.
      log "ok: text layer accepted (no ligature artifacts detected)"
    fi
  fi
  return "$status"
}

# --- run ---------------------------------------------------------------------

if [[ "$do_html" == true ]]; then run_html; fi
if [[ "$do_pdf"  == true ]]; then run_pdf;  fi

step "done"
