# Building the CV PDF

`cv/cv.tex` is the master CV source. `assets/pdf/Alden_CV.pdf` is its compiled
output and is **committed** so the site works on native GitHub Pages, which
cannot run LaTeX.

> ⚠️ **Current status:** `cv.tex` is a *stub*. Every `[BRACKETED]` token is a
> placeholder. Regenerate the PDF after replacing the stub with the real master
> CV.

## Why this is manual (for now)

Phase 1 of `docs/latex-cv-phases.md` deliberately adds **no CI**. GitHub Pages'
native build cannot compile LaTeX or run pandoc, so the PDF is exported locally
and committed. Phase 2 replaces this contract with a GitHub Actions pipeline
that generates the PDF as a build artifact — when it lands, this file goes away.

## Prerequisites

A TeX distribution providing `pdflatex` with `geometry`, `microtype`, and
`hyperref`. `texlive-latex-base` + `texlive-latex-recommended` covers all three
(the file deliberately avoids `enumitem`, which lives in the ~1.4 GB
`texlive-latex-extra`, so it builds on a minimal install).

No TeX installed locally? Use a disposable container instead — it needs no
package installation on the host. Run from the repository root:

```bash
docker run --rm -v "$PWD":/work -e HUID="$(id -u)" -e HGID="$(id -g)" \
  ubuntu:24.04 bash -c '
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      texlive-latex-base texlive-latex-recommended texlive-fonts-recommended
    cd /tmp && cp /work/cv/cv.tex .
    pdflatex -interaction=nonstopmode -halt-on-error cv.tex
    cp cv.pdf /work/assets/pdf/Alden_CV.pdf
    chown "$HUID:$HGID" /work/assets/pdf/Alden_CV.pdf   # container runs as root
  '
```

> The `chown` matters: the container writes as root, and a root-owned PDF cannot
> be overwritten by the next local build without manual `chown`/`rm`.

## Native build (if `pdflatex` is on your `PATH`)

Run from the repository root:

```bash
pdflatex -interaction=nonstopmode -halt-on-error \
  -output-directory=cv cv/cv.tex
cp cv/cv.pdf assets/pdf/Alden_CV.pdf
```

Then clean the intermediates so they are never committed:

```bash
rm -f cv/cv.aux cv/cv.log cv/cv.out
```

## ⚠️ Verify the text layer — the PDF is read by machines, not just people

This is the step that is easy to skip and expensive to get wrong. T1 (EC/
LModern) encoding makes pdfTeX render `fi`/`fl` as single ligature glyphs with
no text equivalent, so **"file" extracts as "le"** and "profile" as "prole".
Every ATS and every copy-paste sees the mangled text. `cv.tex` prevents this
with `\usepackage{microtype}` + `\DisableLigatures{encoding = T1, family = *}`.

```bash
pdftotext assets/pdf/Alden_CV.pdf - | grep -i "prole le"   # must print NOTHING
```

Measured alternatives, so this isn't re-litigated (see the comment in `cv.tex`):

| Approach | Ligatures | Accents (`Université naïve`) |
|---|---|---|
| T1 + `\pdfgentounicode` + `glyphtounicode` | ❌ still `prole le` | ✅ correct |
| Default OT1 (drop `fontenc`) | ✅ correct | ❌ `Universite ́ naı̈ve` |
| **T1 + microtype `\DisableLigatures`** | ✅ correct | ✅ correct |

`cv.tex` therefore loads microtype as `\usepackage[expansion=false]{microtype}`.
Do **not** simply drop the option: microtype's font expansion needs scalable
fonts, and on a minimal TeX install the T1 fonts are bitmap-only, so pdfTeX
aborts with *"auto expansion is only possible with scalable fonts"* and emits
no PDF at all. Enabling expansion would require adding a scalable font package
(`lmodern`/`cmsuper`, i.e. `texlive-fonts-extra`).

Also confirm the file is a real PDF and not a stub:

```bash
file assets/pdf/Alden_CV.pdf   # expect "PDF document"
ls -l assets/pdf/Alden_CV.pdf  # a LaTeX failure aborts the build, so a tiny file means trouble
```

## Verify before committing

```bash
bundle exec jekyll build
```

Open `/cv/`, switch to the **Document (PDF)** tab, and confirm the PDF renders
inline on desktop and shows the download-fallback link on mobile. If the embed
collapses to a sliver, see the `fitvidsignore` note below.

## Committed vs. ignored

| Path | Committed? | Why |
|---|---|---|
| `cv/cv.tex` | ✅ | The source of truth for the document |
| `assets/pdf/Alden_CV.pdf` | ✅ | Pages cannot compile it, so the bytes must ship |
| `cv/cv.aux`, `cv/cv.log`, `cv/cv.out` | ❌ | LaTeX intermediates; delete them |
| `cv/` (the whole directory) | ❌ served | Excluded in `_config.yml` — Jekyll must not copy `.tex` into `_site` |

## If the in-page PDF viewer collapses to a thin line

The `<object>` in `_layouts/cv.html` carries a `fitvidsignore` class. Minimal
Mistakes runs the FitVids jQuery plugin over every `<object>` on the page at
load, which wraps it in `.fluid-width-video-wrapper` (`height: 0;
overflow: hidden`) and forces the object itself to `position: absolute;
height: 100%`. The embed then renders as a ~2px sliver with no error message.
`fitvidsignore` is FitVids' default opt-out list, so the class keeps the PDF
out of it — keep the class on the element.

## Keeping `cv.tex` "pandoc-friendly"

Phase 2 renders this same file to HTML with
`pandoc cv/cv.tex -f latex -t html5`. Two rules keep that path working:

1. **Stay on a plain class** (`article`). `moderncv` and heavily templated
   classes convert badly — the HTML view would come out mangled.
2. **Use semantic structure** (`\section*{}`, `\itemize`). Anything that only
   exists as a PDF float or `minipage` will not survive the conversion, so keep
   content that must appear on the page in ordinary body text.

## Content discipline

The PDF is generated, never hand-edited, and this stub is not a licence to
invent history. Replace placeholders from the real master CV only (handoff
open question #4) — the same rule that keeps `_projects/` and `_research/`
entries at `published: false` until real content is parsed.
