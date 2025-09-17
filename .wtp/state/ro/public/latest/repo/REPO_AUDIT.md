# REPO AUDIT
- Run ID: 17811238927
- Run TS (UTC): 2025-09-17T21:32:01Z

## Podsumowanie
- Plików łącznie: 5066
- Kategorie:
  - **config**: 65 plików, 125.8 MB
  - **docs**: 4 plików, 7.5 KB
  - **other**: 87 plików, 5.8 MB
  - **wtp**: 4910 plików, 274.1 MB

- Workflows: 0 (aktywne: 0, kwarantanna: 0)
- MU-plugins: 0 • Plugins: 0 • Themes: 0 • .wtp plików: 4910

## Workflows – aktywne
_brak_

## Workflows – kwarantanna
_brak_

## Największe pliki (>10MB)
| Plik | Rozmiar | Kategoria |
|---|---:|---|
| .wtp/snapshots/repo-17809130594.tar.gz | 77.8 MB | wtp |
| .wtp/snapshots/repo-latest.tar.gz | 77.8 MB | wtp |
| .wtp/state/ro/public/17809130594/repo-full.tar.gz | 77.8 MB | wtp |
| plugins-bundle.json | 38.3 MB | config |

## .wtp – największe poddrzewa
| Poddrzewo | Rozmiar |
|---|---:|
| .wtp/state/ro | 115.5 MB |
| .wtp/snapshots/repo-17809130594.tar.gz | 77.8 MB |
| .wtp/snapshots/repo-latest.tar.gz | 77.8 MB |
| .wtp/state/ci_logs | 645.4 KB |
| .wtp/snapshots/snapshot-17776432917.json | 220.5 KB |
| .wtp/snapshots/snapshot-17772217424.json | 219.6 KB |
| .wtp/snapshots/snapshot-17773393330.json | 219.6 KB |
| .wtp/snapshots/snapshot-17775331454.json | 219.6 KB |
| .wtp/snapshots/snapshot-17766936598.json | 218.7 KB |
| .wtp/snapshots/snapshot-17767758043.json | 218.7 KB |
| .wtp/snapshots/snapshot-17771085850.json | 217.1 KB |
| .wtp/snapshots/snapshot-17810899154.json | 60.3 KB |
| .wtp/snapshots/snapshot-latest.json | 60.3 KB |
| .wtp/reports/ci-digest-17673445235.md | 53.8 KB |
| .wtp/snapshots/snapshot-17765081644.json | 52.3 KB |
| .wtp/snapshots/snapshot-17765401373.json | 52.3 KB |
| .wtp/snapshots/snapshot-17771796554.json | 16.4 KB |
| .wtp/processed/004-fix-and-disable-exporter.20250909T154203.patch | 13.7 KB |
| .wtp/processed/004-fix-exporter-500.20250909T192921Z.patch | 13.2 KB |
| .wtp/inbox/snapshot-watchdog1.patch | 9.6 KB |

## Rekomendacje
- - Utrzymuj aktywne tylko 6 fundamentów w `.github/workflows/` (deploy/wpcli/snapshot + ai-upsert/apply-inbox-patch + gsc).
- - Pozostałe workflowy trzymaj w `.github/workflows._quarantine/` i przywracaj pojedynczo po stabilizacji.
- - Usuń lub zarchiwizuj duże pliki (>10MB), jeżeli nie muszą być w repo (limit GH 100MB).
- - W `.wtp/` zostaw `latest/` i kilka ostatnich runów; starsze katalogi przenieś do artefaktów.
- - MU-plugins: przejrzyj pod kątem martwych plików / dubli; trzymaj tylko realnie używane.
