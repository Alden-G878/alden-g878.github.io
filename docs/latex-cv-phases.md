# LaTeX CV → PDF + In-Page Live View — Phased Handoff

> **Companion to:** `jekyll-site-handoff.md` (the original site spec). This doc
> supersedes its `assets/pdf/` "kept in sync manually" policy and its "no CI step
> required" build note — Phase 2 below adopts GitHub Actions deliberately.
>
> **Repo:** `Alden-G878/alden-g878.github.io` (user site → `alden-g878.github.io`)
> **Date:** 2026-09-14 · **Status:** Phases 0–1 complete; Phase 2 built and
> committed (workflow + CV tabs) — the only remaining step is the manual Pages
> source switch. Phase 3 not started.
>
> **See also:** `phase2-implementation-plan.md` — the detailed design for
> Phase 2, including the measured evidence and the corrections to the workflow
> sketch below.

---

## 0. Current state (verified, as of this handoff)

| Fact | Value |
|---|---|
| Theme | Minimal Mistakes **4.28.1** via `remote_theme:` (NOT whitelisted as `theme:` — never switch) |
| Local build | Jekyll **4.4.1** (plain `gem "jekyll"`, vendored bundle in `vendor/bundle/`) |
| Production build | GitHub Pages **native** ("pages build and deployment", Jekyll **3.10.0**, kramdown 2.4.0, rouge 3.30.0) |
| Plugins in use | `jekyll-feed`, `jekyll-remote-theme`, `jekyll-include-cache`, `jekyll-seo-tag`, `jekyll-sitemap` — **all** whitelisted on Pages |
| Collections | `projects`, `research` (`output: true`, `sort_by: date_end`); placeholders ship `published: false` |
| Data files | `_data/{education,skills,links,categories,navigation}.yml` — placeholder-gated (blocks hide while values contain "Placeholder") |
| PDF | `/assets/pdf/Alden_CV.pdf` — **currently 404s**; referenced by `_data/links.yml → resume_pdf`, CV header, and Contact page |
| Live-view gap | No on-site rendering of the actual CV document; PDF link leaves the page |
| CI | None. `.github/workflows/` does not exist. Pages builds natively on push to `main` |
| Known cosmetics | No `favicon.ico`; `_config.yml` still has `title: Your awesome title` |

### Verified layout gotchas (do not regress)

1. Custom layouts chaining to `layout: archive` (home, portfolio) must NOT re-render
   `<div id="main">` + `{% include sidebar.html %}` — the theme's `archive.html` already does both (duplicate-sidebar bug, fixed 2026-09-14).
2. Custom layouts chaining to `layout: default` (cv) render the sidebar themselves and the
   content container MUST carry class `page` — the float/width rules
   (`float: inline-end; width: calc(100% - 200px)`) live there. Bare custom classes
   (e.g. `page--cv` alone) cause content to jump full-width past the sidebar's bottom.
3. Full-width custom layouts (project, research detail) must NOT carry the `page` class
   (it reserves a phantom 200px gutter); they wrap in plain `<div id="main">` for the
   skip-link target, mirroring MM's `splash.html`.
4. Liquid pipe args cannot be parenthesized: `| concat: (site.research)` is a syntax
   error — assign to a temp var first.
5. `sed -i.bak` inside collection dirs makes Jekyll ingest the `.bak` as a document —
   delete backups immediately.

---

## Phase 1 — Tabbed CV with embedded PDF (no CI, pure win)

**Goal:** live document view on `/cv/` with zero redirects; PDF present as a real file.
**No Actions, no workflow, no toolchain changes. Native Pages keeps building.**

### Work

1. **`_layouts/cv.html`** — add a CSS-only tab switcher above the existing content:
   - Tab A **"Interactive CV"** (default, checked) = everything the layout renders today
     (education / skills / experience from `_data` + collections).
   - Tab B **"Document (PDF)"** = inline embed:
     ```html
     <object type="application/pdf" data="{{ site.data.links.resume_pdf | relative_url }}#toolbar=1"
             aria-label="CV document, PDF viewer">
       <p>Inline PDF isn't supported on this device.
          <a href="{{ site.data.links.resume_pdf | relative_url }}">Download the PDF</a>.</p>
     </object>
     ```
   - Implementation notes: hidden `radio` inputs + `:checked ~` sibling CSS
     (`#tab-interactive:checked ~ .cv-pane--interactive { display:block }` etc.),
     styled with `.chip--filter`-like tokens already in `assets/css/main.scss`.
     No JS, works with MM's greedy nav untouched.
2. **`assets/css/main.scss`** — append `.cv-tabs`, `.cv-pane`, embed height rules
   (`height: min(80vh, 1100px)`, `width: 100%`, border matching `.project-card`).
3. **PDF source of truth (interim):** compile locally from the master CV and commit
   `assets/pdf/Alden_CV.pdf`. Add `assets/pdf/BUILD.md` recording the exact export
   command so the process survives handoffs.
4. Keep `notes_missing_data` discipline: do not invent content to fill the embed.

### Accept / verify

- `/cv/` shows both tabs; Tab B renders the PDF **inline** on desktop; on mobile the
  `<object>` fallback message + download link appear (mobile Safari/Chrome refuse
  inline PDF — expected, not a bug).
- Skip-link, single sidebar, `page` class on the article (gotcha #2/#3 above) intact.
- `bundle exec jekyll build` → 0 errors; placeholders still leak nothing into `_site`.

### Cost / risk

~1–2 hours. Zero infra risk. PDF is still manually synced (accepted until Phase 2).

---

## Phase 2 — LaTeX master + Actions pipeline (the real proposal)

> **STATUS: IMPLEMENTED** (2026-09-14), except the Pages source switch in work
> item 3, which is a repo-settings action.
>
> ⚠️ **The workflow sketch below is the original proposal and is wrong in
> several ways.** Do not copy it. It was superseded by
> `.github/workflows/deploy.yml` after measurement; the differences are
> summarised under the sketch, and documented in full in
> `cv/BUILD.md` and `phase2-implementation-plan.md`.

**Goal:** edit only `cv/cv.tex`; push → CI compiles both the downloadable PDF and an
in-page HTML rendering of the LaTeX. This is the "trigger, not principle" adoption of
GitHub Actions assessed 2026-09-14 — it is justified here because **native Pages cannot
compile LaTeX or run pandoc** (not on the plugin/tool whitelist).

### Work

1. **LaTeX master** — add `cv/cv.tex`:
   - Class: plain `article` + `enumitem` (+ `hyperref`). **Avoid** `moderncv` /
     exotically-templated classes — pandoc's LaTeX→HTML conversion degrades badly on them.
   - Write "pandoc-friendly": semantic sections (`\section{}`, `\itemize`), no exotic
     floats/minipages for anything that must appear in the live view.
2. **Workflow** — `.github/workflows/deploy.yml`:
   ```yaml
   name: Build CV + deploy site
   on:
     push: { branches: [main] }
     workflow_dispatch:
   permissions:
     contents: read
     pages: write
     id-token: write
   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: dante-ev/latex-action@v2        # or texlive Docker image + BuildKit cache
           with: { root_file: cv/cv.tex, args: -pdf -outdir=_build }
         - run: |
             pandoc cv/cv.tex -f latex -t html5 --wrap=none \
               -o _includes/cv-live.html
             cp _build/cv.pdf assets/pdf/Alden_CV.pdf
         - uses: ruby/setup-ruby@v1
           with: { ruby-version: '3.2', bundler-cache: true }
         - run: bundle exec jekyll build
         - uses: actions/upload-pages-artifact@v3
     deploy:
       needs: build
       uses: actions/deploy-pages@v4
   ```
   - pandoc must be installed in the job (`apt-get install -y pandoc`) or run in a
     container that has it. Consider a single texlive+ruby container image for speed.
   - Committing generated `cv-live.html` is **not** required — generate at build time.
     If you prefer a fallback for native builds, commit it and add a CI drift-check.
3. **Switch Pages source** — repo Settings → Pages → Build and deployment →
   **Source: GitHub Actions**. (The old "pages build and deployment" dynamic runs stop.)
4. **CV layout** — add Tab C **"Document (HTML)"** including `_includes/cv-live.html`
   (pandoc output), styled to match; Tab B keeps the embed as the fidelity view.
5. **Optional drift-guard** (recommended once real content lands): CI step asserting every
   `site.projects`/`site.research` title with `published: true` appears in `cv.tex`,
   failing the build otherwise — preserves handoff principle #1 (single source of truth).
6. **Delete** `assets/pdf/BUILD.md`'s manual-export contract; PDF is now an artifact.

### Accept / verify

- Push a one-character change to `cv/cv.tex` → workflow green → live `/assets/pdf/Alden_CV.pdf`
  returns 200 with new bytes → Tab C shows updated HTML doc without leaving `/cv/`.
- `actions` run < ~4 min (with caches); Pages shows the deploy from the workflow.
- Broken LaTeX **fails the build** (loud) instead of silently shipping stale output.

### Cost / risk

- Version-skew problem (local 4.4.1 vs Pages 3.10.0) disappears — CI uses the lockfile.
- New maintenance surface: action version bumps, Ruby pin, workflow permissions.
- `gh` CLI is not installed locally; workflow debugging via
  `github.com/Alden-G878/alden-g878.github.io/actions` or the public API (both verified working).

### What the sketch above gets wrong (measured)

| Sketch says | Reality |
|---|---|
| `dante-ev/latex-action@v2` + apt pandoc | Different toolchain from local dev → "works in CI, broken locally". Replaced by **one `cv/build.sh`** that both the developer and CI run, using pinned Docker images (`pandoc/core:3.11`, `ubuntu:24.04`) |
| `pandoc cv/cv.tex -f latex -t html5` | Needs **`-t html5 --shift-heading-level-by=1`** (else `\section*{}` becomes `<h1>`, colliding with the page title) and **`-f latex-auto_identifiers`** (else headings get `id`s that duplicate the interactive pane's `<section id="…">`) |
| "Committing generated `cv-live.html` is **not** required" | **It is required.** Jekyll's `include` tag raises `IOError` when the file is missing, so a CI-only include would break every local build |
| `uses: actions/deploy-pages@v4` inside the build job | `deploy-pages` must be its **own job** with `needs:`, `environment: github-pages`, and `permissions: {pages: write, id-token: write}` |
| Missing | `actions/configure-pages`, the drift check, and the PDF/text-layer assertions |
| Missing | `sass: {style: compressed}` — without it the Actions switch ships ~112 KB of CSS per page instead of ~74 KB, because the `github-pages` gem's production default is not applied when you pin `gem "jekyll"` |
| "`enumitem`" in the LaTeX class notes | Not used, and not needed — it would pull ~1.4 GB of extra TeX dependencies for two lines of list setup |
| `-pdf` `-outdir` | Plain `pdflatex -interaction=nonstopmode -halt-on-error`; the `chown` and `expansion=false` fixes from Phase 1 are load-bearing |

---

## Phase 3 — Optional: LaTeX as the only CV source

**Goal:** remove duplication between the data-driven Experience section and the LaTeX
document. **Fully reversible one-line change.**

- Delete the Experience `<section>` (and optionally Education/Skills) from
  `_layouts/cv.html`; the page becomes: header/contact → tabs → embedded + pandoc views.
- `_data/` + collections remain the source for **Portfolio/Home cards** — do not delete
  the collections, only the CV page's data-driven sections.
- Keep the Phase 2 drift-guard inverted if needed (portfolio completeness vs `cv.tex`).
- Decision inputs: how much the recruiter-facing CV page should read as "document" vs
  "interactive index". Nothing else on the site changes.

---

## Carried-over open questions (from original handoff, still unresolved)

1. GPA on the public CV (`_data/education.yml → gpa: null` until answered).
2. Whether `context: class` projects appear on the public portfolio vs CV-only.
3. Final category vocabulary — `_data/categories.yml` currently holds the handoff's
   10 terms verbatim.
4. Master CV itself — intentionally not yet provided; all placeholder entries ship
   `published: false` and must stay that way until real content replaces them.