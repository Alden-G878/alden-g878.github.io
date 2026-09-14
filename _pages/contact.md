---
# Contact page — links pulled from _data/links.yml at render time.
layout: single
title: "Contact"
permalink: /contact/
author_profile: true
sidebar:
  nav: "main"
---

The best way to reach me is {% if site.data.links.email %}[email](mailto:{{ site.data.links.email }}){% else %}email (address coming soon){% endif %}.

{% if site.data.links.github %}- GitHub: [{{ site.data.links.github | remove: 'https://' }}]({{ site.data.links.github }}){% endif %}
{% if site.data.links.linkedin %}- LinkedIn: [profile]({{ site.data.links.linkedin }}){% endif %}
{% if site.data.links.location %}- Location: {{ site.data.links.location }}{% endif %}
{% if site.data.links.resume_pdf %}- CV as PDF: [download]({{ site.data.links.resume_pdf | relative_url }}){% endif %}

*Links populate automatically as `_data/links.yml` is filled in.*