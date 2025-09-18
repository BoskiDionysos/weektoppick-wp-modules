# REPO AUDIT
- Run ID: 17834935694
- Run TS (UTC): 2025-09-18T16:19:53Z

## Summary
- Files: 550
- config: 65 • 87.5 MB
- docs: 4 • 7.5 KB
- other: 87 • 5.8 MB
- theme: 1 • 792.0 B
- wtp: 393 • 4.0 MB

**Workflows active:** 0  |  **quarantine:** 0
MU files: 0 • Plugins files: 0 • Themes files: 1 • .wtp files: 393

## Biggest files (>10MB)
_none_

## Recommendations
- Keep active only 6 workflows (deploy/wpcli/snapshot + ai-upsert/apply-inbox-patch + gsc).
- Leave all others in `.github/workflows._quarantine/` (restore one-by-one after core is stable).
- Remove big archives from Git (use artifacts).
- In `.wtp/` keep `latest/` + few recent runs; prune old runs periodically.
