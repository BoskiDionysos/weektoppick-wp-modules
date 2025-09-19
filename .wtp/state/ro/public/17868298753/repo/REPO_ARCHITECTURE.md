# REPO ARCHITECTURE (snapshot)
- Run ID: 17868298753
- Run TS (UTC): 2025-09-19T19:49:02Z

## Summary
- Files: 1197
- other: 172 • 94.0 MB
- .wtp: 949 • 8.2 MB
- workflow-active: 14 • 89.3 KB
- workflow-quarantine: 52 • 225.8 KB
- mu-plugin: 2 • 2.9 KB
- theme: 8 • 6.3 KB

## MU-Plugins (discovery)
| file | lint | actions | filters | version |
|---|---|---:|---:|---|
| wp-content/mu-plugins/zzz-wtp-emergency-recovery.php | ERR | 1 | 1 |  |
| wp-content/mu-plugins/000-wtp-safemode.php | ERR | 1 | 3 |  |

## Workflows (active)
- .github/workflows/01_deploy.yml
- .github/workflows/94_collect_errors.yml
- .github/workflows/91_restore_plugins_safely.yml
- .github/workflows/92_root_healthcheck.yml
- .github/workflows/98_promote_theme.yml
- .github/workflows/03_snapshot_full.yml
- .github/workflows/00_repo_inventory.yml
- .github/workflows/93_enable_debug_and_collect.yml
- .github/workflows/99_switch_theme_now.yml
- .github/workflows/ai-upsert-file.yml
- .github/workflows/03_repo_snapshot.yml
- .github/workflows/02_wpcli.yml
- .github/workflows/gsc-collector.yml
- .github/workflows/95_admin_unbrick.yml

## Workflows (quarantine)
- .github/workflows._quarantine/12_upsert_deploy_test.yml
- .github/workflows._quarantine/wpcli-plugins-debug.yml
- .github/workflows._quarantine/workflow-lint.yml
- .github/workflows._quarantine/95B_hard_reset.yml
- .github/workflows._quarantine/README.md
- .github/workflows._quarantine/deploy-to-hostinger.yml
- .github/workflows._quarantine/mu-catcher-hunt.yml
- .github/workflows._quarantine/ssot-guard.yml
- .github/workflows._quarantine/03_snapshot_latest_repair.yml
- .github/workflows._quarantine/ci-brief.yml
- .github/workflows._quarantine/wtp-exporter-watch.yml
- .github/workflows._quarantine/00_workflows_dump.yml
- .github/workflows._quarantine/96_emergency_heal.yml
- .github/workflows._quarantine/import-live-to-repo.yml
- .github/workflows._quarantine/05_patcher.yml
- .github/workflows._quarantine/pipeline-deploy-wpcli.yml
- .github/workflows._quarantine/ci-logs-digest.yml
- .github/workflows._quarantine/deploy-and-wpcli.yml
- .github/workflows._quarantine/mu_hotfix_headers.yml
- .github/workflows._quarantine/generate-manifest.yml
- .github/workflows._quarantine/06_verifier.yml
- .github/workflows._quarantine/bulk-disable-workflows.yml
- .github/workflows._quarantine/protected-plugins-sanity.yml
- .github/workflows._quarantine/00_ai_upsert_file.yml
- .github/workflows._quarantine/03_repo_audit.yml
- .github/workflows._quarantine/deploy-ssh-smoketest.yml
- .github/workflows._quarantine/snapshot-watchdog.yml
- .github/workflows._quarantine/mu_bom_scan.yml
- .github/workflows._quarantine/audit-workflows.yml
- .github/workflows._quarantine/97_theme_fix_functions.yml
- .github/workflows._quarantine/export-gh-digest.yml
- .github/workflows._quarantine/agent-push.yml
- .github/workflows._quarantine/exporter-watchdog.yml
- .github/workflows._quarantine/00_fix_workflows_layout.yml
- .github/workflows._quarantine/snapshot-inventory.yml
- .github/workflows._quarantine/04_orchestrator.yml
- .github/workflows._quarantine/00_repo_housekeeping.yml
- .github/workflows._quarantine/wpcli-allowed-plugins.yml
- .github/workflows._quarantine/autopilot-controller.yml.disabled
- .github/workflows._quarantine/remote-health.yml
- .github/workflows._quarantine/patch-from-comment.yml.disabled
- .github/workflows._quarantine/00_quarantine.yml
- .github/workflows._quarantine/99_ssh_hotfix.yml
- .github/workflows._quarantine/deploy-site.yml
- .github/workflows._quarantine/mu_fix_functions_cleanup.yml
- .github/workflows._quarantine/00_prune_wtp.yml
- .github/workflows._quarantine/03_snapshot_failopen.yml
- .github/workflows._quarantine/03_snapshot_core.yml
- .github/workflows._quarantine/collect-run-logs.yml
- .github/workflows._quarantine/wtp-snapshot-sync.yml
- .github/workflows._quarantine/remote-inventory.yml
- .github/workflows._quarantine/apply-inbox-patch.yml
