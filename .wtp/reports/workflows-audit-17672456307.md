# Workflows audit – run 17672456307

- Repo: BoskiDionysos/weektoppick-wp-modules
- SHA:  c1806c0136213400e3187b3c507235d4f7d993f6
- Actor:BoskiDionysos

## Summary

Raporty szczegółowe poniżej.
### Files in .github/workflows
```
.github/workflows/agent-push.yml
.github/workflows/ai-upsert-file.yml
.github/workflows/apply-inbox-patch.yml
.github/workflows/audit-workflows.yml
.github/workflows/collect-run-logs.yml
.github/workflows/deploy-site.yml
.github/workflows/deploy-ssh-smoketest.yml
.github/workflows/deploy-to-hostinger.yml
.github/workflows/export-gh-digest.yml
.github/workflows/exporter-watchdog.yml
.github/workflows/generate-manifest.yml
.github/workflows/gsc-collector.yml
.github/workflows/import-live-to-repo.yml
.github/workflows/patch-from-comment.yml
.github/workflows/snapshot-watchdog.yml
.github/workflows/ssot-guard.yml
.github/workflows/workflow-lint.yml
.github/workflows/wpcli-allowed-plugins.yml
.github/workflows/wtp-exporter-watch.yml
.github/workflows/wtp-snapshot-sync.yml
```

## actionlint

```
[33m.github/workflows/wpcli-allowed-plugins.yml[0m[90m:[0m0[90m:[0m0[90m: [0m[1mcould not parse as YAML: yaml: mapping values are not allowed in this context[0m[90m [syntax-check]
[0m```

## Heuristics

### rsync --filter=merge
_Problem_: użycie '--filter=merge <file>' potrafi dać 'unexpected end of filter rule: merge'.
_Rekomendacja_: użyj '--exclude-from=<file>' i zapisuj wzorce jako 'katalog/***'.
```
.github/workflows/audit-workflows.yml:86:          # 1) rsync --filter=merge (częsty błąd)
.github/workflows/audit-workflows.yml:87:          if grep -R --line-number --color=never -E 'rsync .*--filter=merge' .github/workflows/*.y*ml >/tmp/grep_merge.txt 2>/dev/null; then
.github/workflows/audit-workflows.yml:88:            echo "### rsync --filter=merge" >> "$REPORT"
```
### curl /health endpoint
_Uwaga_: upewnij się, że endpoint istnieje na prod i jest w cudzysłowach.
Przykład bezpiecznego użycia: curl -fsS "http://127.0.0.1/wp-json/wtp-ro-open/v1/health" || echo 'warn'
```
.github/workflows/audit-workflows.yml:101:            echo "Przykład bezpiecznego użycia: curl -fsS \"http://127.0.0.1/wp-json/wtp-ro-open/v1/health\" || echo 'warn'" >> "$REPORT"
.github/workflows/deploy-to-hostinger.yml:157:            curl -fsS "http://127.0.0.1/wp-json/wtp-ro-open/v1/health" && echo "Health OK"
.github/workflows/wpcli-allowed-plugins.yml:111:          sshpass -p "$PASS" ssh -p "$PORT" -o StrictHostKeyChecking=no "$USER@$HOST" "curl -fsS \"http://127.0.0.1/wp-json/wtp-ro-open/v1/health\" || echo '::warning::health endpoint failed'"
```
### Secrets presence
- expects secret: DEPLOY_HOST
- expects secret: DEPLOY_PORT
- expects secret: DEPLOY_USER
- expects secret: DEPLOY_PASS
- expects secret: DEPLOY_TARGET

_Sprawdź w repo Settings → Secrets → Actions_.

### BOM/CRLF scan
- OK (no BOM/CRLF)

### Lists presence (.wtp)
- found: .wtp/allowed-plugins.txt
- found: .wtp/protected-plugins.txt

### Reference plugin slugs (info)
- wp.org: litespeed-cache, wordfence, cookie-law-info, translatepress-multilingual, seo-by-rank-math, polylang, weglot, pretty-link
- komercyjne (chronione): sitepress-multilingual-cms, wpml-string-translation, multilingualpress

### Verdict: ⚠️ Issues found (1) or actionlint errors=1
