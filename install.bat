@echo off
rem Install the speckit-cobol-harness into a target repo. Usage: install.bat [C:\path\to\repo]
setlocal
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=."
set "SRC=%~dp0payload"
if not exist "%TARGET%\scripts" mkdir "%TARGET%\scripts"
if not exist "%TARGET%\eval\crs" mkdir "%TARGET%\eval\crs"
if not exist "%TARGET%\eval\runs" mkdir "%TARGET%\eval\runs"
copy /Y "%SRC%\scripts\extract_structure.py" "%TARGET%\scripts\" >nul
copy /Y "%SRC%\scripts\fill_prose.py" "%TARGET%\scripts\" >nul
copy /Y "%SRC%\eval\cr-template.md" "%TARGET%\eval\" >nul
copy /Y "%SRC%\eval\rubric.md" "%TARGET%\eval\" >nul
if not exist "%TARGET%\eval\runsheet.csv" copy "%SRC%\eval\runsheet.csv" "%TARGET%\eval\" >nul
findstr /B /C:"## COBOL context" "%TARGET%\CLAUDE.md" >nul 2>&1
if %errorlevel%==0 (
  echo CLAUDE.md block already present - skipped
) else (
  if exist "%TARGET%\CLAUDE.md" echo.>>"%TARGET%\CLAUDE.md"
  type "%SRC%\CLAUDE-block.md" >> "%TARGET%\CLAUDE.md"
  echo Appended COBOL context block to CLAUDE.md
)
echo Installed harness into: %TARGET%
echo Next: see README.md ^(generate context -^> fill prose -^> spec-kit init -^> run CRs -^> score^)
endlocal
