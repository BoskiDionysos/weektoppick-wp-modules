# ECOSYSTEM AUDIT (repo ↔ server)
- Run ID: 17890139276

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
- wp-content/mu-plugins/000-wtp-safemode.php
- wp-content/mu-plugins/zzz-wtp-emergency-recovery.php

## Notes
- Slug detection on server uses heuristics; authoritative active list comes from `active_plugins` paths.
- MU-plugins activity cannot be derived from server list; here we show only what exists in the repo.
- Use this report to decide **which plugins to promote into SSOT** and which to **migrate into custom MU**.
