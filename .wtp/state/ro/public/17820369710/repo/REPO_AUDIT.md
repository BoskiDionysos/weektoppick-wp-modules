# REPO AUDIT
- Run ID: 17811238927
- Run TS (UTC): 2025-09-17T21:32:01Z

## Summary
- Files: 5066
- config: 65 • 125.8 MB
- docs: 4 • 7.5 KB
- other: 87 • 5.8 MB
- wtp: 4910 • 274.1 MB

**Workflows active:** 0  |  **quarantine:** 0
MU files: 0 • Plugins files: 0 • Themes files: 0 • .wtp files: 4910

## Biggest files (>10MB)
| File | Size | Category |
|---|---:|---|
| .wtp/snapshots/repo-17809130594.tar.gz | 77.8 MB | wtp |
| .wtp/snapshots/repo-latest.tar.gz | 77.8 MB | wtp |
| .wtp/state/ro/public/17809130594/repo-full.tar.gz | 77.8 MB | wtp |
| plugins-bundle.json | 38.3 MB | config |

## Recommendations
- Keep active only 6 workflows (deploy/wpcli/snapshot + ai-upsert/apply-inbox-patch + gsc).
- Leave others in `.github/workflows._quarantine/`; restore one-by-one after core is stable.
- Remove big archives from Git (use artifacts).
- In `.wtp/` keep `latest/` + few recent runs; prune old runs periodically.
