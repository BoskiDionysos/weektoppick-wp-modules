# WeekTopPick — Releases (snapshoty stabilnych wydań)

To jest katalog **snapshotów stabilnych** (punkty odniesienia do rollbacków).  
Git trzyma całą historię, ale tutaj trzymamy **gotowe paczki/plik YML**, które „na pewno działały”.

## Zasady ogólne
- Każdy snapshot ma **wersję semantyczną** `vX.Y.Z` i **skrót commita** (7 znaków).
- Nazewnictwo:
  - **Wtyczki (ZIP)**: `<slug>_vX.Y.Z_sha<7>.zip`
  - **Motywy (ZIP)**: `<slug>_vX.Y.Z_sha<7>.zip`
  - **Workflows (YML)**: `<name>_vX.Y.Z.yml`
- Snapshotów **nie edytujemy**. Nowa wersja = nowy plik.

## Struktury
- `releases/plugins/` — paczki ZIP z wtyczkami.
- `releases/themes/` — paczki ZIP z motywami.
- `releases/workflows/` — utrwalone stabilne YML (kopie workflowów).

## Jak zrobić snapshot (lokalnie)
1) Zbuduj paczkę:
```bash
# plugin
cd plugins/wtp-affiliate-core && zip -r "../../releases/plugins/wtp-affiliate-core_v1.0.0_sha$(git rev-parse --short HEAD).zip" . && cd -

# theme
cd themes/wtp-core && zip -r "../../releases/themes/wtp-core_v1.0.0_sha$(git rev-parse --short HEAD).zip" . && cd -
