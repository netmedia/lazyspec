Nastavljamo rad na LazySpecu i Nava projektu. Odgovaraj mi na hrvatskom. Ovo je stanje gdje smo stali:

## Repozitoriji
- **LazySpec** (`D:\Development\Netmedia\LazySpec`, branch `develop`): terminalski UI i export za OpenSpec. Glavni program je `tools\lazyspec\lazyspec.ps1` (~4000 redaka, PowerShell 5.1/7, bez modula).
  - Datoteka mora ostati **čisti ASCII** (ne-ASCII znakovi kao `[char]0x2026` ili `\u2212` u regexu), LF, bez tabova.
  - Ostalo u repozitoriju: `install.ps1/.exe`, `initintoproject.ps1/.exe`, `build-exe.ps1`, `launcher\launcher.cs`, `tools\lazyspec\export-texts.json` (tekstovi exporta en/hr/de), `tools\lazyspec\LAZYSPEC.md`, `README.md`, `examples\document-theme\document-theme.yaml`, `tests\`.
- **Nava** (`D:\Development\Nava\BackofficeAndPublicApi_2022`): klijentski projekt koji koristi LazySpec instaliran na računalu (bez kita u projektu).
  - `openspec\config.yaml` sadrži `lazyspec:` blok: `name`, `documentTheme: openspec_artifacts/document-theme.yaml`, `figmaToken`, `titles`, `diagrams`.
  - Shema je `feature`. Dokumenti su na hrvatskom, a svi identifikatori i kod na engleskom.

## Commitano
Zadnji commit koji znam u LazySpecu: `44d6be2` (install: tolerira neispravne PATH unose). Nakon toga ima više commitova koje je napravio korisnik (export, jezik, FigJam dijagrami itd.). **Sve opisano ispod NIJE commitano**, ni u LazySpecu ni u Navi. U `lazyspec.ps1` su pomiješane i korisnikove necommitane izmjene (retry na exportu, provjera zaključane datoteke). Commitam samo kad korisnik traži.

## Napravljeno u ovoj sesiji (LazySpec, necommitano)
1. **Word template** (`lazyspec: documentTemplate:` ili `-Template`): .docx se gradi sam (`Export-WordOnBase`). Template je baza: tijelo se briše, ostaje zadnji `sectPr`, sadržaj ide u ugrađene stilove (Title, Subtitle, Heading1-6, Normal, ListParagraph, TableGrid, TOCHeading, TOC1/2). Word COM služi samo za brojeve stranica u sadržaju. Ako template nedostaje ili je pokvaren: greška i exit 1. Postoji upozorenje o fontovima koji nedostaju.
2. **Tema dokumenta** (`lazyspec: documentTheme:` YAML ili `-Theme`): jedan izgled za PDF (Edge), Word i HTML.
   - Ključevi: `numbering`, `page`, `colors`, `styles` (body, title, subtitle, heading1-6, tocHeading, table, link, code), `header`, `footer`, `cover`.
   - Fontovi su u `fonts\` pored teme (i u podfolderima). Ugrađuju se u Word kao obfuscirani `.odttf` (XOR prvih 32 bajta s GUID-om obrnutim redom), a u PDF i HTML preko `@font-face`.
   - Logo u PDF zaglavlju ide preko `image-set(url(png) Nx)` u `@page` margin boxu, **ne kroz SVG** (Chrome ne učita sliku ugniježđenu u SVG).
   - Word dobiva generirani bazni .docx (stilovi, `theme1.xml` s fontovima teme, zaglavlje i podnožje s PAGE/NUMPAGES, `titlePg`).
   - Ako su postavljeni i template i tema: Word koristi template, PDF i HTML temu, a `-Theme` s komandne linije pobjeđuje.
   - Prored: `lineHeight` s veličinom fonta u Wordu postaje `atLeast` (veličina × lineHeight), da PDF i Word budu jednaki. Ćelije tablica u Wordu dobivaju vlastiti mali razmak.
   - S temom nema LazySpecovih linija ispod naslova, sadržaj je običan tekst, a `li` ima razmak.
3. **`-Markdown <file.md>`** (uz `-Export Pdf|Word|Html`): bilo koji markdown postaje dokument u izgledu projekta.
   - Front matter: `title`, `subtitle`, `client`, `author`, `date`, `language`, `toc`, `cover`.
   - Dokument se piše pored .md datoteke, a projekt se traži od foldera te datoteke.
   - Podržani su prijelomi retka (`\` ili dva razmaka na kraju retka).
4. **Mini YAML parser** (`ConvertFrom-ThemeYaml`): obične vrijednosti u bloku čitaju se do kraja retka, sa zarezima.
5. **Install**:
   - `install.ps1/.exe` u repozitoriju: `Profile`, `Global`, `Both`, `Update`, `-Uninstall`.
   - `initintoproject -Remove` vadi kit iz projekta i seli `lazyspec.json` u root projekta.
   - Postavke se čitaju iz `<root>\lazyspec.json` ili `tools\lazyspec\lazyspec.json`.
6. **`models.md`** (novi artefakt v2 sheme, vidi Nava):
   - LazySpec ga prikazuje kao tab i poglavlje (naslovi u `export-texts.json`: Models / Modeli / Datenmodelle).
   - Tablice s prvim stupcem Promjena/Change/Änderung boje retke `+` zeleno, `~` žuto, `-` crveno (u HTML-u i Wordu preko pozadine ćelije).
   - **Dijagram modela** (C# System.Drawing, `LazySpecModelDiagram`) crta se iz `` ### `Name` ``, tablica i redaka `**Veze:**`. Raspored ima optimizaciju zamjenom pozicija. Ubacuje se iza tablice „Pregled”.
7. **Ostali popravci prikaza**:
   - HTML komentari se ne prikazuju;
   - kod u naslovima zadržava veličinu naslova;
   - iza tablica je prazan redak (u terminalu i u exportu);
   - `**Veze:**`, `**Prijelazi:**`, `**Jedinstvenost i indeksi:**` s više stavki odvojenih `; ` prikazuju se kao lista;
   - CSS `overflow-wrap: anywhere` na tekstu i ćelijama, jer je Chrome prije smanjivao cijeli PDF na ~2/3 kad je neka tablica bila preširoka.
8. **Testovi** (bez Pestera): `tests\Test-WordTemplate.ps1` (33), `tests\Test-DocumentTheme.ps1` (42), `tests\Test-MarkdownDocument.ps1` (22), pomoćne funkcije u `tests\TestHelpers.ps1`.
   - Testovi „isto kao prije” trebaju `-Baseline <stari lazyspec.ps1>`. Ja koristim `%TEMP%\lazyspec-baseline\lazyspec.ps1` (HEAD + korisnikove izmjene, bez mojih).
   - Testovi uspoređuju bez `<style>` bloka i bez custom Word stilova.

## Nava (necommitano)
- `openspec_artifacts\document-theme.yaml`: tema prema „Document template.docx”:
  - `numbering: false`;
  - Montserrat 11 pt, `lineHeight 1.4` (= Wordov 1,15);
  - H1 18 pt #FF303C, H2 14 pt #595959 podcrtano;
  - tablica s crnim rubovima;
  - link u boji teksta s podcrtom;
  - logo `images\logo.png`.

  Fontovi su u `openspec_artifacts\fonts\Montserrat font\` (korisnikovi, OFL).
- `openspec\config.yaml`:
  - `documentTheme` je postavljen, `documentTemplate` je maknut;
  - context: svi dokumenti za klijenta idu kroz `lazyspec -Export Word -Markdown ...`;
  - pravilo: modeli, statusi i kod uvijek na engleskom;
  - hrvatski naslovi za models.md.
- **Sheme** `openspec\schemas\{feature,greenfield}` i kopije u `openspec_artifacts\openspec-format-v2\schemas\`:
  - artefakt `models` (proposal → specs → models → research → design → tasks) s predloškom `templates\models.md` (hrvatski u projektu, engleski u kitu);
  - design upućuje na models.md;
  - `tiny` u `tasks.md` ima kratku sekciju „## Modeli” (samo novo, s prvim stupcem Promjena).
  - `openspec schema validate` prolazi za sve tri.
- **`models.md` napisan za sva 4 aktivna changea** (add-charter-reservation-payment, add-guest-account, add-backoffice-online-reservations, fix-mmk-extras-import). Svi prolaze `openspec validate --strict`. Korisnik je prihvatio nazive koje su agenti izabrali.
- Regeneriran je `export\backofficeandpublicapi-2022-add-charter-reservation-payment-2026-11-11.pdf` (s `-KeepDiagrams`).

## Važno za rad
- U bashu, heredoc s Python kodom zna puknuti: Python skripte pišem Write alatom u `%TEMP%` pa ih pokrećem. Izmjene u .ps1 radim Edit alatom ili Pythonom s `assert count == 1`.
- **Nikad ne gasiti sve `msedge` procese** (to su korisnikovi preglednici).
- Za pregled PDF-a: PyMuPDF je u `%TEMP%\pylib` (`PYTHONPATH`). Word → PDF preko COM skripte `/tmp/w2p2.ps1` (`-In`, `-OutPdf`). Pandoc je instaliran.
- Nava exporte radim u `%TEMP%` (`-Out`) s `-KeepDiagrams`, osim kad korisnik traži regeneriranje u `export\`. Ako je PDF otvoren, export javlja da je zaključan.
- Globalni `lazyspec` je star: korisnik treba pokrenuti `.\install.exe Update` da dobije sve ovo.

## Otvoreno / moguće sljedeće
- PDF ima 147 stranica, Word 126 (raspored scenarija i dijagrama se malo razlikuje).
- Ako korisnik želi razmake točno kao u templateu: `spaceAfter` u Nava temi na 0 (sada 6 pt za odlomke i 3 pt za liste, namjerno).
- `[NEEDS CLARIFICATION]` stavke u models.md datotekama čekaju odgovore klijenta.
