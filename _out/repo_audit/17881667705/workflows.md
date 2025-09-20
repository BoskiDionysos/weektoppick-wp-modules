# Workflows index

## 01_deploy (single-run, password auth, strict host key, rsync, sanity) (01_deploy.yml)
- Triggers: `None`
- Jobs: deploy

## 02a_server_snapshot (read-only, WP core/themes/plugins/options → JSON) (02_server_snapshot.yml)
- Triggers: `None`
- Jobs: snapshot

## 02_wpcli (install/update/activate from SSOT, strict SSH, safe publish) (02_wpcli.yml)
- Triggers: `None`
- Jobs: wpcli

## 03_repo_audit_full (read-only, complete) (03_repo_audit_full.yml)
- Triggers: `None`
- Jobs: audit

## 03_repo_snapshot (03_repo_snapshot.yml)
- Triggers: `None`
- Jobs: snapshot

## 04_ecosystem_correlate (repo↔server correlation) (04_ecosystem_correlate.yml)
- Triggers: `None`
- Jobs: correlate

## 91_restore_plugins_safely (91_restore_plugins_safely.yml)
- Triggers: `None`
- Jobs: restore

## 92_root_healthcheck (92_root_healthcheck.yml)
- Triggers: `None`
- Jobs: check

## 93_enable_debug_and_collect (93_enable_debug_and_collect.yml)
- Triggers: `None`
- Jobs: debug-pack

## 94_collect_errors (94_collect_errors.yml)
- Triggers: `None`
- Jobs: collect

## 95_admin_unbrick (95_admin_unbrick.yml)
- Triggers: `None`
- Jobs: heal

## 98_promote_theme (98_promote_theme.yml)
- Triggers: `None`
- Jobs: promote

## 99_switch_theme_now (99_switch_theme_now.yml)
- Triggers: `None`
- Jobs: fix

## AI Upsert File (ai-upsert-file.yml)
- Triggers: `None`
- Jobs: upsert

## GSC collector (gsc-collector.yml)
- Triggers: `None`
- Jobs: gsc

