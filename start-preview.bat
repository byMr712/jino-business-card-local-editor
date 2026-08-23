<# :
@echo off
rem ==============================================================
rem  Jino business card local editor - preview launcher
rem  URL: http://127.0.0.1:8077/
rem  Server code lives in preview.ps1 (same folder).
rem  Usage:
rem    preview.bat                 - start preview (first run asks for site URL)
rem    preview.bat https://site.ru - re-sync body.txt from site, then start
rem  Details: structure.txt / readme.md
rem ==============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0preview.ps1" %*
exit /b %ERRORLEVEL%
#>
$dir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'preview.ps1') @args
exit $LASTEXITCODE
