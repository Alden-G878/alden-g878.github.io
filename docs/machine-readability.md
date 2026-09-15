# Machine readability — ATS, crawlers, and recruiter tooling

How the site presents itself to software that does not render CSS or read
PDFs the way a human does: application tracking systems, search crawlers, link
unfurlers, and LLM-based screeners.

Written after a measured audit on 2026-09-14, using `w3m -dump`,
`pdftotext -layout`, `pandoc -f html -t plain`, and `pdfinfo` against both the
local build and the deployed site. "Verified" below means observed in output,
not assumed.

---

## 1. What the three CV surfaces are for

`/cv/` deliberately offers the same CV in three forms. They serve different
readers, and it is worth being explicit about which:

| Surface | Reader | Strength |
|---|---|---|
| PDF (`/assets/pdf/Alden_CV.pdf`) | **ATS uploads**, human recruiters | The only surface a recruiter *uploads*. Has a verified-clean text layer (§4). |
| HTML document tab | Humans, LLMs, crawlers | Rendered from the same `cv.tex`, readable as text. |
| Interactive tab | Humans on the web | Links and layout; the least structured of the three. |

The important consequence: **the PDF is the surface that must be correct for
ATS**, because that is the artifact that gets uploaded. The page matters for
search and for LLMs, but an ATS rarely parses a URL.

## 2. The one structural limitation

All three tab panes are present in the DOM simultaneously; the inactive ones are
hidden by **CSS only** (`.cv-pane { display: none }`).

Consequences, measured:

- Rendered text totals **363 words**, versus roughly **130** for the single
  visible pane.
- A raw-HTML consumer sees the same sections **twice** — `Education`, `Skills`
  and `Experience` from the interactive pane, then `Summary`, `Education`,
  `Skills`, `Experience`, `Research`, `Projects` from the pandoc pane.
- It also sees the "Placeholder document" notice, the `cv.tex` build note, and
  the header contacts a second time.

Who is affected:

| Reader | Affected? | Why |
|---|---|---|
| Google-class search | **Largely no** | `display:none` content is discounted, not indexed as visible text. |
| LLM / AI screeners | **Yes** | They fetch raw HTML and ignore stylesheets. |
| Scrapers, naive parsers | **Yes** | Same reason. |
| ATS (PDF upload) | **No** | They read the PDF, not the page. |

This is a known trade-off of the CSS-tabs approach (no JavaScript, works without
it). Fixing it properly means rendering only one pane server-side, which would
lose the no-JS tab switching. **Left as-is deliberately** — it is an LLM-facing
cosmetic duplication, not an ATS defect, and it should be re-evaluated once real
CV content exists and the duplication is measurable against real text.

## 3. What was fixed

### 3.1 Site identity (`_config.yml`)

| Was | Now | Why it mattered |
|---|---|---|
| `title: Your awesome title` | `Alden — Computer Engineering` | Every `<title>`, `og:site_name` and the feed used the stock placeholder. |
| Jekyll's stock description | a factual one-liner | Used for `<meta name="description">` and the feed summary. |
| `email: your-email@example.com` | unset | A fake address, worse than none. |
| `twitter_username: jekyllrb` | unset | Not Alden's handle — it would have claimed a stranger's account in share links. |
| *(no `name:`)* | `name: "Alden"` | **This is what broke the JSON-LD** — see below. |

The JSON-LD bug is worth understanding, because it failed silently. MM's
`_includes/schema.html` emits:

```liquid
"name": {{ site.social.name | default: site.name | jsonify }},
```

Neither `site.social.name` nor `site.name` existed, so the homepage published
`"name": null` — valid JSON, valid schema.org, and completely useless. Setting
`name:` fixed it.

### 3.2 PDF metadata (`cv/cv.tex`)

`pdfinfo` reported **Title, Author, Subject and Keywords all empty**. An ATS
reading the document information dictionary had nothing to index by name.

Now set via `\hypersetup{pdftex, pdftitle=..., pdfauthor=..., pdfsubject=...,
pdfkeywords=...}`. Verified:

```
Title:    Alden - Curriculum Vitae
Author:   Alden
Subject:  Curriculum Vitae
Keywords: RTL design, verification, computer architecture, ...
```

Values are plain ASCII on purpose — PDFDocEncoding handles an em dash poorly in
metadata strings. The text layer was re-verified clean afterwards.

### 3.3 Structured data (`_includes/head/custom.html`)

`default.html` includes `head/custom.html`, which is the theme's supported
extension point for head markup, so no theme file is forked.

An enriched `Person` block was added alongside the theme's own. Measured before
and after:

| | Before | After |
|---|---|---|
| JSON-LD `name` | `null` | `"Alden"` |
| JSON-LD properties | 2 (`name`, `url`) | 5 (+ `alumniOf`, `sameAs`, `knowsAbout`) |
| Microdata properties on `/cv/` | 4 | 3 (+ the JSON-LD block) |

Design notes, both deliberate:

- **Null values are omitted, not published.** `"jobTitle": null` is worse than
  an absent key: a consumer cannot distinguish "unknown" from "explicitly
  nothing". Values come from `_data/links.yml`, so filling that file in
  automatically enriches the block with no edit here.
- **`knowsAbout` is expanded to readable labels.** `_data/categories.yml` holds
  filter slugs (`rtl-design`) because the portfolio's `data-category` attributes
  and collection front matter must match them exactly. Publishing raw slugs would
  tell a parser the person knows about "rtl-design", so hyphens are turned into
  spaces, mirroring what the portfolio chips display. It remains a coarse
  signal — those slugs are a topical vocabulary, not the CV's specific skills.

### 3.4 Favicon

None was declared, so `/favicon.ico` returned **404**. Added an "A" monogram
(`assets/images/favicon.svg` plus 16/32/180 PNGs and a root `favicon.ico`), and
all six declared icon paths were verified to exist in the build. A missing
favicon affects browser tabs, bookmarks, and link unfurls — small, but visible
to a recruiter.

## 4. The PDF text layer (unchanged, but load-bearing)

The single most important correctness property for ATS. Two distinct failure
modes are checked automatically by `cv/build.sh` after every PDF build:

1. pdfTeX + T1 ligature glyphs — `file` extracts as `le`, `profile` as `prole`.
2. XeTeX-style Unicode ligature codepoints (U+FB00–U+FB04) — `file` extracts as
   `ﬁle`.

The second is not caught by the first; both are asserted. See `cv/BUILD.md` §5.

Layout-preserving extraction (`pdftotext -layout`) reads correctly. One caveat
worth knowing: right-aligned dates land in a separate text column, so a naive
parser may not associate a date with the role on the same visual line.

## 5. Remaining gaps

Ordered by impact. Items 1–3 are the ones that actually block machine extraction.

1. **No contact method is machine-readable.** `_data/links.yml` has `email`,
   `linkedin` and `location` all `null`, so the site emits **no** `mailto:` or
   `tel:` link anywhere (verified: 0 occurrences site-wide). A parser cannot
   extract a way to make contact. Fill the three fields in that one file and the
   CV header, Contact page, and JSON-LD all pick them up.
2. **No surname anywhere.** Every title reads just "Alden", and the CV `<h1>` is
   "Alden — Curriculum Vitae". A recruiter searching or an ATS matching a full
   name will not find this site. Set `name:` in `_config.yml` and `pdfauthor=` in
   `cv.tex`.
3. **`/cv/` microdata is thin** — the theme's `Person` scope carries only `name`,
   `url` and two `sameAs`. Enriching the theme's block would mean forking a theme
   include; the added JSON-LD block above is the supported alternative and is the
   one search engines prefer.
4. **`og:type` is `website` on all 8 pages**, including `/cv/`. MM decides this
   from `page.date`, so a page without a date cannot be `article` — there is no
   front-matter override. Left alone: cosmetic for unfurling, irrelevant to ATS.
5. **Portfolio and contact pages are near-empty.** All collection entries are
   `published: false`, and `/contact/` says "address coming soon" — so the
   portfolio contributes nothing to index yet.
6. **Placeholder tokens are ingested verbatim.** 23 distinct `[BRACKETED]`
   placeholders currently extract from `/cv/` and the PDF. A parser sees
   `[INSTITUTION]` as literal text, which looks worse than an empty page. This
   resolves when the master CV lands; `cv.tex` is deliberately not filled with
   invented content.
7. **Tab duplication** — see §2.

## 6. Re-running the audit

```bash
bundle exec jekyll build
JEKYLL_ENV=production bundle exec jekyll build

# what a text-mode crawler sees
w3m -dump -cols 100 _site/cv/index.html

# what an LLM crawler sees (ignores CSS, so shows all three panes)
pandoc -f html -t plain _site/cv/index.html

# what an ATS reads from the uploaded artifact
pdftotext -layout assets/pdf/Alden_CV.pdf -
pdfinfo assets/pdf/Alden_CV.pdf

# structured data must be valid JSON, not merely present
python3 - <<'PY'
import re, json
s = open("_site/cv/index.html", encoding="utf-8").read()
for m in re.finditer(r'<script type="application/ld\+json">(.*?)</script>', s, re.S):
    print(json.dumps(json.loads(m.group(1)), indent=2))
PY

# machine-readable contact info: expect at least one after gaps 1 is fixed
grep -rhoE 'mailto:[^"]*|tel:[^"]*' _site/ | sort -u
```
