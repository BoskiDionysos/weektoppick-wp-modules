# WeekTopPick — LOCKS v3.0 (Single Source of Truth)

---

## 1. Zasady nadrzędne
- **Czas Bartka jest święty** – Owner nie zajmuje się technikaliami.  
- **AI nie zgaduje i nie fantazjuje** – wszystkie działania opierają się na repo, logach, JSON-ach, raportach i cennikach.  
- **AI wdraża niezbędne elementy bez pytania** (np. sanity checki, fallbacki, health checks, cache purge).  
- **SSOT = repo GitHub** – repozytorium jest jedynym źródłem prawdy.  

---

## 2. Języki i lokalizacja
- Wiodący: **EN (slugi w EN)**.  
- Obsługiwane: PL, DE, FR, IT, ES, PT, CZ, SK.  
- Hiszpański i portugalski obejmują także Amerykę Łacińską i południową.  
- Każdy content musi mieć schema hreflang.  

---

## 3. Governance
- **AI decyduje**: technologia, architektura, implementacja kodu, CI/CD, sanity checki, rollbacki.  
- **Owner decyduje (GO/NO-GO)**: partnerzy strategiczni, nowe kategorie, kierunek biznesowy.  
- **Zmiany LOCKS**: tylko przez commit/PR, wersjonowanie MAJOR.MINOR.PATCH.  

---

## 4. GH ↔ WP (relacja środowisk)
- Kierunek: **jednokierunkowy** (GH → WP).  
- WP traktowane jako **runtime**, nie źródło.  
- Manualne zmiany w WP są blokowane (`DISALLOW_FILE_MODS`, MU-plugin Deploy Guard).  
- Snapshoty i raporty mogą wracać z WP do GH, ale jako **read-only dane** (`.wtp/state/`).  

---

## 5. CI/CD i deploy
- Deploy atomowy z paczką `release_<sha>.tar.gz`.  
- **Dry-run sanity** obowiązkowy przed rsync.  
- **Protect filters** chronią LiteSpeed, Wordfence, TranslatePress, Cookie Law Info.  
- **Health check** pod `/wp-json/wtp-ro-open/v1/health` musi być OK.  
- **Cache purge** wykonywany po deployu.  
- **Rollback** = re-deploy poprzedniego commita lub snapshotu z `releases/`.  

---

## 6. Treści, SEO, schema
- Slugi zawsze EN.  
- Title/Meta/Schema generowane przez WTP Core SEO (autorska wtyczka).  
- Schema: `Product`, `Offer`, `Article`, `Breadcrumb`.  
- Fallback: jeśli partner nie dostarcza danych, autopilot stosuje placeholdery i jasny komunikat.  

---

## 7. Charity
- Domyślnie % trafia do NGO miesiąca (rotowana co miesiąc).  
- User może wskazać inną organizację z listy globalnych i lokalnych.  
- Raporty charity publikowane **miesięcznie** w repo.  

---

## 8. Alternatywy i shipping
- Jeśli produkt niedostępny w kraju:  
  - pokazać alternatywę (np. Allegro, MediaExpert),  
  - komunikat: „Dostępne w innym kraju, mogą być dodatkowe koszty wysyłki.”  
- W schema oznaczać `availability = OutOfStock` lub `PreOrder`.  

---

## 9. Partnerzy afiliacyjni
- **Bazowi (must-have):** Amazon, Allegro (PL/CZ/SK), Awin.  
- **AI rekomenduje kolejnych** na podstawie CTR, prowizji, atrakcyjności ofert.  
- Owner akceptuje GO/NO-GO dla nowych partnerów.  
- W repo katalog `releases/partners/` przechowuje adaptery stabilnych integracji.  

---

## 10. OFF features
Na dziś wyłączone, ale opisane w roadmapie:  
- FS (Financial Services: karty, konta, ubezpieczenia).  
- Personalizacja contentu.  
- Community & social login.  
- Exit strategy.  

---

## 11. KPI & progi jakości
- AI ustawia progi startowe wg danych rynkowych, kalibruje automatycznie.  
- Jeśli jakość < progu → retry lub Draft, nigdy auto-publikacja.  

---

## 12. Raporty i monitoring
- **Codzienny raport techniczny** → `.wtp/state/daily_tech_report.json`.  
- **Tygodniowy raport biznesowy** → `.wtp/state/weekly_business_report.json`.  
- **Miesięczny raport charity** → `.wtp/state/charity_report.json`.  
- Snapshot Watchdog i Health Check raportują do repo (fail = error).  

---

## 13. Archiwizacja i releases
- Git = pełne archiwum historii.  
- Dodatkowo katalog `releases/` zawiera snapshoty stabilnych paczek:  
  - `releases/plugins/<plugin>_vX.Y.Z_sha.zip`  
  - `releases/themes/<theme>_vX.Y.Z_sha.zip`  
  - `releases/workflows/<workflow>_vX.Y.Z.yml`  
- AI zawsze używa snapshotów/releases do rollbacku, nigdy nie zgaduje.  

---

## 14. Index JSON (dla AI)
- W repo plik `docs/locks/index.json` zawiera mapę do:  
  - LOCKS v3.0,  
  - snapshotów (`manifest.json`, `bundle.json`, `files_xxx.json`),  
  - `.wtp/state/` (raporty),  
  - workflows (`deploy`, `ai-upsert-file`, `agent-push`, `snapshot-watchdog`).  
- **AI zawsze zaczyna od `docs/locks/index.json`.**  
- Jeśli w `index.json` nie ma potrzebnego zasobu →  
  - **AI nie zgaduje**,  
  - **AI pyta Ownera** o dodanie zasobu do index.json.  

---

# KONIEC DOKUMENTU
