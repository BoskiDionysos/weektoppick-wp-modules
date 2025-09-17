# 🗂️ Workflows Quarantine

Ten katalog zawiera **workflowy tymczasowo wyłączone** z aktywnego CI/CD WeekTopPick.

## Zasady:
- To **NIE są śmieci** – to workflowy zachowane do przeglądu lub późniejszego użycia.
- Aktywne workflowy znajdują się wyłącznie w `.github/workflows/`.
- Powód kwarantanny: stabilizacja core (deploy, wpcli, snapshot, AI upsert, apply-patch, GSC).
- Każdy plik z tego katalogu można łatwo przywrócić → wystarczy przenieść z powrotem do `.github/workflows/`.

## Status:
- **Core**: 01_deploy.yml, 02_wpcli.yml, 03_snapshot.yml, ai-upsert-file.yml, apply-inbox-patch.yml, gsc-collector.yml
- **Quarantine**: wszystkie pozostałe (przeglądane etapami po stabilizacji core).

> 🔒 Zasada: najpierw zielony core, potem stopniowo wracamy do plików z tego katalogu (status „Review”).
