# ECOSYSTEM AUDIT (repo ↔ server)
- Run ID: 17889681885

## Theme
- Active theme on server: **wtp-core-theme**

## Plugins – overview
- Server installed (approx slugs): 6
- Server active (slugs): 6
- Repo available (slugs): 0

### Diff – only on server
- classic-editor
- cookie-law-info
- litespeed-cache
- pretty-link
- seo-by-rank-math
- wordfence

### Diff – only in repo (not installed on server)
_none_

### Active on server but missing in repo
- classic-editor
- cookie-law-info
- litespeed-cache
- pretty-link
- seo-by-rank-math
- wordfence

### Version mismatches (server vs repo headers)
_none_

## MU-plugins (repo overview)
- mu-plugins/00-mu-safe-loader.php
- mu-plugins/wtp-canonical-redirects.php
- mu-plugins/wtp-canonical.php
- mu-plugins/wtp-deploy-guard.php
- mu-plugins/wtp-dev-bridge.php
- mu-plugins/wtp-patch-safe-loader-log.php
- mu-plugins/wtp-ro-exporter.php
- mu-plugins/wtp-theme-guardian.php

## Notes
- Slug detection on server uses heuristics; authoritative active list comes from `active_plugins` paths.
- MU-plugins activity cannot be derived from server list; here we show only what exists in the repo.
- Use this report to decide **which plugins to promote into SSOT** and which to **migrate into custom MU**.
