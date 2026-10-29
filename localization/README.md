# Tłumaczenia

`translations.csv` to eksport arkusza Google Sheets `dice_football_text`, zakładka `translations`:
https://docs.google.com/spreadsheets/d/1dcv8GwLfNoDR98XOF2REWDo8Bu15-PXu0PwCRk1FhFY
**Arkusz jest źródłem prawdy – nie edytuj `translations.csv` ręcznie** (następna synchronizacja nadpisze zmiany).

Kolumny: `keys, en, pl` – klucz (w kodzie `tr("KLUCZ")`) i tekst w każdym języku. `%s` / `%d` to wstawiane
wartości, `%%` to znak procentu.

## Dodawanie tekstu

1. W arkuszu dopisz wiersz: klucz WIELKIMI_LITERAMI i tekst w obu językach.
2. Pobierz do gry: dwuklik `tools/sync_translations.bat` albo `python tools/sync_sheets.py --translations`
   (`--dry-run` pokazuje tylko, co się zmieni). `tools/sync_sheets.bat` bez opcji pobiera dane i tłumaczenia.
3. Godot zaimportuje plik sam po powrocie do edytora (bez edytora: `godot --headless --path . --import`).

Skrypt wypisuje klucze bez tłumaczenia w którymś języku (`WARNING translations: missing …`) i przerywa
przy powtórzonym kluczu – wtedy nic nie zapisuje.

W arkuszu wolno:
- dodawać puste wiersze jako odstępy między sekcjami (wiersze bez klucza są pomijane),
- dodawać kolumny pomocnicze z nagłówkiem od `_` (np. `_notes` – kontekst dla tłumacza); nie trafiają do gry,
- dodać nowy język kolumną z kodem języka (np. `de`) – wtedy też wpis w `scripts/autoload/settings.gd`
  (`SUPPORTED_LOCALES`, `LOCALE_NAMES`) i plik `translations.<kod>.translation` w `project.godot`.

Tekst zaczynający się od `+`, `-`, `=` albo cyfry, a także ze spacją na początku lub końcu (np. `" or "`),
wpisuj w arkuszu z apostrofem na początku (`'+ or`), żeby Sheets nie zamienił go na formułę lub liczbę.

## Karty zagrań

Nazwy i opisy kart (`data/plays/plays.json`) mają klucze `PLAY_CARD_<ID>_NAME` i `PLAY_CARD_<ID>_DESC`
(`<ID>` = id karty wielkimi literami, np. `PLAY_CARD_LONG_BALL_NAME`). Ekran meczu pokazuje tłumaczenie,
a gdy klucza nie ma – nazwę i opis wpisane w Edytorze zagrań (tekst roboczy). Nowa karta z edytora działa więc
od razu; tłumaczenie dopisz w arkuszu, gdy karta jest gotowa. Edytor zawsze pokazuje tekst roboczy.
