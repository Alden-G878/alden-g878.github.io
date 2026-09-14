---
layout: archive
permalink: /categories/
title: "Posts by Category"
author_profile: true
---

{% for category in site.categories %}
  {% capture category_name %}{{ category | first }}{% endcapture %}
  <h2 id="{{ category_name | slugify }}" class="archive__subtitle">{{ category_name }}</h2>
  <ul>
    {% for post in site.categories[category_name] %}
      <li><a href="{{ post.url }}">{{ post.title }}</a></li>
    {% endfor %}
  </ul>
{% endfor %}