@echo off
rem Pobiera tlumaczenia z Google Sheets do localization\translations.csv
python "%~dp0sync_sheets.py" --translations %*
pause
