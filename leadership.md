---
# Leadership and teaching roles — the fuller version of the Leadership section
# on /cv/.
#
# layout: single on purpose:
#   * it renders the sidebar itself, so the page joins the site's navigation
#     like every other page;
#   * the category filter on /portfolio/ would be meaningless for a hand-ordered
#     list of three roles.
#
# NOTE: `single` already renders <div id="main"> and the sidebar, so this file
# must NOT add them again — see docs/layout-gotchas.md #1.
layout: single
title: "Leadership"
permalink: /leadership/
toc: false
toc_sticky: false
---

Roles where the work was teaching or leading other people rather than building
something: instructing a course, supporting students in it, and running the
electronics side of a robotics team.

{% comment %}
  Rendered through the shared include, so these rows are the same markup as the
  Leadership section of the interactive /cv/ pane. Editing the data file updates
  both.

  Do not add a heading here — the page layout already renders `title` as the
  <h1>, and an <h2> immediately below it would be the only heading on the page.
{% endcomment %}
{% include leadership-list.html %}

## Elsewhere

- [**CV**]({{ "/cv/" | relative_url }}) — the complete record, including this same list
- [**Portfolio**]({{ "/portfolio/" | relative_url }}) — the projects and research these roles supported
- [**Contact**]({{ "/contact/" | relative_url }}) — how to reach me
