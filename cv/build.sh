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
# Usage:
#   cv/build.sh              rebuild both artifacts
#   cv/build.sh --html-only  rebuild only _includes/cv-live.html (fast; no TeX)
#   cv/build.sh --pdf-only   rebuild only the PDF
#
# Requires Docker. See cv/BUILD.md for the native (TeX installed locally) path.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PDF_OUT="assets/pdf/Alden_CV.pdf"
HTML_OUT="_includes/cv-live.html"

# Pinned, not :latest — otherwise a pandoc release silently rewrites the
# committed HTML and the CI drift check goes red for no reason.
PANDOC_IMAGE="pandoc/core:3.11"
# Ubuntu 24.04 gives texlive-latex-base + -recommended, which is all cv.tex
# needs (fontenc, inputenc, geometry, hyperref, microtype).
TEX_IMAGE="ubuntu:24.04"

do_html=false
do_pdf=false
case "${1:-}" in
  --html-only) do_html=true ;;
  --pdf-only)  do_pdf=true ;;
  "")          do_html=true; do_pdf=true ;;
  *) echo "unknown option: $1" >&2; echo "usage: cv/build.sh [--html-only|--pdf-only]" >&2; exit 2 ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: docker not found.

This script builds inside containers so that no TeX or pandoc installation is
needed on the host. Either install Docker, or see cv/BUILD.md for the native
`pdflatex` path if you already have a TeX distribution.
EOF
  exit 1
fi

# --- HTML view (pandoc, fast) -----------------------------------------------
if [[ "$do_html" == true ]]; then
  echo "==> pandoc: $HTML_OUT"

  # `--user` matters: without it the container writes as root, and the redirect
  # below (running as the invoking user) gets "Permission denied". Same class of
  # bug as the root-owned PDF in the TeX step.
  #
  # Warnings go to stderr and stay visible; stdout is the HTML body. Note that a
  # parse failure can still exit 0 while emitting nothing usable, hence the
  # assertion below.
  #
  # Expected, harmless warning: "[WARNING] Could not load include file
  # glyphtounicode.tex" — pandoc resolves \input{} inside the preamble even
  # though it discards the preamble. The preamble guard is what keeps the PDF
  # building everywhere, so it stays. Do not add --quiet: it hides real warnings
  # too. See cv/BUILD.md.
  # `latex-auto_identifiers` is NOT a typo: it is pandoc's LaTeX reader with
  # auto-identifiers *disabled*. By default pandoc gives each heading an id
  # derived from its text, so \section*{Education} becomes
  # <h2 id="education"> — which collides with the interactive pane's
  # <section id="education"> on the same page. Duplicate ids are invalid HTML and
  # break in-page anchors, so the ids are turned off here. Don't "fix" this flag.
  body="$(docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/work -w /work \
    -e HOME=/tmp "$PANDOC_IMAGE" \
    cv/cv.tex -f latex-auto_identifiers -t html5 --wrap=none \
    --shift-heading-level-by=1)"

  if ! grep -q "<h2" <<<"$body"; then
    echo "error: pandoc produced no <h2> headings — cv.tex did not convert properly." >&2
    exit 1
  fi

  # Banner so nobody hand-edits a generated file. Prepended here (not inside
  # cv.tex) so it is applied identically on every run, keeping any CI drift
  # check stable.
  {
    echo '<!--'
    echo '  GENERATED FILE — do not edit by hand.'
    echo '  Produced by cv/build.sh from cv/cv.tex (pandoc, LaTeX -> HTML5).'
    echo '  Edit cv/cv.tex and re-run `cv/build.sh --html-only`; CI regenerates'
    echo '  this file on every deploy and fails if it drifts from cv.tex.'
    echo '-->'
    printf '%s\n' "$body"
  } > "$HTML_OUT"

  echo "    ok: $(wc -l < "$HTML_OUT") lines"
fi

# --- PDF --------------------------------------------------------------------
if [[ "$do_pdf" == true ]]; then
  echo "==> pdflatex: $PDF_OUT"
  docker run --rm -v "$PWD":/work -e HUID="$(id -u)" -e HGID="$(id -g)" \
    "$TEX_IMAGE" bash -c '
      set -e
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        texlive-latex-base texlive-latex-recommended texlive-fonts-recommended
      cd /tmp && cp /work/cv/cv.tex .
      pdflatex -interaction=nonstopmode -halt-on-error cv.tex
      cp cv.pdf /work/assets/pdf/Alden_CV.pdf
      # The container runs as root; without this the PDF is root-owned and the
      # next local build cannot overwrite it.
      chown "$HUID:$HGID" /work/assets/pdf/Alden_CV.pdf
    '

  # The PDF text layer is read by ATS parsers and copy-paste. T1/EC encoding
  # emits fi/fl as ligature glyphs with no text equivalent, so "file" extracts
  # as "le". cv.tex prevents it via \DisableLigatures; assert it stayed that way.
  if command -v pdftotext >/dev/null 2>&1; then
    if pdftotext "$PDF_OUT" - | grep -qi "prole le"; then
      echo "error: PDF text layer is broken (ligatures extracting as 'le')." >&2
      echo "       See the text-layer section of cv/BUILD.md." >&2
      exit 1
    fi
    echo "    ok: text layer clean"
  else
    echo "    note: pdftotext not installed, skipped text-layer check"
  fi

  echo "    ok: $(stat -c %s "$PDF_OUT") bytes"
fi

echo "==> done"
