---
# Featured projects and research — the curated subset, hand-picked via
# `flagship: true` in each entry's front matter. Everything else lives on
# /portfolio/.
#
# layout: single (not portfolio) on purpose:
#   * it is a curated list, not the filterable index, so the category filter bar
#     would be redundant here;
#   * `single` renders the sidebar itself, so this page participates in the
#     site's navigation like every other page.
#
# NOTE: `single` already renders <div id="main"> and the sidebar, so this file
# must NOT add them again — see docs/layout-gotchas.md #1.
layout: single
title: "Featured Projects"
permalink: /featured/
toc: false
toc_sticky: false
---

Selected work in digital IC and RTL design — the projects and research
write-ups worth reading first. For the complete list with category filtering,
see the [Portfolio]({{ "/portfolio/" | relative_url }}).

{% comment %}
  Ongoing work leads, then newest-first. Same reasoning as the interactive CV
  timeline: `sort: "date_end" | reverse` alone would put ongoing entries LAST,
  because Liquid treats nil as greatest when sorting ascending, so reversing
  leaves the nulls at the end.
{% endcomment %}
{% assign flagship_projects = site.projects | where: "flagship", true %}
{% assign flagship_research = site.research | where: "flagship", true %}
{% assign all_flagship = flagship_projects | concat: flagship_research %}
{% assign ongoing = all_flagship | where_exp: "e", "e.date_end == nil" %}
{% assign dated = all_flagship | where_exp: "e", "e.date_end != nil" %}
{% assign dated = dated | sort: "date_end" | reverse %}
{% assign featured = ongoing | concat: dated %}

{% if featured.size > 0 %}
  <div class="featured-grid">
    {% for entry in featured %}
      {% include project-card.html entry=entry %}
    {% endfor %}
  </div>
{% else %}
  <p class="notice--info">
    Nothing is featured yet — set <code>flagship: true</code> in a project or
    research entry to surface it here.
  </p>
{% endif %}
