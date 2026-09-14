---
layout: archive
permalink: /tags/
title: "Posts by Tag"
author_profile: true
---

{% for tag in site.tags %}
  {% capture tag_name %}{{ tag | first }}{% endcapture %}
  <h2 id="{{ tag_name | slugify }}" class="archive__subtitle">{{ tag_name }}</h2>
  <ul>
    {% for post in site.tags[tag_name] %}
      <li><a href="{{ post.url }}">{{ post.title }}</a></li>
    {% endfor %}
  </ul>
{% endfor %}