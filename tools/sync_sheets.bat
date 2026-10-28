@echo off
rem Pobiera dane gry z Google Sheets do folderu data\
python "%~dp0sync_sheets.py" %*
pause
