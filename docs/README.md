---
layout: default
title: README -- learn about mutable systems
---
# InterPlanetary Mutable System (IPMS)

[![bring](//img.shields.io/badge/project-blockRingTM-darkgreen.svg?style=flat-square&logo=CodeSandbox&logoColor=gold)](//blockRing™.gq")
[![standard-readme compliant](//img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](//github.com/RichardLitt/standard-readme)
[![jsd](//data.jsdelivr.com/v1/package/gh/iglake/cssjs/badge?style=flat-square&color=black)](//www.jsdelivr.com/package/gh/iglake/cssjs)

<a href="//www.jsdelivr.com/package/gh/miche47/cgism">
<img style="opacity:0.6;" src="//data.jsdelivr.com/v1/package/gh/michel47/cgism/badge?style=flat-square&color=yellow"></a>

[![Netlify Status](https://api.netlify.com/api/v1/badges/b7189b96-54cf-45fd-8b6a-a4ba6c12f1dd/deploy-status)](https://app.netlify.com/sites/quirky-benz-32940b/deploys)
[![markdown](https://img.shields.io/badge/format-markdown-ffaabb.svg?style=flat-square&logo=Markdown&logoColor=ffaabb)](http://markdown.org)
[![IP](//img.shields.io/badge/IP-127.0.0.1-purple.svg?style=flat-square&logo=IP&logoColor=red)](//blockRing™.gq")
(<span class="ip">ip</span>)
![Codetally](https://img.shields.io/codetally/michel47/bin)
![ct](https://www.codetally.com/shield/username/reponame?1501195872560)

___



Everything is change, in perpetual transformation
and we try to develop system that are [immutable][IM],
ledger that are permanent !

What is wrong with the whole [blockchain industry][BI] ?

[IM]: {{site.search}}=immutable+ledger
[BI]: {{site.search}}=!g+what's+wrong+with+the+blockchain+industry


Out of all the blockchains and ledger technologies around
we are missing a simple one :

 a good way to track changes 


 we need mutable blockchains

 A system what will tell accurately the value of a mutable 
 and this without spending tons of network / computing resources.

 we don't want to wastefully "gamble" to have the HEAD block from the chain.


With IPMS We have taken a different approach to tackle the problem.
we consider immuables things of the past, and mutables things of the present.

IN fact this inspired by nature, by who we are as a global society,
we are with all form of life as a whole a complex organism.
we organize, we continuously communicate and exchange,
and this is only possible because of an inherent trust with oour peers.
Today we can extend our reach globaly and communicate safely at large to the *(inter)*net.


A mutable is a "decentalized element" that can be access anywhere
with its value maintained by anyone.
It constitutes an "immutable addressing scheme" every one can trust to find data.

Every shared resources it can be "abused" and the value of a mutable can be "hijacked".
however if we ask everyone to sign their update we have a way to sort our the good records
from the bad.


{% for post in site.posts %}
    <a href="{{ post.url }}">
        <h2>{{ post.title }} &mdash; {{ post.date | date_to_string }}</h2>
    </a>
    {{ post.content }}
{% endfor %}




