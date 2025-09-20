# REPO AUDIT (full)
- Run ID: 17881789522

## Totals
- plugins: **0**
- mu_plugins: **10**
- hooks: **29**
- functions: **30**
- classes: **2**
- includes: **0**
- deps_resolved_edges: **0**
- deps_unresolved: **0**
- scanned_php_files: **24**

## Notes
- Obsługiwane układy katalogów: `wp-content/plugins|mu-plugins|themes` oraz `plugins|mu-plugins|themes` w root.
- Dependencies: prosta rezolucja ścieżek (relatywne, __DIR__/dirname(__FILE__)); dynamiczne `include $var` mogą pozostać w `unresolved`.
