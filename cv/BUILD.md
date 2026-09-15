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
> the real master CV once it is available, then re-run `cv/build.sh`. Do not
> invent content to fill the placeholders — see §9.
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
./cv/build.sh --host        # force the host toolchain (skip Docker)
./cv/build.sh --docker      # force Docker (ignore host binaries)
./cv/build.sh --force-image # rebuild the Docker toolchain image
./cv/build.sh --help        # full usage
```

A full rebuild takes **about 0.75 s** on the Docker path once the toolchain image
exists (it used to take ~30 s — see §1.3).

### 1.1 Toolchain selection

The script picks a toolchain automatically, in this order:

| Priority | Toolchain | When | Pinned? |
|---|---|---|---|
| 1 | **Docker** (`cv/Dockerfile`) | Docker is available | ✅ Ubuntu 24.04 + pandoc 3.11 (sha256-verified) |
| 2 | **Host binaries** | no Docker, but `pdflatex` **and** `pandoc` are on `PATH` | ❌ whatever you installed |
| 3 | — | neither available | exits with an explanation |

Docker is preferred because it is pinned and reproducible. **GitHub's runners
already have Docker** and do *not* ship pandoc or TeX Live, so CI always uses
path 1. If Docker is unavailable but you have a TeX distribution, path 2 builds
the same artifacts with whatever versions you have — the HTML output is
byte-identical to the Docker path for the same pandoc version (verified).

### 1.2 The toolchain image

Everything lives in one image, described by `cv/Dockerfile`:

| Component | Purpose |
|---|---|
| `texlive-latex-base` / `-recommended` / `-fonts-recommended` | `pdflatex` + fontenc/inputenc/geometry/hyperref/microtype and the EC/LModern fonts |
| `pandoc` **3.11** | the HTML view, fetched from the GitHub release as a `.deb` and **sha256-verified** |
| `poppler-utils` | `pdftotext`, so the text-layer check (§5) runs even on hosts without poppler |
| `cv/warmup.tex` compiled once | bakes the EC/LModern PK fonts so no run regenerates them (§1.3) |

The image is tagged by a **hash of `cv/Dockerfile` + `cv/warmup.tex`**, so editing
either automatically invalidates it and forces a rebuild — a stale image can
never silently persist. `./cv/build.sh --print-image-tag` prints the tag it will
look for, which is how the CI workflow caches the image under the right name.

> ⚠️ **Do not** try to `COPY --from=pandoc/core`. That image is **Alpine/musl**,
> so its binary cannot run in this glibc image — it fails at exec with
> *no such file or directory* because `ld-musl-x86_64.so.1` is missing. Use the
> release `.deb`, as the Dockerfile does. Also note that `apt install pandoc` on
> Ubuntu 24.04 gives **3.1.3**, not 3.11, which would change the generated HTML.

### 1.3 Why the build is fast

The original recipe ran `apt-get update && apt-get install texlive-*` on **every
invocation**, which was ~26 s of a ~30 s build — repeated on every local edit and
on every CI push, since GitHub-hosted runners have no Docker layer cache.

Measured on this repository:

| Configuration | One-time | Every run |
|---|---|---|
| `apt-get install texlive` per run (original) | — | **29.7 s** |
| Prebuilt image, apt layers baked | ~45 s | 2.0 s |
| Prebuilt + fonts baked in | ~45 s | **0.75 s** (both artifacts) |

The remaining 2.0 s→0.75 s gap is the font warm-up. `cv/Dockerfile` compiles
`cv/warmup.tex` at build time so the EC/LModern PK fonts already exist; without
it, `pdflatex` regenerates ~8 fonts per run via `mktexpk`.

Two traps in that warm-up, both of which silently degrade it to a no-op:

1. **It must match `cv.tex`'s class options.** `cv.tex` is `[11pt,letterpaper]`,
   so `\normalsize` is 10.95pt (`ecrm1095`). A bare `\documentclass{article}` is
   10pt, which bakes 1000-series fonts and leaves the 1095-series to be generated
   anyway. If `cv.tex`'s base size or `fontenc` changes, update `warmup.tex`.
2. **`\usefont` takes NFSS family names, not EC file names.** Use `cmr`/`cmss`/
   `cmtt`; `ecrm`/`ecss` select nothing and bake no fonts.

The warm-up now sweeps every family at every size the class produces, plus the
TS1 encoding (which supplies `\textbullet`, used on the contact line, and is
reached through a different encoding entirely), so it does not go stale when a
new heading style is added. Verify with:

```bash
docker run --rm -v "$PWD":/work -w /work "$(./cv/build.sh --print-image-tag)" bash -c '
  cd /tmp && cp /work/cv/cv.tex .
  pdflatex -interaction=nonstopmode cv.tex 2>&1 | grep -c mktexpk'   # want: 0
```

### Why the artifacts are committed, even though they are generated

Two independent reasons, and both matter:

- **GitHub Pages' native build cannot compile LaTeX or run pandoc.** If the
  artifacts were not in git, there would be nothing to serve.
- **Jekyll's `include` tag raises `IOError` when a file is missing.** A
  `cv-live.html` that existed only inside CI would break every local
  `jekyll build`. It has to be a real file in the repository.

CI regenerates both before building, so what ships is never stale. See §3.

### The exact commands the script runs

Both steps run inside the toolchain image. The flags that matter are annotated;
see §6 for the ones that look wrong but are not.

```bash
TAG="$(./cv/build.sh --print-image-tag)"

# HTML view
#   latex-auto_identifiers disables pandoc's auto-ids (see the gotcha in §6)
#   --user + HOME=/tmp stop the container writing as root
#   HOME=/tmp is SAFE here because pandoc keeps no font cache
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/work -w /work \
  -e HOME=/tmp "$TAG" \
  pandoc cv/cv.tex -f latex-auto_identifiers -t html5 --wrap=none \
  --shift-heading-level-by=1

# PDF
#   deliberately NO -e HOME: the baked fonts live under root's HOME, and
#   overriding it makes TeX regenerate every font (see §1.3)
docker run --rm -v "$PWD":/work -w /work \
  -e HUID="$(id -u)" -e HGID="$(id -g)" "$TAG" bash -c '
    set -e
    cd /tmp && cp /work/cv/cv.tex .
    pdflatex -interaction=nonstopmode -halt-on-error cv.tex >/dev/null
    cp cv.pdf /work/assets/pdf/Alden_CV.pdf
    chown "$HUID:$HGID" /work/assets/pdf/Alden_CV.pdf
  '
```

> **`--user` on the pandoc call and `chown` on the TeX call are both
> load-bearing.** Containers write as root by default. Without these the
> generated files land root-owned, and the next build fails with
> *Permission denied* — which looks like a script bug but is a file-ownership
> problem. Both were hit and fixed during development.
>
> **The `HOME` asymmetry is also load-bearing.** The HTML step sets `HOME=/tmp`
> (needed for `--user` to have a writable home); the PDF step must **not**,
> because the image's baked fonts live under `/root/.texlive2023/`. Passing
> `HOME=/tmp` to the PDF step moves `TEXMFVAR` and defeats the font warm-up.

### Native build (if you already have a TeX distribution)

`./cv/build.sh --host` uses host binaries directly. Equivalently, by hand:

```bash
pdflatex -interaction=nonstopmode -halt-on-error \
  -output-directory=cv cv/cv.tex
cp cv/cv.pdf assets/pdf/Alden_CV.pdf
rm -f cv/cv.aux cv/cv.log cv/cv.out   # never commit these
```

This does **not** regenerate the HTML view — that always needs pandoc. You can
also get pandoc without Docker: the official Linux build is **statically linked**,
so it runs anywhere with no dependencies. Download
`pandoc-3.11-linux-amd64.tar.gz` (or `-arm64`) from the
[pandoc releases](https://github.com/jgm/pandoc/releases/tag/3.11) —
`cv/build.sh` will fetch and cache that same binary itself if you run `--host`
without pandoc installed.

## 2. Verify before pushing

```bash
./cv/build.sh                     # regenerates both artifacts (exits non-zero on failure)
bundle exec jekyll build          # 0 errors expected
bundle exec jekyll serve          # then check /cv/ in a browser
```

On `/cv/`, with all three tabs (*Interactive CV | Document (HTML) | Document (PDF)*):

- **Document (HTML)** shows the rendered `cv.tex` with the header, the
  `Placeholder document.` notice, and `Summary` / `Education` / `Skills` /
  `Research Experience` / `Leadership` / `Project Experience` as `<h2>`
  headings.
- **Interactive CV** shows the same sections built from `_data/`, including
  `Leadership`. The two panes are separate build paths (pandoc vs Liquid) that
  target the same structure — if you add a section to one, add it to the other.
  Note the heading text differs by design: `cv.tex` uses the master CV's
  phrasing ("Summary", "Technical Skills", "Experience" timeline), while the
  interactive pane uses short labels ("Skills"). The order is what must match.
- **Document (PDF)** renders the PDF inline on desktop; on mobile the browser
  refuses inline PDFs and the fallback message + download link appear instead
  (expected, not a bug).
- Arrow keys move between tabs and the focus ring follows only the focused one.
- Skip link, a single sidebar, and `page page--cv` on the article are intact.

The CV is currently **3 pages**, matching the master CV it mirrors, at a matched
density (0.5in margins, 13.1pt leading vs the master's ~13.2pt). If you edit
`cv.tex`, re-check the page count before pushing:

```bash
pdfinfo assets/pdf/Alden_CV.pdf | grep '^Pages'   # expect 3
```

The margin and `\linespread` notes in `cv.tex` record the measured values and
why they are set where they are — read those before tightening anything, because
the layout has been at the edge of overflowing before.

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
| `cv-live.html` **and** `Alden_CV.pdf` match `cv/cv.tex` | workflow | *"edited `cv.tex`, forgot to re-run the build"* |
| `_site/cv/index.html` exists, no `*.tex`/`BUILD.md` in `_site`, `cv-doc` present | workflow | a broken CV page, or LaTeX sources leaking to the web root |

### Both artifacts are byte-reproducible

The drift check compares committed bytes, which is only meaningful if the build
is deterministic. Both artifacts are, for different reasons:

| Artifact | Why it is reproducible |
|---|---|
| `_includes/cv-live.html` | Pandoc output is deterministic for a fixed version and input. |
| `assets/pdf/Alden_CV.pdf` | pdfTeX would otherwise stamp the **current time** into `CreationDate`/`ModDate` on every run. `cv/build.sh` pins `SOURCE_DATE_EPOCH` (the reproducible-builds standard), so identical input gives identical bytes. |

> **`SOURCE_DATE_EPOCH` is what makes checking the PDF possible at all.** Before
> it was set, the PDF had a new hash on every run even with no edits, so a byte
> comparison would have been permanently red and the PDF was excluded from the
> drift check — the honest conclusion at the time. The fix is preferable to
> skipping the build when nothing changed: the build always runs, so it can
> never serve something stale, and the artifact only changes when its content
> does.

**Why this matters day to day:** without it, every `./cv/build.sh` left an
uncommitted diff in `assets/pdf/Alden_CV.pdf`. That made `git status` misleading
— a real content change was indistinguishable from build noise. Now a dirty PDF
means it genuinely needs committing.

The drift check uses `git status --porcelain`, not `git diff`: `git diff`
compares the index against the worktree and is blind to untracked files, so a
regenerated-but-never-`git add`ed artifact would pass silently. Porcelain
reports `??`/` M`/` D`, covering all three failure modes.

### Checking whether the deployed PDF is current

Comparing hashes is not useful for the *live* site: GitHub serves the PDF with
`cache-control: max-age=600`, so a browser may hold a copy for ten minutes, and
the served bytes will not match your local ones for that reason alone. Compare
the extracted **text** instead, which is what actually matters and ignores any
remaining incidental differences:

```bash
curl -s https://alden-g878.github.io/assets/pdf/Alden_CV.pdf -o /tmp/live.pdf
diff <(pdftotext /tmp/live.pdf -) <(pdftotext assets/pdf/Alden_CV.pdf -)   # empty = current
```

To bypass the 10-minute cache when you need to see a fresh deploy immediately:

```bash
curl -s "https://alden-g878.github.io/assets/pdf/Alden_CV.pdf?$(date +%s)" -o /tmp/live.pdf
```

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

This is the step that is easy to skip and expensive to get wrong. There are
**two** distinct ways the text layer breaks, and they have different signatures.

**Failure 1 — pdfTeX ligature glyphs.** T1 (EC/LModern) encoding makes pdfTeX
render `fi`/`fl` as single ligature glyphs with no text equivalent, so **"file"
extracts as "le"** and "profile" as "prole". Every ATS and every copy-paste sees
the mangled text. `cv.tex` prevents this with `\usepackage{microtype}` +
`\DisableLigatures{encoding = T1, family = *}`.

```bash
pdftotext assets/pdf/Alden_CV.pdf - | grep -i "prole le"   # must print NOTHING
```

**Failure 2 — Unicode ligature codepoints.** An XeTeX-based engine (e.g.
Tectonic) does not produce failure 1 at all. Instead it emits the Unicode
ligature codepoints **U+FB00–U+FB04**, so "file" extracts as **`ﬁle`** — equally
broken for an ATS, but the `prole le` check **passes**, because that signature
never appears. This was measured, not theorised: a XeTeX build of `cv.tex` gives
0 occurrences of plain `fi` and 2 of U+FB01.

```bash
pdftotext assets/pdf/Alden_CV.pdf - | LC_ALL=C grep -qF "$(printf '\xef\xac')" \
  && echo BROKEN      # all five Latin ligatures start with bytes EF AC
```

**`cv/build.sh` now runs both checks automatically** after every PDF build, using
a local `pdftotext` if present or the one baked into the toolchain image if not
(GitHub's runners ship no poppler). A build that produces either signature fails
loudly. This matters because a non-pdfTeX engine is otherwise perfectly capable
of shipping a broken text layer behind a green build.

Measured alternatives, so this isn't re-litigated (see the comment in `cv.tex`):

| Approach | Ligatures | Accents (`Université naïve`) |
|---|---|---|
| T1 + `\pdfgentounicode` + `glyphtounicode` | ❌ still `prole le` | ✅ correct |
| Default OT1 (drop `fontenc`) | ✅ correct | ❌ `Universite ́ naı̈ve` |
| **T1 + microtype `\DisableLigatures` (pdfTeX)** | ✅ correct | ✅ correct |
| Tectonic / XeTeX | ❌ `ﬁle` (U+FB01) | ✅ correct |

`cv.tex` therefore loads microtype as `\usepackage[expansion=false]{microtype}`.
Do **not** simply drop the option: microtype's font expansion needs scalable
fonts, and on a minimal TeX install the T1 fonts are bitmap-only, so pdfTeX
aborts with *"auto expansion is only possible with scalable fonts"* and emits
no PDF at all. Enabling expansion would require adding a scalable font package
(`lmodern`/`cmsuper`, i.e. `texlive-fonts-extra`).

> **Why not Tectonic?** It is an appealing Docker-free option — one self-contained
> binary, no TeX install. It was tested and rejected: it is XeTeX-based, so
> `\DisableLigatures` hard-errors (*"only possible with pdftex version 1.30 or
> newer"*), it produces a different PDF entirely, and it breaks the text layer in
> the way failure 2 describes. Adopting it would mean a different document, not a
> faster build of this one.

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

### Do not remove `SOURCE_DATE_EPOCH` from the PDF step

It looks like a stray magic number with no purpose. It is what makes the PDF
byte-reproducible, and therefore what lets CI byte-compare the committed PDF at
all. Remove it and the artifact gets a new hash on every build, the drift check
turns permanently red, and `git status` fills with a PDF diff that is not a real
change. See §3.

The `pdftex` option in `\hypersetup` (in `cv.tex`) is a similar trap: without it,
`pdftitle`/`pdfauthor` are silently ignored and the metadata is blank again.

### The font warm-up fails silently if `warmup.tex` drifts from `cv.tex`

If `cv.tex` changes its base point size or encoding, `cv/warmup.tex` will bake
fonts that are never used and leave the real ones to be generated at run time —
a slowdown, not an error, so nothing complains. Check with the `mktexpk` count in
§1.3. Two specific traps: the class options must match (`11pt` in both), and
`\usefont` takes NFSS names (`cmr`), not EC file names (`ecrm`).

### Do not compare a Docker image tag by hand

`cv/build.sh` derives the tag from a hash of `cv/Dockerfile` + `cv/warmup.tex`.
Hardcoding a different tag anywhere (e.g. in the workflow) means the script won't
find the cached image and will rebuild it from scratch, silently wasting the
cache. Ask the script instead: `./cv/build.sh --print-image-tag`.

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
| `cv/Dockerfile` | ✅ | The pinned toolchain; its content hashes into the image tag |
| `cv/warmup.tex` | ✅ | Build-time font warm-up only — never compiled into an artifact |
| `.github/workflows/deploy.yml` | ✅ | Caches the image, runs `cv/build.sh`, builds and deploys the site |
| `assets/pdf/Alden_CV.pdf` | ✅ | Pages cannot compile it, so the bytes must ship |
| `_includes/cv-live.html` | ✅ | Generated, but Jekyll's `include` raises `IOError` if it is absent |
| `cv/cv.aux`, `cv/cv.log`, `cv/cv.out` | ❌ | LaTeX intermediates; the script compiles out-of-tree so they never appear |
| `cv/warmup.pdf`, `cv/*.pdf` (scratch) | ❌ | Build scratch; only `assets/pdf/Alden_CV.pdf` ships |
| `cv/` (the whole directory) | ❌ served | Excluded in `_config.yml` — Jekyll must not copy `.tex`/`Dockerfile` into `_site` |

## 9. Content discipline

Both artifacts are generated, never hand-edited, and this stub is not a licence
to invent history. Replace placeholders from the real master CV only — the same
rule that keeps `_projects/` and `_research/` entries at `published: false`
until real content is parsed.

When the real CV lands: replace the body of `cv.tex`, delete the
`Placeholder document.` notice and the `\ph{}` markers, run `./cv/build.sh`, and
commit `cv.tex` plus both regenerated artifacts in one commit.
