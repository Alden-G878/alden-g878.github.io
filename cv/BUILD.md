# CV artifacts and deploying the site

Two separate concerns live in this file:

1. **`cv/cv.tex` → the CV artifacts.** The LaTeX master generates two committed
   files: `assets/pdf/Alden_CV.pdf` (the printable / ATS document, shown on the
   *Document (PDF)* tab) and `_includes/cv-live.html` (the in-page
   *Document (HTML)* tab). One script does both — `cv/build.sh`.
2. **Getting the site live.** Push to `main`; GitHub Pages publishes it —
   normally through `.github/workflows/deploy.yml`, which runs that same script.

Sections: **1** regenerate the artifacts · **2** verify before pushing ·
**3** what CI checks · **4** deploy · **5** verify the PDF text layer ·
**6** gotchas · **7** pandoc-friendly rules · **8** what is committed ·
**9** content discipline.

> ⚠️ **Current status:** `cv/cv.tex` is a *stub*. Every `[BRACKETED]` token is a
> placeholder, and the PDF says so in its own body text. Replace the stub with
> the real master CV (handoff open question #4), then re-run `cv/build.sh`.
>
> **Infrastructure status:** `.github/workflows/deploy.yml` is committed. The one
> remaining manual step is switching *Settings → Pages → Source* to **GitHub
> Actions** — see §4.

---

## 1. Regenerate the CV artifacts

`cv/cv.tex` is the single source of truth for the CV document. Both artifacts are
**generated** — never hand-edit `assets/pdf/Alden_CV.pdf` or
`_includes/cv-live.html`; edit `cv.tex` and re-run the script.

```bash
./cv/build.sh               # both artifacts
./cv/build.sh --html-only   # just _includes/cv-live.html (seconds; no TeX)
./cv/build.sh --pdf-only    # just assets/pdf/Alden_CV.pdf
```

The script needs Docker, so no TeX or pandoc installation is required on the
host. It runs two pinned containers:

| Artifact | Tool | Pinned image |
|---|---|---|
| `assets/pdf/Alden_CV.pdf` | `pdflatex` | `ubuntu:24.04` + `texlive-latex-base`/`-recommended`/`-fonts-recommended` |
| `_includes/cv-live.html` | `pandoc` | `pandoc/core:3.11` |

Nothing is written as `:latest`, so a toolchain release cannot silently rewrite
the committed artifacts.

### Why the artifacts are committed, even though they are generated

Two independent reasons, and both matter:

- **GitHub Pages' native build cannot compile LaTeX or run pandoc.** If the
  artifacts were not in git, there would be nothing to serve.
- **Jekyll's `include` tag raises `IOError` when a file is missing.** A
  `cv-live.html` that existed only inside CI would break every local
  `jekyll build`. It has to be a real file in the repository.

CI regenerates both before building, so what ships is never stale. See §3.

### The exact commands the script runs

```bash
# HTML view — note `latex-auto_identifiers`, which is pandoc's LaTeX reader with
# auto-ids DISABLED (see the gotcha in §6).
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/work -w /work \
  -e HOME=/tmp pandoc/core:3.11 \
  cv/cv.tex -f latex-auto_identifiers -t html5 --wrap=none \
  --shift-heading-level-by=1

# PDF
docker run --rm -v "$PWD":/work -e HUID="$(id -u)" -e HGID="$(id -g)" \
  ubuntu:24.04 bash -c '
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      texlive-latex-base texlive-latex-recommended texlive-fonts-recommended
    cd /tmp && cp /work/cv/cv.tex .
    pdflatex -interaction=nonstopmode -halt-on-error cv.tex
    cp cv.pdf /work/assets/pdf/Alden_CV.pdf
    chown "$HUID:$HGID" /work/assets/pdf/Alden_CV.pdf
  '
```

> **`--user` on the pandoc call and `chown` on the TeX call are both
> load-bearing.** Containers write as root by default. Without these the
> generated files land root-owned, and the next build fails with
> *Permission denied* — which looks like a script bug but is a file-ownership
> problem. Both were hit and fixed during development.

### Native build (if you already have a TeX distribution)

```bash
pdflatex -interaction=nonstopmode -halt-on-error \
  -output-directory=cv cv/cv.tex
cp cv/cv.pdf assets/pdf/Alden_CV.pdf
rm -f cv/cv.aux cv/cv.log cv/cv.out   # never commit these
```

This does **not** regenerate the HTML view — that always needs pandoc.

## 2. Verify before pushing

```bash
./cv/build.sh                     # regenerates both artifacts (exits non-zero on failure)
bundle exec jekyll build          # 0 errors expected
bundle exec jekyll serve          # then check /cv/ in a browser
```

On `/cv/`, with all three tabs (*Interactive CV | Document (HTML) | Document (PDF)*):

- **Document (HTML)** shows the rendered `cv.tex` with the header, the
  `Placeholder document.` notice, and `Summary` / `Education` / `Skills` /
  `Experience` / `Research` / `Projects` as `<h2>` headings.
- **Document (PDF)** renders the PDF inline on desktop; on mobile the browser
  refuses inline PDFs and the fallback message + download link appear instead
  (expected, not a bug).
- Arrow keys move between tabs and the focus ring follows only the focused one.
- Skip link, a single sidebar, and `page page--cv` on the article are intact.

If the PDF embed collapses to a thin line, see the FitVids note in §6.

`cv/build.sh` already fails the build on the two regressions that are easy to
miss: an empty/HTML-less `cv-live.html`, and a PDF whose text layer has broken
ligatures (see the text-layer section below).

## 3. What CI checks

The workflow runs four gates after the artifact rebuild. Three come from
`cv/build.sh` itself; one is a step in the workflow.

| Check | Where | Catches |
|---|---|---|
| `cv-live.html` contains `<h2` | `build.sh` | a pandoc parse failure that still exits 0 and would ship a blank tab |
| PDF text layer has no `prole le` | `build.sh` | broken ligatures (§5) |
| `cv-live.html` matches `cv/cv.tex` | workflow | *"edited `cv.tex`, forgot to re-run the build"* |
| `_site/cv/index.html` exists, no `*.tex`/`BUILD.md` in `_site`, `cv-doc` present | workflow | a broken CV page, or LaTeX sources leaking to the web root |

The drift check is only possible because the output is reproducible — measured
during Phase 2, because it decides what CI may assert:

| Artifact | Re-running the build | Can CI diff it? |
|---|---|---|
| `_includes/cv-live.html` | Byte-identical (verified twice: same sha256) | ✅ Yes — a drift check is reliable |
| `assets/pdf/Alden_CV.pdf` | **Different bytes every run** (LaTeX embeds a timestamp) | ❌ No — a byte diff would fail forever |

The PDF is therefore validated by *content* instead: it parses, it is not tiny,
and its text layer is clean. Never add a byte comparison for it.

The drift check uses `git status --porcelain`, not `git diff`: `git diff`
compares the index against the worktree and is blind to untracked files, so a
regenerated-but-never-`git add`ed `cv-live.html` would pass silently. Porcelain
reports `??`/` M`/` D`, covering all three failure modes.

## 4. Deploy the site

GitHub Pages serves this repository at **https://alden-g878.github.io**.

### Normal deploy — push to `main`

```bash
git add -A
git commit -m "…"
git push origin main
```

`.github/workflows/deploy.yml` then runs on its own:

```
checkout → ruby/setup-ruby (bundler-cache) → configure-pages → cv/build.sh
        → drift check → jekyll build → sanity checks → upload → deploy
```

The order is load-bearing: `cv/build.sh` must finish before `jekyll build`,
because `_layouts/cv.html` includes `_includes/cv-live.html` and Jekyll reads
it at render time. To rebuild without changing the site, use
*Actions → Deploy site to Pages → Run workflow* (`workflow_dispatch`).

> **The workflow only runs once Pages is pointed at Actions.** Until
> *Settings → Pages → Source* is switched from **Deploy from a branch** to
> **GitHub Actions**, the native *"pages build and deployment"* job keeps
> publishing instead, and it has no LaTeX and no pandoc — so a `cv.tex` change
> would ship only if you committed the regenerated artifacts yourself.

### The one manual step

*Settings → Pages → Build and deployment → Source* → **GitHub Actions**.

The currently deployed site keeps serving until the first Actions deploy
completes, so the ordering is forgiving. If that first run fails at the deploy
step, switch the source back and re-run rather than debugging the workflow.

**Rollback** is two steps, and neither loses the Phase 1 work: revert the
workflow commit, and set *Settings → Pages → Source* back to **Deploy from a
branch**.

### Switching the source changes the rendering engine

This is the one part of the switch that can alter pages nobody touched, so it
was diffed before the source was flipped. Native Pages renders with
**Jekyll 3.10.0 / kramdown 2.4.0 / rouge 3.30.0**; the workflow renders with the
lockfile, **Jekyll 4.4.1 / kramdown 2.5.1 / rouge 4.5.1**.

Measured result across `/`, `/portfolio/`, `/about/`, `/contact/` and `/cv/`:

| Difference | Cause | Status |
|---|---|---|
| **CSS was not minified** (≈112 KB vs ≈74 KB) | the `github-pages` gem injects `sass: {style: compressed}` in production; the plain `jekyll` gem defaults to `:expanded` | **fixed** — `sass: style: compressed` is now set in `_config.yml`, so the deployed CSS is byte-identical to what the branch deploy served |
| `Toggle menu` → `Toggle Menu`, and a `Follow:` label appearing | native Pages under Jekyll 3 did not load the theme's own `_data/ui-text.yml`, so MM's capitalised `| default:` fallbacks were used for the two strings that lack a lowercase default. Jekyll 4 merges theme data, so the theme's real strings are used. | accepted — the new strings are the correct/theme-intended ones |
| `cv.tex`-derived content, tabs, `.cv-doc` | this session's intended changes | expected |

Nothing else differed — the prose, structure and metadata of the untouched
pages are identical between the two engines.

To re-run the comparison after a future theme or engine change:

```bash
JEKYLL_ENV=production bundle exec jekyll build --baseurl ""
# then diff _site/<page>/index.html against the live page
```

### Preview locally before pushing

```bash
bundle exec jekyll serve
```

Then open <http://localhost:4000/cv/>. (Plain `jekyll build` writes `_site/`
without serving it; `serve` also watches for changes.)

> **Serving locally uses `JEKYLL_ENV=development`, so Sass is expanded** and the
> CSS you see will be larger than production. That is expected — the style is
> forced to `compressed` in production, mirroring native Pages (§6).

### Verify a deploy

```bash
curl -sI https://alden-g878.github.io/cv/ | head -1              # expect: 200
curl -sI https://alden-g878.github.io/assets/pdf/Alden_CV.pdf | head -1
```

For the PDF, confirm the bytes actually changed rather than trusting the status
code:

```bash
curl -s https://alden-g878.github.io/assets/pdf/Alden_CV.pdf | sha256sum | cut -c1-16
sha256sum assets/pdf/Alden_CV.pdf | cut -c1-16   # must match
```

## 5. ⚠️ Verify the text layer — the PDF is read by machines, not just people

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

## 6. Gotchas — each of these cost time once already

### The pandoc warning about `glyphtounicode.tex` is expected

Every pandoc run prints:

```
[WARNING] Could not load include file glyphtounicode.tex at cv/cv.tex line 73
```

This is harmless and the build still exits 0. Pandoc discards the preamble but
still *resolves* `\input{}` inside it, and the `glyphtounicode.tex` that ships
with TeX Live is not in the pandoc image. The preamble block that does this is
what keeps the PDF's text layer correct, so it stays. **Do not add `--quiet`** to
silence it — that would hide real warnings too.

### `latex-auto_identifiers` is not a typo

It is pandoc's LaTeX reader with auto-identifiers **disabled**. By default pandoc
gives every heading an `id` derived from its text, so `\section*{Education}`
becomes `<h2 id="education">` — which collides with the interactive pane's
`<section id="education">` on the same page. Duplicate ids are invalid HTML and
break in-page anchors. Don't "clean up" that flag.

### `\hfill` disappears in the HTML view

Pandoc drops it, so `\textbf{Role} \hfill 2027` becomes
`<strong>Role</strong> 2027` — the date runs straight into the title. That is why
`cv.tex` defines `\cvwhen{}`:

```latex
\textbf{\ph{ROLE}} \hfill \cvwhen{\ph{DATES}}
```

`\hfill` still right-aligns the PDF; `\cvwhen` (a `\textsf`, which pandoc *does*
preserve) becomes `<span class="sans-serif">`, styled by `.cv-doc .sans-serif` in
`assets/css/main.scss`. Use it for any trailing metadata.

### Containers write as root

Both `--user "$(id -u):$(id -g)"` (pandoc) and `chown "$HUID:$HGID"` (TeX) in
`build.sh` exist for this. Miss either and the generated file is root-owned, the
next build fails with *Permission denied*, and it reads like a script bug.

### `sass: style: compressed` in `_config.yml` looks redundant — it is not

Native Pages renders through the `github-pages` gem, which injects
`sass: {style: compressed}` in production
(`GitHubPages::Configuration::PRODUCTION_DEFAULTS`). This repo does **not** use
that gem — it pins `gem "jekyll"` — and `jekyll-sass-converter` defaults to
`:expanded`. Without the setting, switching the Pages source would have shipped
≈112 KB of CSS instead of ≈74 KB on every page. The setting makes the Actions
deploy output-neutral. Don't remove it without re-measuring (§4).

### The in-page PDF viewer collapsing to a thin line

The `<object>` in `_layouts/cv.html` carries a `fitvidsignore` class. Minimal
Mistakes runs the FitVids jQuery plugin over every `<object>` on the page at
load, which wraps it in `.fluid-width-video-wrapper` (`height: 0;
overflow: hidden`) and forces the object itself to `position: absolute;
height: 100%`. The embed then renders as a ~2px sliver with no error message.
`fitvidsignore` is FitVids' default opt-out list, so the class keeps the PDF
out of it — keep the class on the element.

## 7. Keeping `cv.tex` "pandoc-friendly"

The same file produces both artifacts, so anything that survives only in PDF
breaks the HTML tab. Three rules:

1. **Stay on a plain class** (`article`). `moderncv` and heavily templated
   classes convert badly — the HTML view would come out mangled.
2. **Use semantic structure** (`\section*{}`, `\itemize`). Anything that exists
   only as a float or `minipage` will not survive the conversion, so keep content
   that must appear on the page in ordinary body text.
3. **Route trailing metadata through `\cvwhen{}`** — never bare after `\hfill`,
   which pandoc silently drops (see §6).

Packages are deliberately limited to `texlive-latex-base` +
`texlive-latex-recommended` (`fontenc`, `inputenc`, `geometry`, `hyperref`,
`microtype`). Spacing uses plain lengths and a `\tightlist` macro rather than
`enumitem`/`parskip`, which would pull in ~1.4 GB of extra dependencies for two
lines of setup — and `enumitem` is not needed for correct rendering.

## 8. Committed vs. ignored

| Path | Committed? | Why |
|---|---|---|
| `cv/cv.tex` | ✅ | The source of truth for the CV document |
| `cv/build.sh` | ✅ | One build path, shared by humans and CI |
| `.github/workflows/deploy.yml` | ✅ | Runs `cv/build.sh`, then builds and deploys the site |
| `assets/pdf/Alden_CV.pdf` | ✅ | Pages cannot compile it, so the bytes must ship |
| `_includes/cv-live.html` | ✅ | Generated, but Jekyll's `include` raises `IOError` if it is absent |
| `cv/cv.aux`, `cv/cv.log`, `cv/cv.out` | ❌ | LaTeX intermediates; delete them |
| `cv/*.pdf` (build scratch) | ❌ | Only `assets/pdf/Alden_CV.pdf` ships |
| `cv/` (the whole directory) | ❌ served | Excluded in `_config.yml` — Jekyll must not copy `.tex` into `_site` |

## 9. Content discipline

Both artifacts are generated, never hand-edited, and this stub is not a licence
to invent history. Replace placeholders from the real master CV only (handoff
open question #4) — the same rule that keeps `_projects/` and `_research/`
entries at `published: false` until real content is parsed.

When the real CV lands: replace the body of `cv.tex`, delete the
`Placeholder document.` notice and the `\ph{}` markers, run `./cv/build.sh`, and
commit `cv.tex` plus both regenerated artifacts in one commit.
