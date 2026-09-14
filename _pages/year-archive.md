---
layout: archive
permalink: /year-archive/
title: "Posts by Year"
author_profile: true
---

{% for post in site.posts %}
  {% capture this_year %}{{ post.date | date: "%Y" }}{% endcapture %}
  {% if last_year != this_year %}
    <h2 id="{{ this_year }}" class="archive__subtitle">{{ this_year }}</h2>
    {% assign last_year = this_year %}
  {% endif %}
  {% include archive-single.html %}
{% endfor %}