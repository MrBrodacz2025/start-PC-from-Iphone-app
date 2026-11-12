@echo off
setlocal
REM Token z pliku token.txt (nie commituj tego pliku) albo ustaw r?cznie poni?ej
if exist "%~dp0\token.txt" (
  set /p PC_TOKEN=<"%~dp0\token.txt"
) else (
  set PC_TOKEN=twoj_tajny_token
)
python -m pip install -r "%~dp0\requirements.txt" --quiet
python "%~dp0\windows_server.py" --port 5000
