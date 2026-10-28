"""Pobiera zakładki arkusza Google Sheets jako pliki CSV do folderu data/ gry.

Arkusz musi być udostępniony przez link (co najmniej "Przeglądający").
Konfiguracja: sheets_config.json obok skryptu
  - "tabs": nazwa pliku CSV (bez .csv) -> gid zakładki (liczba po "#gid=" w adresie zakładki).

Użycie:
  python tools/sync_sheets.py            pobiera i zapisuje zmienione pliki
  python tools/sync_sheets.py --dry-run  tylko pokazuje, co by się zmieniło

Pliki są zapisywane dopiero, gdy wszystkie zakładki pobiorą się poprawnie.
Brakujące pliki <nazwa>.csv.import (importer "keep") są tworzone automatycznie –
bez nich Godot traktowałby CSV jako plik tłumaczeń.
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


def normalize(text: str) -> str:
    """Ujednolica CSV: końce linii \\n, bez pustych wierszy na końcu, bez pustych kolumn na końcu."""
    rows = list(csv.reader(io.StringIO(text)))
    while rows and not any(cell.strip() for cell in rows[-1]):
        rows.pop()
    if not rows or not any(cell.strip() for cell in rows[0]):
        raise RuntimeError("tab is empty (no header row)")
    width = max(i + 1 for i, cell in enumerate(rows[0]) if cell.strip())
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    for row in rows:
        writer.writerow((row + [""] * width)[:width])
    return out.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Google Sheets tabs to data/*.csv")
    parser.add_argument("--dry-run", action="store_true", help="only show what would change")
    args = parser.parse_args()

    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    output_dir = (SCRIPT_DIR / config["output_dir"]).resolve()

    downloaded: dict[str, str] = {}
    errors = 0
    for name, gid in config["tabs"].items():
        try:
            downloaded[name] = normalize(download_tab(config["spreadsheet_id"], gid))
            print(f"  ok      {name} ({downloaded[name].count(chr(10)) - 1} rows)")
        except RuntimeError as error:
            errors += 1
            print(f"  ERROR   {name}: {error}")
    if errors:
        print(f"\n{errors} tab(s) failed - nothing was written.")
        return 1

    changed = 0
    for name, content in downloaded.items():
        path = output_dir / f"{name}.csv"
        old = path.read_text(encoding="utf-8") if path.exists() else None
        if old == content:
            continue
        changed += 1
        print(f"  {'new' if old is None else 'changed':7} {path.name}")
        if args.dry_run:
            continue
        path.write_text(content, encoding="utf-8", newline="")
        import_path = path.with_name(path.name + ".import")
        if not import_path.exists():
            import_path.write_text(IMPORT_FILE, encoding="utf-8", newline="")

    if changed == 0:
        print("\nAll files are up to date.")
    elif args.dry_run:
        print(f"\n{changed} file(s) would change (dry run, nothing written).")
    else:
        print(f"\n{changed} file(s) updated in {output_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
