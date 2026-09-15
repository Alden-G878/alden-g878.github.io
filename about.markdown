---
layout: single
title: "About This Site"
permalink: /about/
---

This site is my personal homepage and portfolio. The [homepage]({{ "/" |
relative_url }}) is an introduction; this page describes how the site itself is
built, for anyone curious about the machinery.

## How it is built

- **Static site generator:** [Jekyll](https://jekyllrb.com/), which turns the
  Markdown and data files in this repository into plain HTML.
- **Theme:** [Minimal Mistakes](https://mmistakes.github.io/minimal-mistakes/),
  loaded via `remote_theme` rather than a vendored copy, so it stays pinned to a
  tagged release.
- **Hosting:** GitHub Pages.

## Where the content comes from

The site is generated from a small number of sources rather than hand-written
pages, so the views cannot disagree with each other:

| Content | Source |
|---|---|
| Projects and research | `_projects/` and `_research/`, one file per entry |
| The CV, as a page | The same collection files plus `_data/` |
| The CV, as a PDF | `cv/cv.tex`, a LaTeX master, compiled in CI |
| Skills and contact details | `_data/` |

Editing `cv/cv.tex` and pushing regenerates both the PDF and the in-page
document view, so the CV has a single source of truth.

## Source code

The repository is public:
[github.com/alden-g878/alden-g878.github.io](https://github.com/alden-g878/alden-g878.github.io).

## More

- [Portfolio]({{ "/portfolio/" | relative_url }}) — every project, filterable
- [Featured Projects]({{ "/featured/" | relative_url }}) — selected work
- [CV]({{ "/cv/" | relative_url }}) — the complete record
- [Contact]({{ "/contact/" | relative_url }}) — how to reach me
