---
title: Deploying to Production
weight: 10
description: Deploying the policy center
summary: Deploying the policy center
---

## Prerequisites

- A web server capable of serving static files

## CI or Local

To build the site for production, run the following command:

```bash
$> PUBLISH=1 devbox run ci
```

This will build the site and pdfs and place the output in the `public` directory.

The contents of the `public` directory can be deployed to any web server capable of serving static files.