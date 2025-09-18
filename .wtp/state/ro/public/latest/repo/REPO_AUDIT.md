# REPO AUDIT
- Run ID: 17820491037
- Run TS (UTC): 2025-09-18T06:49:01Z

## Summary
- Files: 5070
- config: 65 • 87.5 MB
- docs: 4 • 7.5 KB
- other: 87 • 5.8 MB
- wtp: 4914 • 42.9 MB

**Workflows active:** 0  |  **quarantine:** 0
MU files: 0 • Plugins files: 0 • Themes files: 0 • .wtp files: 4914

## Biggest files (>10MB)
_none_

## Recommendations
- Keep active only 6 workflows (deploy/wpcli/snapshot + ai-upsert/apply-inbox-patch + gsc).
- Leave others in `.github/workflows._quarantine/`; restore one-by-one after core is stable.
- Remove big archives from Git (use artifacts).
- In `.wtp/` keep `latest/` + few recent runs; prune old runs periodically.
