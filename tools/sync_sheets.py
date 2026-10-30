"""Pobiera zakładki arkuszy Google Sheets jako pliki CSV gry: dane do folderu data/ i tłumaczenia
do localization/translations.csv.

Arkusze muszą być udostępnione przez link (co najmniej "Przeglądający").
Konfiguracja: sheets_config.json obok skryptu
  - "spreadsheet_id" + "tabs": arkusz danych; nazwa pliku CSV (bez .csv) -> gid zakładki (liczba po "#gid="
    w adresie zakładki),
  - "portraits": arkusz wag portretów ("spreadsheet_id" + "tabs" jak wyżej, pliki też do data/),
  - "translations": arkusz tekstów ("spreadsheet_id", "gid", "output" – ścieżka względem skryptu).

Użycie:
  python tools/sync_sheets.py                 pobiera dane, wagi portretów i tłumaczenia, zapisuje zmienione pliki
  python tools/sync_sheets.py --data          tylko dane
  python tools/sync_sheets.py --portraits     tylko wagi portretów (data/portrait_weights.csv)
  python tools/sync_sheets.py --translations  tylko tłumaczenia
  python tools/sync_sheets.py --dry-run       tylko pokazuje, co by się zmieniło (łączy się z powyższymi)

Pliki są zapisywane dopiero, gdy wszystkie zakładki pobiorą się poprawnie.
Brakujące pliki <nazwa>.csv.import (importer "keep") są tworzone automatycznie dla danych –
bez nich Godot traktowałby CSV jako plik tłumaczeń.

Tłumaczenia: pierwsza kolumna to klucze, kolejne – języki (nagłówek = kod języka, np. en, pl). Kolumny,
których nagłówek zaczyna się od "_" (np. "_notes"), i wiersze bez klucza (odstępy między sekcjami) nie trafiają
do gry. Powtórzony klucz przerywa synchronizację, brakujące tłumaczenia są tylko wypisywane.
Godot importuje zmieniony plik sam po powrocie do edytora (bez edytora: godot --headless --path . --import).
"""

import argparse
import csv
import io
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SCRIPT_DIR / "sheets_config.json"
EXPORT_URL = "https://docs.google.com/spreadsheets/d/{id}/export?format=csv&gid={gid}"
IMPORT_FILE = '[remap]\n\nimporter="keep"\n'


def download_tab(spreadsheet_id: str, gid: int) -> str:
    url = EXPORT_URL.format(id=spreadsheet_id, gid=gid)
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            content_type = response.headers.get("Content-Type", "")
            data = response.read()
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            raise RuntimeError("no access - share the sheet by link (Viewer)") from None
        if error.code in (400, 404):
            raise RuntimeError(f"tab with gid={gid} not found") from None
        raise RuntimeError(f"HTTP {error.code}") from None
    except urllib.error.URLError as error:
        raise RuntimeError(f"connection error: {error.reason}") from None
    if "text/csv" not in content_type:
        raise RuntimeError("Google returned a page instead of CSV - check link sharing and gid")
    return data.decode("utf-8-sig")


def read_rows(text: str) -> list[list[str]]:
    """Wiersze CSV bez pustych wierszy na końcu i bez pustych kolumn na końcu (szerokość = nagłówek)."""
    rows = list(csv.reader(io.StringIO(text)))
    while rows and not any(cell.strip() for cell in rows[-1]):
        rows.pop()
    if not rows or not any(cell.strip() for cell in rows[0]):
        raise RuntimeError("tab is empty (no header row)")
    width = max(i + 1 for i, cell in enumerate(rows[0]) if cell.strip())
    return [(row + [""] * width)[:width] for row in rows]


def normalize(text: str) -> str:
    """Ujednolica CSV: końce linii \\n, bez pustych wierszy na końcu, bez pustych kolumn na końcu."""
    out = io.StringIO()
    csv.writer(out, lineterminator="\n").writerows(read_rows(text))
    return out.getvalue()


def _quote(cell: str) -> str:
    # Cudzysłów także przy spacjach na brzegach (np. " or "), żeby nie zgubił ich żaden czytnik CSV.
    if any(char in cell for char in ',"\n\r') or cell != cell.strip():
        return '"' + cell.replace('"', '""') + '"'
    return cell


def normalize_translations(text: str) -> tuple[str, list[str]]:
    """CSV tłumaczeń dla Godota (bez kolumn "_…" i wierszy bez klucza) oraz lista ostrzeżeń."""
    rows = read_rows(text)
    columns = [i for i, header in enumerate(rows[0]) if not header.strip().startswith("_")]
    if len(columns) < 2:
        raise RuntimeError("translations need a key column and at least one language column")
    header = [rows[0][i].strip() for i in columns]
    kept = [header]
    seen: set[str] = set()
    missing: dict[str, list[str]] = {}
    for row in rows[1:]:
        key = row[columns[0]].strip()
        if not key:
            continue
        if key in seen:
            raise RuntimeError(f"duplicate key {key}")
        seen.add(key)
        cells = [key] + [row[i] for i in columns[1:]]
        for language, cell in zip(header[1:], cells[1:]):
            if not cell.strip():
                missing.setdefault(language, []).append(key)
        kept.append(cells)
    warnings = [f"missing {language} ({len(keys)}): {', '.join(keys)}" for language, keys in missing.items()]
    return "".join(",".join(_quote(cell) for cell in row) + "\n" for row in kept), warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Google Sheets tabs to data/*.csv and translations")
    parser.add_argument("--data", action="store_true", help="only game data (data/*.csv)")
    parser.add_argument("--portraits", action="store_true", help="only portrait weights")
    parser.add_argument("--translations", action="store_true", help="only translations")
    parser.add_argument("--dry-run", action="store_true", help="only show what would change")
    args = parser.parse_args()
    only = args.data or args.portraits or args.translations
    sync_data = args.data or not only
    sync_portraits = args.portraits or not only
    sync_translations = args.translations or not only

    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    output_dir = (SCRIPT_DIR / config["output_dir"]).resolve()

    downloaded: dict[Path, str] = {}
    errors = 0
    sources = []
    if sync_data:
        sources.append((config["spreadsheet_id"], config["tabs"]))
    if sync_portraits:
        sources.append((config["portraits"]["spreadsheet_id"], config["portraits"]["tabs"]))
    for spreadsheet_id, tabs in sources:
        for name, gid in tabs.items():
            try:
                content = normalize(download_tab(spreadsheet_id, gid))
                downloaded[output_dir / f"{name}.csv"] = content
                print(f"  ok      {name} ({content.count(chr(10)) - 1} rows)")
            except RuntimeError as error:
                errors += 1
                print(f"  ERROR   {name}: {error}")
    if sync_translations:
        source = config["translations"]
        try:
            content, warnings = normalize_translations(download_tab(source["spreadsheet_id"], source["gid"]))
            downloaded[(SCRIPT_DIR / source["output"]).resolve()] = content
            print(f"  ok      translations ({content.count(chr(10)) - 1} keys)")
            for warning in warnings:
                print(f"  WARNING translations: {warning}")
        except RuntimeError as error:
            errors += 1
            print(f"  ERROR   translations: {error}")
    if errors:
        print(f"\n{errors} tab(s) failed - nothing was written.")
        return 1

    changed = 0
    for path, content in downloaded.items():
        old = path.read_text(encoding="utf-8") if path.exists() else None
        if old == content:
            continue
        changed += 1
        print(f"  {'new' if old is None else 'changed':7} {path.name}")
        if args.dry_run:
            continue
        path.write_text(content, encoding="utf-8", newline="")
        import_path = path.with_name(path.name + ".import")
        if path.parent == output_dir and not import_path.exists():
            import_path.write_text(IMPORT_FILE, encoding="utf-8", newline="")

    if changed == 0:
        print("\nAll files are up to date.")
    elif args.dry_run:
        print(f"\n{changed} file(s) would change (dry run, nothing written).")
    else:
        print(f"\n{changed} file(s) updated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
