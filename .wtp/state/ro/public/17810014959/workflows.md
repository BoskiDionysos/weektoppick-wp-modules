# Workflows index

## 00_ai_upsert_file (00_ai_upsert_file.yml)
- Triggers: `None`
- Jobs: upsert

## 00_repo_inventory (00_repo_inventory.yml)
- Triggers: `None`
- Jobs: inventory

## 00_workflows_dump (00_workflows_dump.yml)
- Triggers: `None`
- Jobs: dump

## 01_deploy (single-run, password auth, strict host key, rsync, sanity) (01_deploy.yml)
- Triggers: `None`
- Jobs: deploy

## 02_wpcli (install/update/activate from SSOT, secure SSH) (02_wpcli.yml)
- Triggers: `None`
- Jobs: wpcli

## 03_snapshot (WordPress -> SSOT, full state + code analysis, offline assembly) (03_snapshot.yml)
- Triggers: `None`
- Jobs: snapshot

## 03_snapshot_failopen (ALWAYS PUBLISH latest) (03_snapshot_failopen.yml)
- Triggers: `None`
- Jobs: snapshot

## 03_snapshot_latest_repair (03_snapshot_latest_repair.yml)
- Triggers: `None`
- Jobs: repair

## 04_orchestrator (04_orchestrator.yml)
- Triggers: `None`
- Jobs: orchestrate

## 05_patcher (05_patcher.yml)
- Triggers: `None`
- Jobs: patch

## 06_verifier (06_verifier.yml)
- Triggers: `None`
- Jobs: verify

## 99_mu_hunt_fix (remove catcher, hard rewrite safe loader, opcache reset) (99_ssh_hotfix.yml)
- Triggers: `None`
- Jobs: hunt_fix

## Agent Push (Silent Mode) (agent-push.yml)
- Triggers: `None`
- Jobs: build-deploy-sync-and-verify

## AI Upsert File (ai-upsert-file.yml)
- Triggers: `None`
- Jobs: upsert

## Apply Inbox Patch (apply-inbox-patch.yml)
- Triggers: `None`
- Jobs: apply

## Audit: workflows & deploy wiring (audit-workflows.yml)
- Triggers: `None`
- Jobs: audit

## Bulk disable workflows (bulk-disable-workflows.yml)
- Triggers: `None`
- Jobs: disable

## CI Logs: digest & report (ci-logs-digest.yml)
- Triggers: `None`
- Jobs: digest

## Collect Run Logs (on failure → commit + issue) (collect-run-logs.yml)
- Triggers: `None`
- Jobs: collect

## WP deploy + WP-CLI (deploy-and-wpcli.yml)
- Triggers: `None`
- Jobs: deploy_and_wpcli

## WP Deploy (code + diagnostics) (deploy-site.yml)
- Triggers: `None`
- Jobs: deploy

## SSH Smoketest (deploy-ssh-smoketest.yml)
- Triggers: `None`
- Jobs: ping

## Deploy to Hostinger (Atomic GH→WP, normalized bundle) (deploy-to-hostinger.yml)
- Triggers: `None`
- Jobs: deploy

## Export GH Digest (full repo snapshot for diagnostics) (export-gh-digest.yml)
- Triggers: `None`
- Jobs: build-and-publish

## Exporter Watchdog (exporter-watchdog.yml)
- Triggers: `None`
- Jobs: watchdog

## Manifest (build & commit) (generate-manifest.yml)
- Triggers: `None`
- Jobs: build-manifest

## GSC collector (gsc-collector.yml)
- Triggers: `None`
- Jobs: gsc

## Import Live → Repo (PR) (import-live-to-repo.yml)
- Triggers: `None`
- Jobs: pull-live

## mu_catcher_hunt (mu-catcher-hunt.yml)
- Triggers: `None`
- Jobs: hunt, scan

## mu_bom_scan (mu_bom_scan.yml)
- Triggers: `None`
- Jobs: scan

## mu_fix_functions_cleanup (mu_fix_functions_cleanup.yml)
- Triggers: `None`
- Jobs: fix

## mu_hotfix_headers (mu_hotfix_headers.yml)
- Triggers: `None`
- Jobs: fix

## Pipeline deploy + wpcli (pipeline-deploy-wpcli.yml)
- Triggers: `None`
- Jobs: pipeline

## Protected plugins sanity (remote check + report) (protected-plugins-sanity.yml)
- Triggers: `None`
- Jobs: sanity

## Remote health snapshot (remote-health.yml)
- Triggers: `None`
- Jobs: health

## Remote inventory (plugins & themes) (remote-inventory.yml)
- Triggers: `None`
- Jobs: inventory

## Snapshot Inventory (prod, from SSOT) (snapshot-inventory.yml)
- Triggers: `None`
- Jobs: snapshot

## Snapshot Watchdog (snapshot-watchdog.yml)
- Triggers: `None`
- Jobs: watchdog

## SSOT Guard (ssot-guard.yml)
- Triggers: `None`
- Jobs: validate

## Workflow Lint (actionlint → log to repo + issue) (workflow-lint.yml)
- Triggers: `None`
- Jobs: lint

## WP-CLI install update allowed plugins (wpcli-allowed-plugins.yml)
- Triggers: `None`
- Jobs: wpcli

## WP-CLI plugins debug & install (wpcli-plugins-debug.yml)
- Triggers: `None`
- Jobs: debug

## WTP Exporter Watch (wtp-exporter-watch.yml)
- Triggers: `None`
- Jobs: watch

## WTP Snapshot Sync (wtp-snapshot-sync.yml)
- Triggers: `None`
- Jobs: sync

