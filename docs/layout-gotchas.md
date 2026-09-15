# Layout and Liquid gotchas — do not regress

Hard-won, non-obvious constraints in this site's layouts and templates. Every one
of these caused a real bug that was found and fixed; each is easy to reintroduce
because the broken version looks reasonable.

They are verified against the source, and where a claim is about the theme's own
CSS the exact rule is quoted so it can be re-checked after a theme upgrade.

Scope: the site's own `_layouts/`, `_includes/`, and `_data/`. Nothing here
concerns the CV build — see `cv/BUILD.md` for that.

---

## 1. A layout chaining to `layout: archive` must not render `#main` or the sidebar

`archive.html` already renders **both** the page title and the sidebar. A layout
that inherits from it and also emits them produces **two sidebars** and a
duplicated `#main` (which also breaks the skip-link target, since two elements
would share that id).

**Affected:** `_layouts/home.html`, `_layouts/portfolio.html` — both chain to
`layout: archive` and contribute content only.

```yaml
# _layouts/home.html — correct
---
layout: archive
---
{% comment %}
  NOTE: the archive layout (inherited above) already renders the sidebar and
  page title — do NOT add another <div id="main"> / sidebar here, or they
  will be duplicated.
{% endcomment %}
```

This is also noted inline in both files, because that is where someone would
actually make the mistake.

## 2. A layout chaining to `layout: default` must render `#main` + sidebar itself, and its content container must carry the class `page`

`default.html` provides neither the sidebar nor an `#main` target. So a layout
inheriting from it has to supply both. The part that is easy to miss is the
**content container's class**: the sidebar gutter is not applied by the sidebar,
it is applied by a `page` (or `archive`) class on the **content**.

The theme's actual rules, from the built `assets/css/main.css` — note that
`.page` and `.archive` carry the *same* gutter rule:

```css
@media (min-width: 64em) {
  .page, .archive {
    float: inline-end;
    width: calc(100% - 200px);
    padding-inline-end: 200px;
  }
}
```

A bare custom class such as `page--cv` matches nothing, so the content is
initially laid out *beside* the sidebar and then — once it grows taller than the
sidebar — **jumps to full width**, overlapping the sidebar's column. It looks
fine on a short page and breaks on a long one, which is what makes it hard to
spot.

**Affected:** `_layouts/cv.html`, which uses `<article class="page page--cv">` —
`page` is required, `page--cv` is only an extra styling hook.

Layouts that inherit from `archive` get this for free, because the theme's
`archive.html` puts `archive` on the container itself:

| Page | Container rendered |
|---|---|
| `/` (home) | `<div class="archive">` |
| `/portfolio/` | `<div class="archive">` |
| `/cv/` | `<article class="page page--cv">` |

## 3. A full-width layout must NOT carry the `page` (or `archive`) class

The flip side of #2. A layout with **no sidebar** that carries `page` or
`archive` inherits `width: calc(100% - 200px)` and reserves a phantom 200px
gutter beside nothing, so content is needlessly narrowed and offset.

Such layouts wrap their content in a plain `<div id="main" role="main">` purely
to provide the skip-link target, mirroring the theme's own `splash.html`.

**Affected:** `_layouts/project.html` and `_layouts/research.html`. Both chain to
`layout: default`, render no sidebar, and use a content class that is *not* a
theme gutter class. Verified from a real build with the placeholder entries
temporarily published:

| Page | Sidebars | Container class |
|---|---|---|
| `/projects/<slug>/` | 0 | `project-detail` |
| `/research/<slug>/` | 0 | `research-detail` |

> **Not affected, despite appearances:** `_layouts/portfolio.html` is *not*
> full-width. It has a sidebar and inherits `archive` from its parent layout,
> which supplies the gutter correctly — it simply contains no `page` class of its
> own. An earlier version of this note claimed otherwise; that was wrong.

> Rule of thumb: `page`/`archive` appears on a content container **only** when a
> sidebar is present. `#main` is needed **whenever** there is a skip link, which
> is always.

## 4. A layout chaining to `archive` must emit `{{ content }}` or the page body vanishes

Because layouts chain, `{{ content }}` inside the theme's `archive.html` refers
to **the chained layout's rendered output** — not to the Markdown body. So a
layout that inherits from `archive` and never calls `{{ content }}` silently
discards its page's body text. No error, no warning, and the file still exists;
the content simply never appears.

This actually happened: `portfolio.md`'s intro paragraph rendered **0 times** in
the built page. `_layouts/portfolio.html` now calls `{{ content }}` before
rendering the grid.

```liquid
{{ content }}   {# the page body from portfolio.md #}

{% comment %} then the grid / empty state {% endcomment %}
```

**Affected:** `_layouts/portfolio.html` — it has body text to render.
`_layouts/home.html` is structurally identical but `index.markdown` has no body,
so nothing is lost there. `cv.html` and the detail layouts do call
`{{ content }}`.

Check for it by comparing a page's body text against the built output:

```bash
bundle exec jekyll build
# take a distinctive phrase from the .md file's body and confirm it survived
grep -c 'All hardware/RTL projects' _site/portfolio/index.html   # expect: 1
```

## 5. A Liquid pipe argument cannot be parenthesized

`{% assign x = a | concat: (b) %}` is a **syntax error** in Liquid. The classic
form `| concat: b` works and is what these templates use, but any expression
needing grouping must be assigned to a temporary variable first.

```liquid
{% comment %} correct — assigns first, then pipes {% endcomment %}
{% assign flagship_projects = site.projects | where: "flagship", true %}
{% assign flagship_research = site.research | where: "flagship", true %}
{% assign flagship = flagship_projects | concat: flagship_research
               | sort: "date_end" | reverse %}
```

Note the line continuation: a pipe may start the next line, which is how these
expressions are kept readable.

**Affected:** `_layouts/home.html`, `_layouts/portfolio.html`,
`_includes/cv-interactive.html` — all three use the temp-variable pattern.

## 6. A `.bak` file inside a collection directory becomes a document

`sed -i.bak` writes its backup **into the same directory**, and Jekyll reads
every file in `_projects/` or `_research/` as a collection document — regardless
of extension or of the file having no front matter. The backup therefore becomes
a real entry and is published.

This was verified, not assumed. Adding `_projects/probe.md.bak` and building:

```
projects docs: ["_projects/probe.md.bak"]
  -> published at /projects/probe-md/
```

Note the URL: Jekyll slugified `probe.md.bak` to `probe-md`, so the artifact does
not even look like the template it came from, which makes it easy to miss when
reviewing output.

Delete backups immediately, or write them outside the collection:

```bash
# avoid: leaves _projects/<name>.md.bak behind
sed -i.bak 's/foo/bar/' _projects/example.md

# prefer: edit in place, no backup file
sed -i 's/foo/bar/' _projects/example.md
```

There is currently **no `.gitignore` rule and no `_config.yml` exclude** guarding
against this, so it is a discipline requirement, not an enforced one.
`published: false` on the entries does not help here either — a fresh `.bak` copy
carries whatever front matter it was copied from, and even without front matter
Jekyll still ingests it.

---

## Checking these claims after a theme upgrade

Two of these depend on the theme's CSS rather than on this repo, so they are
worth re-verifying whenever `remote_theme`'s version changes (currently
`mmistakes/minimal-mistakes@4.28.1`):

```bash
bundle exec jekyll build
# the sidebar/`page` rule quoted in #2 and #3
grep -oE '\.(page|archive)\{[^}]*\}' _site/assets/css/main.css
```

Then, for the structure of each layout — the naive grep is misleading here,
because `home.html` and `portfolio.html` *mention* `id="main"` and `sidebar`
inside `{% comment %}` blocks explaining why they must not be added. Strip the
comments before counting, or you will get a false positive on exactly the files
that are correct:

```bash
python3 - <<'PY'
import re, glob
for f in sorted(glob.glob("_layouts/*.html")):
    src = open(f).read()
    chain = re.search(r'^layout:\s*(\S+)', src, re.M)
    chain = chain.group(1) if chain else "?"
    # remove Liquid comments so explanatory prose is not counted as code
    code = re.sub(r'\{%-?\s*comment\s*-?%\}.*?\{%-?\s*endcomment\s*-?%\}', '', src, flags=re.S)
    main = len(re.findall(r'id="main"', code))
    side = len(re.findall(r'include sidebar', code))
    print(f"  {f:28} layout={chain:9} #main={main} sidebar={side}")
PY
```

Expected: the two `layout: archive` layouts show `#main=0 sidebar=0` (the theme
supplies both), `cv.html` shows `#main=1 sidebar=1` (it must), and the two
detail layouts show `#main=1 sidebar=0` (a target for the skip link, no sidebar).

Also worth an occasional check that no `page`/`archive` class has crept onto a
full-width layout (#3), and that no `.bak` files exist:

```bash
# only cv.html should declare `page`; the archive-chaining layouts get it from
# the theme's archive.html, and the detail layouts must have neither
grep -rn 'class="[^"]*\b\(page\|archive\)\b' _layouts/

find _projects _research -name '*.bak'        # expect: nothing
```
