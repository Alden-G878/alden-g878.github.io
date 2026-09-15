---
# Homepage. Deliberately NOT the old flagship-grid role — this page is an
# introduction, and the featured work has its own page at /featured/.
# _layouts/home.html renders only what is below.
layout: home
# No `title:` on purpose. MM appends `site.title` after it, so setting one here
# produced "Alden - Alden — Computer Engineering". Unset gives just the site
# title, which is what an about-style homepage wants.
title:
permalink: /
---

I am an Electrical and Computer Engineering student at Carnegie Mellon
University, working across the stack from RTL down to silicon. My interests sit
in digital circuit and RTL design: computer architecture, hardware acceleration,
verification, and the physical design work needed to turn any of it into a real
chip.

I am currently seeking **spring/summer 2027 internships** in digital circuit and
RTL design and research. I am a combined BS/MS student with Ph.D. intent, and
open to industry roles between degrees.

{% comment %}
  Ordering: ongoing first, then newest-first. `sort: "date_end" | reverse` alone
  leaves ongoing entries LAST, because Liquid treats nil as greatest when sorting
  ascending, so reversing puts the nulls at the end. /featured/ has the fuller
  note.
{% endcomment %}
{% assign flagship_projects = site.projects | where: "flagship", true %}
{% assign flagship_research = site.research | where: "flagship", true %}
{% assign all_flagship = flagship_projects | concat: flagship_research %}
{% assign ongoing = all_flagship | where_exp: "e", "e.date_end == nil" %}
{% assign dated = all_flagship | where_exp: "e", "e.date_end != nil" %}
{% assign dated = dated | sort: "date_end" | reverse %}
{% assign featured = ongoing | concat: dated %}

## What I work on

- **RTL design and ASIC flow** — SystemVerilog, from design through simulation,
  synthesis, place and route, to GDSII. I have taped out a design on Sky130 via
  TinyTapeout, and worked on a commercial process in TSMC 28nm.
- **Computer architecture** — processor pipelines, branch prediction, cache
  management and bus snooping, and microcoded control.
- **Hardware acceleration** — systolic arrays, neural-network inference, and
  accelerators for KNN and decision-tree training.
- **Verification and timing** — SystemVerilog testbenches, Cocotb, constrained
  random testing, formal reachability proofs, and static timing analysis.
- **Embedded systems** — hard real-time firmware, RTOS and bootloader
  development, and custom PCB bring-up.

## Where to look next

- [**Portfolio**]({{ "/portfolio/" | relative_url }}) — every project, filterable by category
- [**Leadership**]({{ "/leadership/" | relative_url }}) — teaching and club roles
- [**CV**]({{ "/cv/" | relative_url }}) — the complete record, as an interactive page or a PDF
- [**Contact**]({{ "/contact/" | relative_url }}) — how to reach me

{% comment %}
  Three cards, not all of them: the homepage should stay about the person.

  Kramdown gotcha: raw HTML placed directly after a Markdown list is absorbed
  INTO the last <li>. The paragraph of prose above separates them, so the grid
  below starts outside the list. Keep that separation if you edit this.
{% endcomment %}
{% if featured.size > 0 %}

### Selected work

<div class="home-teaser">
  {% for entry in featured limit: 3 %}
    {% include project-card.html entry=entry %}
  {% endfor %}
</div>

<p class="home-teaser__more">
  <a href="{{ '/featured/' | relative_url }}">All {{ all_flagship.size }} featured projects &rarr;</a>
</p>

{% endif %}
