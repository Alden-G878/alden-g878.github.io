# `cv/build.sh` performance + portability plan

> **Status:** research, measurements AND implementation complete (2026-09-14).
> All six decisions in §7 were adopted. Result: **29.7 s → 0.75 s** per build,
> byte-identical artifacts, Docker optional rather than required.
> **Date:** 2026-09-14
> **Scope:** only the build *mechanism*. The build *result* must not change —
> every option below was or can be validated for byte-identical output.
>
> **Baseline:** `cv/build.sh` at the commit that added Phase 2 infrastructure.

---

## 1. Goal

Make `cv/build.sh` faster, and reduce its dependence on Docker, **without**
changing its output and **without** narrowing the set of machines that can run
it. Speed must not be bought with fragility.

Non-goals: changing `cv.tex`, the artifacts, the tabs, or the workflow's
structure.

---

## 2. What I measured (all numbers real, this machine)

### 2.1 The current cost

| Step | Time | Notes |
|---|---|---|
| `--html-only` (pandoc) | **0.27 s** | Already fast; Docker overhead is most of it |
| `--pdf-only` (TeX) | **29.7 s** | and again 31.3 s on a second run |

### 2.2 Where the 30 s actually goes

| Component | Time |
|---|---|
| Bare container start | 0.22 s |
| `apt-get update` | 3.90 s |
| `apt-get update` + install texlive | **29.96 s** |
| `pdflatex` itself | ~1.5–2 s |

**The bottleneck is not Docker and not LaTeX — it is `apt-get install texlive`
running from scratch on every single invocation.** The script has no caching
whatsoever, so the 26 s install is paid every time, locally and in CI.

Two consequences worth stating plainly:

- `cv/build.sh` is ~30 s on every run, but ~1.9 s of that is useful work.
- In CI this is **worse than the local number suggests**, because the runner has
  no Docker layer cache: it re-downloads the `ubuntu:24.04` base and re-installs
  texlive on every push.

### 2.3 What a prebuilt image costs instead

| Configuration | Once | Every run after | Image size |
|---|---|---|---|
| Current (`ubuntu:24.04` + apt each run) | 0 s | **29.7 s** | — |
| Prebuilt TeX image, apt layer cached | 37.5 s | **2.0 s** | 556 MB |
| Prebuilt + **fonts baked in** | 46.9 s | **0.44 s** | 761 MB |
| Prebuilt + fonts + pandoc + poppler (one image) | 46.9 s | **0.51 s** → both artifacts | 761 MB |

`pdflatex` on the warm path costs **0.44 s**, and 0 `mktexpk` lines appear,
confirming the baked EC/LModern fonts are reused rather than regenerated.

### 2.4 Docker-free `pandoc`

pandoc publishes a **statically linked** Linux binary (`not a dynamic
executable` — no libc, no musl, nothing):

| | pandoc/core:3.11 (Docker) | static binary |
|---|---|---|
| Time | 0.269 s | **0.041 s** |
| Output sha256 | `c65dfc96b216df4b4fbebccc` | `c65dfc96b216df4b4fbebccc` |
| Bytes | 157 MB | 157 MB |

Byte-identical. This is a free ~0.23 s and one less container.

⚠️ **A trap I hit:** `pandoc/core:3.11` is **Alpine/musl**. You *cannot* copy its
binary into an Ubuntu image — `exec /usr/local/bin/pandoc: no such file or
directory`, because `ld-musl-x86_64.so.1` is absent. Any single-image approach
must use pandoc's **github.com release `.deb`** (glibc), not `COPY --from=pandoc/core`.

### 2.5 Is the runner's toolchain preinstalled?

Checked `actions/runner-images` for `ubuntu-24.04`:

- **pandoc: absent.** **TeX Live: absent.** `poppler`/`pdftotext`: absent.
- **Docker 28.0.4, Buildah 1.33.7, Podman 4.9.3: present.**

So in CI, Docker is *not* an extra dependency — it is already on the runner and
is the cheapest way to get a pinned toolchain. That materially changes the
Docker-free calculus for CI (see §4.3).

---

## 3. The finding that matters most: Tectonic is not a drop-in

[Tectonic](https://tectonic-typesetting.github.io/) is the obvious "Docker-free
LaTeX" candidate — one 36 MB self-contained binary, no TeX install, fetches
packages on demand. I tested it properly rather than assuming.

**Result: it compiles, but it silently degrades the PDF's text layer — and the
existing guard would not catch it.**

| | pdfTeX (current) | Tectonic (XeTeX) |
|---|---|---|
| Engine | pdfTeX | **XeTeX** |
| `\DisableLigatures` | works | **hard error** — `only possible with pdftex version 1.30 or newer` |
| Plain `fi` in extracted text | 2 occurrences | **0** |
| Unicode ligature codepoints | none | **2 × U+FB01 LATIN SMALL LIGATURE FI** |
| Extracted "file" | `file` | **`ﬁle`** |
| Accents (`Université naïve`) | correct | correct |
| Our `prole le` check | passes | **passes** ⚠️ |

Three separate problems:

1. **It errors out** on `\DisableLigatures` as written. It only survives with the
   call guarded by `\ifdefined\pdftexversion` (a pdfTeX-only macro) — note that
   `\ifdefined\pdfoutput` does **not** discriminate, because XeTeX defines that
   too. I initially got this wrong and it cost a cycle.
2. **It changes the output.** Not byte-identical (26,874 vs 59,130 bytes) — a
   different engine, different font path, different PDF.
3. **It breaks the ATS text layer in a way we currently do not detect.** The
   document is full of `fi` words (`file`, `profile`, `qualified`). Under Tectonic
   they extract as `ﬁle` — which is what an ATS sees. And critically, the
   `prole le` guard **passes**, because XeTeX does not produce the *pdfTeX* failure
   signature. Adopting Tectonic would quietly ship a broken text layer behind a
   green check.

That third point is the real argument against it: it would require a *new*
guard, and it would mean the `T1 + \DisableLigatures` design that `cv/BUILD.md`
documents in detail no longer applies.

---

## 4. Options

### 4.1 Prebuilt toolchain image — **recommended**

Keep Docker; stop installing TeX on every run. Add `cv/Dockerfile` and change
`build.sh` to build-if-missing, then `docker run` the cached image.

- **Gain:** 29.7 s → **0.44 s** for the PDF (≈67×); both artifacts in 0.51 s.
- **Compatibility:** *wider*, not narrower. Same `ubuntu:24.04` base, all
  multi-arch (`amd64/arm64/ppc64le/s390x/riscv64`). Docker is already present on
  the CI runner. Anyone with Docker — Windows/macOS/Linux, incl. Podman's
  docker-compatible CLI — gets identical behaviour.
- **Output:** byte-identical. Verified: same PDF size (59,130) and same HTML
  hash as today's path.
- **Costs:** a one-time ~47 s build and 761 MB of image on disk; the script must
  detect a stale image (e.g. tag by content hash).

### 4.2 Use pandoc's static binary for the HTML step

Drop the pandoc container; download (or cache) the static binary.

- **Gain:** 0.27 s → 0.04 s. Byte-identical output, verified.
- **Compatibility:** good, but **not unconditional** — needs a download, a cache
  location, and per-arch selection (`amd64`/`arm64` only).
- **Verdict:** worth doing, but modest. Best folded into 4.1 as a secondary path
  rather than replacing Docker for the PDF.

### 4.3 Native toolchain, no Docker at all

If Docker is unavailable, use `pdflatex`/`pandoc` from the host `PATH`.

- **Gain:** zero container overhead; on a machine that already has TeX, ~0.44 s.
- **Compatibility:** this is the *native* path `cv/BUILD.md` already documents —
  but it works only where TeX is installed, and cannot be pinned. On CI it is a
  **regression**: the runner has no TeX and no pandoc, so this path would mean a
  26 s apt install anyway, i.e. exactly today's cost with more moving parts.
- **Verdict:** keep as the documented fallback, not as the default.

### 4.4 Tectonic — **not recommended**

See §3. It changes the output and breaks the text layer behind a passing guard.
The only way it is safe is with a new, stricter text assertion **and** accepting
a different PDF. The portability appeal is real (one binary, no TeX, works offline
after first run) but it trades a correctness guarantee for convenience.

### 4.5 CI-specific: bake the image into the runner

In the workflow, `docker/build-push-action` with `cache-from/to: type=gha` builds
the image once and restores it from the Actions cache on later runs.

- **Gain:** removes the repeated texlive install *and* the repeated `ubuntu:24.04`
  pull. Likely the single biggest CI win.
- **Compatibility:** GitHub-specific, so it belongs in the workflow, not in
  `build.sh` — keeping the script host-agnostic.

---

## 5. Suggested shape (as implemented)

Each piece is independently revertable:

1. **`cv/Dockerfile`** + **`cv/warmup.tex`** (new) — `ubuntu:24.04`, the same
   texlive set as before plus `poppler-utils`, pandoc 3.11 from its sha256-verified
   glibc `.deb`, and a throwaway compile that bakes the EC/LModern fonts.
2. **`cv/build.sh`** — builds the image if absent, tagging it by a content hash of
   the Dockerfile and warm-up so edits invalidate it. Keeps `--html-only`/
   `--pdf-only`, keeps the `--user`//`chown` handling, keeps both self-checks.
   Adds toolchain auto-selection, `--host`/`--docker`/`--force-image`/
   `--print-image-tag`, and the strengthened text-layer assertion.
3. **`--host` path** — uses host `pdflatex`/`pandoc` when Docker is unavailable,
   fetching and sha256-verifying the static pandoc binary into the XDG cache if
   pandoc is missing. Degrades with an explanation instead of refusing to run.
4. **Workflow** — `setup-buildx-action` + `build-push-action` with `type=gha`
   layer caching, tagged with whatever `--print-image-tag` reports.
5. **Docs** — `cv/BUILD.md` §1 rewritten (toolchain table, image contents, why it
   is fast, the two warm-up traps), §5 rewritten (both ligature failure modes),
   §6 gained two gotchas, §8 gained the new committed files.

---

## 6. Verification plan

Every claim above rests on output being unchanged, so the same checks apply to
whatever is implemented:

- `sha256sum` the HTML against `_includes/cv-live.html` → must match exactly.
- PDF: same page count, same `prole le` result, and confirm the **text layer still
  contains plain ASCII `fi`** (0 Unicode ligature codepoints). This is the check
  that would have caught Tectonic.
- `bundle exec jekyll build` → 0 errors; `/cv/` renders all three tabs.
- CI rehearsal: run the workflow's steps in order locally.

**Recommended addition regardless of option:** extend the text-layer assertion to
reject Unicode ligature codepoints (U+FB00–U+FB04). Today's `prole le` check only
catches the pdfTeX failure; it would not catch an XeTeX-style one. That is a
five-line change that makes the guard engine-independent.

---

## 7. Decisions — ALL SIX ADOPTED and implemented (2026-09-14)

1. **Prebuilt toolchain image — ADOPTED.** `cv/Dockerfile` + `cv/warmup.tex`.
   The image is tagged by a content hash of both files, so edits invalidate it
   automatically. Result: **29.7 s → 0.75 s** for both artifacts.
2. **Static pandoc binary — ADOPTED**, but as the *host* path rather than a
   replacement for Docker. `cv/build.sh` fetches and sha256-verifies
   `pandoc-3.11-linux-<arch>.tar.gz` into `~/.cache/cv-build/` when `--host` is
   used without pandoc installed. The Docker image gets the same pandoc version
   from its glibc `.deb`.
3. **`--host` fallback — ADOPTED.** Toolchain selection is now: Docker →
   host binaries → a clear error explaining what to install. `--host`/`--docker`
   force either path. HTML output is byte-identical across both (verified).
4. **GHA layer caching — ADOPTED.** `docker/setup-buildx-action` +
   `docker/build-push-action` with `cache-from/to: type=gha`, `load: true`,
   `provenance: false` (the cache exporter's attestations cannot be loaded into
   the local daemon) and `ignore-error: true`. The workflow asks `build.sh` for
   the tag via `--print-image-tag`, so the cached image is named exactly what the
   script looks for.
5. **Tectonic — REJECTED**, per §3. Confirmed again during implementation: a
   XeTeX build of `cv.tex` yields 0 plain `fi` and 2 × U+FB01, and the old
   `prole le` check passes on it.
6. **Unicode-ligature check — ADOPTED.** `check_text_layer()` now rejects both
   signatures: the pdfTeX `prole le` string *and* the two-byte UTF-8 prefix
   `EF AC` shared by U+FB00–U+FB04. Verified to accept the real pdfTeX PDF and
   reject a XeTeX one.

### 7.1 What the implementation added beyond the plan

| Finding | Detail |
|---|---|
| The font warm-up is easy to get silently wrong | First attempt used a bare `\documentclass{article}` (10pt) while `cv.tex` is `11pt`, so it baked `ecrm1000` and left `ecrm1095` to be generated. Second attempt used EC file names (`ecrm`) instead of NFSS names (`cmr`), selecting nothing. Third missed TS1, which supplies `\textbullet` on the contact line via a *different encoding*. Now a systematic sweep: 110 fonts baked, **0** generated at run time. |
| `HOME=/tmp` defeats the font warm-up | Baked fonts live under `/root/.texlive2023/`. Passing `HOME` on the PDF step moves `TEXMFVAR` and regenerates everything. The HTML step keeps `HOME=/tmp` (needed for `--user`, harmless for pandoc); the PDF step must not set it. |
| Image-tag drift would silently waste the CI cache | `build.sh` hashes the Dockerfile; the workflow must use the same tag, hence `--print-image-tag`. |
| `apt install pandoc` on Ubuntu 24.04 gives **3.1.3**, not 3.11 | A package-manager install would have silently changed the committed HTML and turned the drift check red. Pinning the version and verifying sha256 avoids this. |

### 7.2 Verification performed

- Byte-parity: `_includes/cv-live.html` sha256 identical across the Docker path,
  the host path, and the committed artifact (`67a74e65c3580b48...`).
- Zero run-time font generation (`mktexpk` count = 0).
- Text-layer check proven to accept pdfTeX output and reject a XeTeX build.
- All three toolchain paths exercised, including the "no toolchain at all" and
  "`--docker` with no docker" error paths.
- Full CI step rehearsal: image resolve → buildx build → `build.sh` → drift check
  → `jekyll build` → sanity checks; `cv/Dockerfile` and `warmup.tex` verified not
  to leak into `_site`.
- Warm run measured 3× for stability: 0.757 / 0.765 / 0.745 s.

   independently of the above.
