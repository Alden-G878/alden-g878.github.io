# Phase 2 implementation plan — LaTeX master + Actions pipeline

> **Companion to:** `docs/latex-cv-phases.md` (Phase 2 section). That doc states
> the *goal*; this one states the *how*, with the decisions, the measured
> evidence behind them, and what to do when it breaks.
>
> **Status (2026-09-14):** **Phase 2 is implemented and committed** — the CV-side
> work (`cv/build.sh`, `\cvwhen`, `_includes/cv-live.html`, Tab C, `.cv-doc`) and
> the infrastructure half (`.github/workflows/deploy.yml`). The only outstanding
> step is the manual repo-settings switch *Pages → Source → GitHub Actions*
> (step 8), which cannot be done from a commit. Deferred by decision: the
> collection drift guard (step 7).
> **Baseline:** Phase 1 committed and pushed (`6dde711`).
> **Verified on:** 2026-09-14, against the current `cv/cv.tex` stub.

---

## 1. Goal and non-goals

**Goal (from the handoff).** Edit only `cv/cv.tex`; push → CI compiles both the
downloadable PDF and an in-page HTML rendering of the LaTeX, so `/cv/` shows the
document without leaving the page.

**In scope**

- A GitHub Actions workflow that compiles `cv/cv.tex` → PDF and → HTML.
- Tab C, "Document (HTML)", rendering the pandoc output inline.
- Switching the Pages build source to GitHub Actions.
- Making the local regeneration path and the CI path *the same code*.

**Non-goals**

- Phase 3 (dropping the data-driven Experience section). Untouched.
- Filling in real CV content. The stub stays a stub (open question #4).
- Fixing the pre-existing `title: Your awesome title` / missing favicon cosmetics.

---

## 2. What I measured before planning

The handoff's workflow sketch assumes `pandoc cv/cv.tex -f latex -t html5` just
works. I ran it. It mostly does — but four things need to be handled, and the
handoff does not mention any of them.

| Probe | Result | Consequence for the plan |
|---|---|---|
| `pandoc cv.tex -f latex -t html5` on the current stub | **Exit 0**, clean HTML5 | The approach is viable; no format blocker. |
| The same run, stderr | `[WARNING] Could not load include file glyphtounicode.tex` | Pandoc resolves `\input{}` in the **preamble** even though it discards the preamble. Needs handling (§4.3). |
| Body-level `\ifdefined\pdfoutput ... \fi` | **Both branches leak** into the HTML | `\ifdefined` guards are meaningless to pandoc. Never rely on one in the body. |
| Preamble-level guard with `\input` | Still warns | Fixing the guard does **not** silence it. Accepted, not fixed (§4.3). |
| `\hfill` (date right-alignment) | **Silently dropped** → `\textbf{Role} \hfill 2027` becomes `<strong>Role</strong> 2027` | Dates lose right-alignment in the HTML view. Mitigation in §4.5. |
| `\textsf{}` / `\emph{}` | Survive as `<span class="sans-serif">` / `<em>` | Gives us a hook for a consistent date style. |
| `\section*{}` | Becomes `<h1 class="unnumbered">` | Same level as the page's own `<h1>` → accessibility/SEO problem. Use `--shift-heading-level-by=1` (§4.4). |
| `--shift-heading-level-by=1` | `<h2>` — correct | Adopt the flag. |
| Missing `_includes/foo.html` | Jekyll's `include` tag **raises `IOError`** (`locate_include_file` → `raise IOError, could_not_locate_message`) | A CI-only `cv-live.html` would **break every local build**. This is the single most important constraint in the plan (§4.2). |
| `Gemfile.lock` PLATFORMS | Includes `x86_64-linux`; `BUNDLED WITH 2.5.23` | `ruby/setup-ruby` + `bundler-cache: true` will resolve without a lockfile rewrite. |
| Local toolchain | `docker` ✅, but `pandoc` ❌, `pdflatex` ❌, `latexmk` ❌, `gh` ❌ | Local regeneration must go through Docker or it cannot be tested at all. |
| Lockfile vs native Pages pins | CI would use Jekyll **4.4.1**, kramdown **2.5.1**, rouge **4.5.1**; native Pages currently renders with 3.10.0 / 2.4.0 / 3.30.0 | Switching Pages to Actions changes the rendering engine. Needs an explicit side-by-side check (§6.1). |

---

## 3. Design decisions

### 3.1 One script, used by both CI and the local dev loop ✅

The handoff proposes `dante-ev/latex-action@v2` plus an `apt-get install pandoc`.
That gives CI a different toolchain from the one a developer uses locally, which
is exactly how "works in CI, broken locally" bugs start.

Instead: a single `cv/build.sh` that does the two Docker steps, invoked verbatim
by both the workflow and the developer.

```bash
# cv/build.sh  (sketch — see §5, step 1)
docker run --rm -v "$PWD":/work -e HUID="$(id -u)" -e HGID="$(id -g)" \
  <texlive image> ...        # -> assets/pdf/Alden_CV.pdf   (Phase 1 recipe, already proven)
docker run --rm -v "$PWD":/work -w /work pandoc/core:3.11 \
  cv/cv.tex -f latex -t html5 --wrap=none --shift-heading-level-by=1 \
  -o _includes/cv-live.html  # -> the HTML view
```

- **Pinned image tag `pandoc/core:3.11`** (what I tested), not `:latest` —
  otherwise a pandoc release silently rewrites the committed HTML and the
  drift check (§4.2) goes red for no reason.
- *Rejected:* `dante-ev/latex-action` + apt pandoc. Faster (no image pull per
  run) but breaks local/CI parity and pins nothing. Revisit once Phase 2 is
  stable, if build time becomes annoying.

### 3.2 `_includes/cv-live.html` is committed, and CI overwrites it ✅

Because Jekyll's `include` tag raises `IOError` on a missing file (§2), the file
**must exist in git**. So:

- Committed = real pandoc output, so local builds match production.
- CI regenerates it every run, so production is never stale.
- A CI step regenerates to a temp file and diffs against the committed copy,
  failing loudly if a developer edited `cv.tex` without re-running the build.
  That preserves handoff principle #1 (single source of truth) without a
  hand-maintained contract.

*Rejected:* generating it only in CI (breaks local builds, proven above).
*Rejected:* `.gitignore`-ing it and committing a hand-made fallback (the drift
check then compares output against a fallback, which is meaningless).

### 3.3 The PDF stays committed ✅

CI overwrites `assets/pdf/Alden_CV.pdf` in the workspace before `jekyll build`,
so the deployed artifact always has a fresh PDF. But keeping the compiled PDF in
git means a local `jekyll build` still shows the PDF tab — otherwise the
Phase 1 auto-gate would hide the tab for every developer without LaTeX.

Consequence: `cv/BUILD.md`'s manual-export contract **stays valid** as the local
path. The handoff says to delete it; I recommend softening it instead — retitle
it "local regeneration" and point at the same script CI uses. Deleting it would
remove the only written record of the `chown` and `expansion=false` gotchas.

### 3.4 Keep the auto-gate keyed on the PDF, not on "PDF or HTML"

`_layouts/cv.html` currently wraps the whole tab block in `cv_pdf_exists`. With
the PDF now committed and regenerated by CI, that condition is effectively always
true, so tabs appear. Leaving the gate as-is means: if someone deletes the PDF,
the page degrades to interactive-only rather than 404ing — the Phase 1 behaviour,
unchanged. Changing it to "PDF or HTML exists" adds a second condition for no
practical gain. **Leave the gate alone.**

### 3.5 Local dev without Docker (or without LaTeX)

`cv/build.sh` should degrade sensibly: if Docker is unavailable, it should fail
with a clear message rather than emitting a truncated PDF. It should also support
regenerating *only* the HTML (`cv/build.sh --html-only`), since that is the
common edit loop and skips the slow TeX image.

---

## 4. The parts the handoff does not cover

### 4.1 Build order in the job

LaTeX and pandoc must run **before** `jekyll build`, and the generated
`_includes/cv-live.html` must be on disk before Jekyll reads `_layouts/cv.html`.
Order:

```
checkout → ruby/setup-ruby (bundler-cache) → cv/build.sh
        → drift check → bundle exec jekyll build → upload-pages-artifact → deploy
```

### 4.2 The include must exist before Jekyll runs

Restating because it is load-bearing: `_includes/cv-live.html` is a committed
file, and `cv/build.sh` overwrites it in place. There is no branch in which
Jekyll runs without that file present.

### 4.3 The `glyphtounicode` warning: accept and document

Pandoc parses `\input{glyphtounicode}` from the preamble, cannot find the file
(the `glyphtounicode.tex` that ships with TeX Live is not present in the pandoc
image), and warns. I confirmed the guard does **not** prevent this, and that the
warning is **non-fatal (exit 0)**.

- **Do not** add `--quiet` — that hides *all* warnings, including real ones.
- **Do not** restructure the preamble to dodge it; the preamble is discarded and
  the guard is what makes the PDF build work everywhere.
- Document it in `cv/BUILD.md` as an expected, cosmetic warning, so the next
  person does not spend an hour on it.
- Safety net: assert the generated HTML is non-empty and contains at least one
  `<h2` before using it, so a genuine parse failure cannot ship a blank tab.

### 4.4 Heading levels

Pandoc turns `\section*{Education}` into `<h1 class="unnumbered">`, which would
collide with the page's own `<h1 class="page__title">`. Use
`--shift-heading-level-by=1` → `<h2>`, matching the existing interactive-tab
`<h2>Education</h2>` structure. Verified: produces `<h2 …>Summary</h2>` etc.

### 4.5 `\hfill` is dropped — pick a house style now

Dates right-aligned with `\hfill` render inline after the title in the HTML view.
Since `cv.tex` is still a stub, this is the cheapest possible moment to settle it.
Recommendation: a one-line macro in `cv.tex`

```latex
% Renders as " · <span class=sans-serif>dates</span>" in HTML and italic-ish in PDF.
\newcommand{\cvwhen}[1]{\textsf{#1}}
```

used as `\textbf{\ph{ROLE}} \hfill \cvwhen{\ph{DATES}}` — `\hfill` still aligns
the PDF, `\cvwhen` survives into the HTML as a styled span. Requires a
`.cv-doc .sans-serif` rule in `main.scss`. Alternative: accept inline dates and
change nothing. **Flag for the user — it is a taste call, not a technical one.**

---

## 5. Implementation steps

Ordered so nothing is broken between steps. Each step is independently verifiable.

### Step 1 — `cv/build.sh`

- Add the script (two Docker invocations, `--html-only` flag, `set -euo pipefail`,
  clear failure when Docker is absent).
- Reuse the Phase 1 TeX recipe verbatim, including `chown "$HUID:$HGID"`.
- Verify: run it; `assets/pdf/Alden_CV.pdf` is a valid PDF
  (`pdftotext … | grep -i "prole le"` prints nothing) and
  `_includes/cv-live.html` is the pandoc output.

### Step 2 — `cv/cv.tex` hygiene

- Add the `\cvwhen` macro (pending the user's call in §4.5).
- No other content changes.

### Step 3 — `_includes/cv-live.html`

- Commit the real pandoc output (with a short header comment explaining that it
  is generated and overwritten by CI, mirroring `assets/pdf/README.txt`).
- Verify: `bundle exec jekyll build` still succeeds.

### Step 4 — Tab C in `_layouts/cv.html`

- Add `#cv-tab-html` radio + label (after the PDF tab, per handoff ordering), and
  a `.cv-pane--html` wrapping `<div class="cv-doc">{% include cv-live.html %}</div>`.
- Wrap in the existing `cv_pdf_exists` gate (§3.4) — no change to the gate.
- Verify: three tabs, arrow keys cycle through all three.

### Step 5 — CSS

- Generalize the tab rules from two hardcoded inputs to three (active state +
  per-input focus ring — remember the focus-ring selector must be per-input, or
  all three labels light up; this was bug #6 in Phase 1).
- Add `.cv-doc` typography scoped so pandoc's bare `<h2>/<ul>/<p>` match the
  interactive tab, plus `.cv-doc .sans-serif` if §4.5 is adopted.
- Verify in-browser at desktop and 390 px, no console errors.

### Step 6 — `.github/workflows/deploy.yml`

- Standard Pages workflow: `permissions: contents: read, pages: write,
  id-token: write`; `concurrency: group: pages, cancel-in-progress: false`;
  `environment: github-pages` on the deploy job.
- Steps: checkout → `ruby/setup-ruby@v1` (ruby 3.2, `bundler-cache: true`) →
  `actions/configure-pages` → `cv/build.sh` → drift check → `jekyll build` →
  artifact sanity checks → `actions/upload-pages-artifact` →
  `actions/deploy-pages`.
- Drift check + non-empty-HTML assertion (§4.2, §4.3) **and** the built-site
  assertions described below.
- Action versions pinned to current majors rather than SHAs, matching how the
  repo tracks its other dependencies; documented in the workflow header.

**As built**, in addition to the plan:

- `actions/configure-pages` is included and `--baseurl` is driven from its
  `base_path` output, so the workflow is correct for a project site too.
- The drift check uses `git status --porcelain -- _includes/cv-live.html`. Using
  `git diff --quiet` was rejected: `diff` compares the index against the worktree
  and is blind to **untracked** files, so a regenerated-but-never-`git add`ed
  `cv-live.html` would pass silently. Porcelain reports `??`/` M`/` D`, covering
  all three failure modes with one condition. Verified against all four states.
- A build-output step asserts `_site/cv/index.html` exists, that no `*.tex`,
  `*.aux` or `BUILD.md` leaked into `_site`, and that `cv-doc` is present in the
  rendered CV page.
- Verified locally by rehearsing every CI step in order (no `act` available).

### Step 7 — Drift guard against the collections (handoff item 5)

- Sketch: for each `_projects/*.md` and `_research/*.md` with `published: true`,
  assert its `title` appears verbatim in `cv/cv.tex`; exit non-zero listing the
  misses.
- Recommend implementing it **but leaving it in warn-only mode** until the real
  CV lands — right now every entry is `published: false`, so the guard is a
  no-op and there is nothing to validate it against.

### Step 8 — Switch the Pages source

- Repo Settings → Pages → Build and deployment → **Source: GitHub Actions**.
- The currently deployed site keeps serving until the first Actions deploy, so
  ordering is forgiving; if the first run's deploy step fails, switch the source
  and re-run rather than debugging the workflow.
- Verify: the native "pages build and deployment" runs stop; `/assets/pdf/Alden_CV.pdf`
  returns 200 with the new bytes.

### Step 9 — Documentation

- `cv/BUILD.md` → retitle to local regeneration, document the script and the
  expected pandoc warning, keep the `chown` / `expansion=false` / `prole le` notes.
- `assets/pdf/README.txt` → the PDF is now a CI-regenerated artifact that is also
  committed for local dev.
- `docs/latex-cv-phases.md` → mark Phase 2 done (and correct its workflow sketch,
  which is missing every item in §4).

---

## 6. Verification plan

### 6.1 The one real risk: the rendering engine changes

Today, native Pages renders the site with Jekyll 3.10.0 / kramdown 2.4.0 /
rouge 3.30.0. After Phase 2, the same commit renders with Jekyll 4.4.1 /
kramdown 2.5.1 / rouge 4.5.1 (§2). This is not just a version bump — it is a
different build engine producing the live site, and it is the only step in the
plan that can change pages nobody touched.

**Mitigation, do this before switching the source:** build locally with the
lockfile (`bundle exec jekyll build` — same engine CI will use) and compare the
rendered HTML of `/`, `/portfolio/`, `/cv/`, `/about/`, `/contact/` against the
live site. Diff them. Any diff is a pre-existing Phase 2 side effect that should
be understood and accepted *deliberately*, not discovered in production.

#### 6.1.1 Outcome of that diff (run 2026-09-14)

Every page was compared against the live native-Pages output. The complete set
of differences, and what was done about each:

| Difference | Cause | Resolution |
|---|---|---|
| **CSS not minified** — ≈112 KB vs the live ≈74 KB, on every page | Native Pages renders through the `github-pages` gem, whose `PRODUCTION_DEFAULTS` inject `sass: {style: compressed}`. This repo pins `gem "jekyll"` instead, and `jekyll-sass-converter` defaults to `:expanded`. | **Fixed**: `sass: style: compressed` added to `_config.yml`. The CSS is now byte-identical to what the branch deploy served (modulo this session's new `.cv-tabs`/`.cv-doc` rules). |
| `Toggle menu` → `Toggle Menu`, and a new `Follow:` label in the footer | Under Jekyll 3, native Pages did **not** load the theme's own `_data/ui-text.yml`, so Liquid's `\| default:` fallbacks were used. For the two strings whose fallback differs from the theme value only in capitalisation that meant `"Toggle Menu"`; for `follow_label` the fallback is the string `"Follow"`, which is truthy, so `Follow:` never rendered. Jekyll 4 merges theme data into `site.data` (`Jekyll::Reader#read_data`), so the theme's real strings are used. | **Accepted**: the new strings are the theme-intended ones. Confirmed reproducible by building the deployed commit `6dde711` with a bogus `locale` — it produces exactly the live output. |
| `cv.tex`-derived content, the third tab, `.cv-doc` | This session's intended changes | Expected |

Nothing else differed. The prose, structure, headings and metadata of the
untouched pages are identical between the two engines, so the engine change is
accepted as safe. The `future: true` difference in the `github-pages` defaults
was checked and is inert — the only post is dated 2025-01-29, well in the past.

### 6.2 Acceptance checks

- Push a one-character change to `cv/cv.tex` → workflow green → live PDF bytes
  change → Tab C shows the updated HTML without leaving `/cv/`.
- Break the LaTeX on purpose → **build fails loudly**, no stale artifact shipped.
- `pdftotext assets/pdf/Alden_CV.pdf - | grep -i "prole le"` → nothing.
- `/cv/`: skip link, single sidebar, `page page--cv` class, three tabs,
  keyboard nav, no console errors, no placeholder leakage into `_site`.
- Local `bundle exec jekyll build` succeeds **without** Docker being run first
  (proves `cv-live.html` is committed — §4.2).
- Run time budget: < ~4 min with caches (handoff's target).

---

## 7. Risks and rollback

| Risk | Likelihood | Impact | Mitigation / rollback |
|---|---|---|---|
| Rendering engine change alters untouched pages | Medium | Medium | §6.1 diff run and accepted — two differences found, one fixed, one intended (§6.1.1). Revert = set Pages Source back to "Deploy from a branch" |
| Native Pages' CSS minification silently lost, inflating every page by ~50 KB | **High** | Medium | Fixed in advance: `sass: {style: compressed}` in `_config.yml` (§6.1.1) |
| Stale committed `cv-live.html` ships | Medium | Low | CI regenerates every run; the drift check fails the build if it disagrees with `cv.tex` |
| pandoc image tag drifts and rewrites HTML | Low | Low | Pinned to `3.11` (§3.1) |
| TeX install makes CI slow | Medium | Low | Docker layer caching; `--html-only` for the common loop |
| Committing generated HTML creates noisy diffs | High | Low | `--wrap=none` keeps the output on few long lines; diffs stay small |
| Action versions rot | Medium | Medium | Major-tag pins, refreshed deliberately (documented in the workflow header); dependabot later |

**Full rollback** is two actions: revert the workflow commit, and set Pages
Source back to "Deploy from a branch". Phase 1's committed PDF and tabs keep
working throughout — the switch is not all-or-nothing.

---

## 8. Decisions (made 2026-09-14)

1. **Date style — ADOPT the `\cvwhen{}` macro.** ✅ Implemented in `cv/cv.tex`;
   styled by `.cv-doc .sans-serif` in `main.scss`.
2. **Tab order — `Interactive CV | Document (HTML) | Document (PDF)`.** ✅
   Implemented. Rationale: the HTML view is rendered *from* the LaTeX master, so
   it is the authoritative document view; the PDF is the fidelity/print/ATS view.
3. **Collection drift guard — DEFER.** ⏸ Not implemented. Every entry is
   `published: false`, so the guard would be a no-op with nothing to validate it
   against. Revisit when real CV content lands.
4. **`cv/BUILD.md` — keep and retitle.** ✅ Rewritten as a deployment guide that
   still documents the local regeneration path (the handoff's "delete it" was
   declined, since it is the only written record of these gotchas).

---

## 9. Additional findings from implementation

Discovered while building Tab C; all fixed or documented in `cv/BUILD.md`.

| Finding | Impact | Resolution |
|---|---|---|
| Pandoc auto-ids collide | `\section*{Education}` → `<h2 id="education">`, colliding with the interactive pane's `<section id="education">` → **duplicate ids on one page** (invalid HTML, broken anchors) | `-f latex-auto_identifiers` |
| Pandoc container wrote `cv-live.html` as **root** | Banner step failed with *Permission denied* | `--user "$(id -u):$(id -g)"` on the pandoc run |
| `_includes/cv-live.html` **is byte-deterministic** | Verified across two runs (same sha256) | ✅ The CI drift check is viable — implement it in step 6 |
| `assets/pdf/Alden_CV.pdf` is **NOT** byte-deterministic | Verified across two runs (different sha256; LaTeX embeds a timestamp) | The drift check must **never** cover the PDF |
| TeX build grew the PDF 53,736 → 59,130 bytes | Expected — `\cvwhen` plus normal rebuild variance | Text-layer check still passes (`prole le` absent) |

### 9.1 Infrastructure findings

Discovered while building the workflow and running the §6.1 diff.

| Finding | Impact | Resolution |
|---|---|---|
| **Native Pages minifies CSS; a plain `gem "jekyll"` setup does not** | ≈112 KB of CSS per page instead of ≈74 KB — a real payload regression on every page of the site, caused by the Actions switch | `sass: {style: compressed}` added to `_config.yml`, making the switch output-neutral |
| **Jekyll 3 vs 4 differ in theme-data loading** | Two MM strings render differently (`Toggle Menu`→`Toggle menu`, and a `Follow:` label appears) | Accepted — Jekyll 4's behaviour is the theme-intended one; confirmed by reproducing the live output with a bogus `locale` |
| `git diff` is blind to untracked files | A drift check written with `git diff --quiet` would pass when `cv-live.html` was regenerated but never added | Use `git status --porcelain`; verified against committed/changed/deleted/untracked states |
| `github-pages` gem also forces `future: true` | Could have published future-dated posts after the switch | Checked: inert here — the only post is dated 2025-01-29 |
| Local gems are vendored at `vendor/bundle` while CI installs to the runner's gem home | Not a problem — `bundler-cache: true` resolves against the CI install, and `BUNDLE_PATH` is a committed local-only setting | No action; noted so nobody "fixes" it |

---

## 10. Open questions for the user

None outstanding. All four from the previous revision were answered (§8): adopt
`\cvwhen`, reorder the tabs, defer the drift guard, keep `BUILD.md`. The only
remaining choice is *when* to do steps 6–8 (the workflow and the Pages switch),
which is an infrastructure decision rather than a design one.

---

## 11. Checklist

### CV-side (done)
- [x] `cv/build.sh` (+ `--html-only` / `--pdf-only`), root-ownership handled
- [x] `\cvwhen` in `cv/cv.tex`, applied to all four dated entry types
- [x] `_includes/cv-live.html` committed with a generated-file banner
- [x] Tab C + `.cv-pane--html` in `_layouts/cv.html`
- [x] Tab CSS generalized to three inputs; focus ring still per-input
- [x] `.cv-doc` typography in `assets/css/main.scss`
- [x] Duplicate-id regression fixed (`latex-auto_identifiers`)
- [x] Browser-verified: 3 tabs, keyboard nav, per-tab focus ring, PDF embed
      unchanged (658px desktop / 480px mobile), no console errors
- [x] `cv/BUILD.md` rewritten as a deploy + regeneration guide

### Infrastructure (done)
- [x] `.github/workflows/deploy.yml` — `cv/build.sh` → HTML drift check
      (PDF explicitly excluded) → `jekyll build` → artifact sanity checks →
      upload → deploy
- [x] Drift check verified against all four failure modes (committed/untouched,
      changed, deleted, never-`git add`ed) using `git status --porcelain`
- [x] §6.1 side-by-side render diff run; both differences explained and resolved
      (§6.1.1) — engine change explicitly accepted
- [x] `sass: {style: compressed}` added to `_config.yml`, restoring native Pages'
      CSS output size
- [x] Workflow YAML validated; all CI steps rehearsed locally end-to-end
      (`cv/build.sh`, drift check, `jekyll build`, all three sanity checks)
- [x] `assets/pdf/README.txt` and `docs/latex-cv-phases.md` marked Phase 2 done

### Infrastructure (still outstanding)
- [ ] **Switch the Pages source** — *Settings → Pages → Source → GitHub Actions*.
      This is a repo-settings change and cannot be made from a commit; until it is
      done the native "pages build and deployment" job keeps publishing, and the
      workflow will not run.
- [ ] Collection drift guard (deferred until real content exists)
- [ ] First real push → confirm the run is green and `/assets/pdf/Alden_CV.pdf`
      returns 200 with new bytes
