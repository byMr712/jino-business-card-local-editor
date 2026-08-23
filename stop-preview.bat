@echo off
rem ==============================================================
rem  Jino business card local editor - stops the preview server
rem  Finds PowerShell processes running preview.ps1 and kills them
rem  Details: structure.txt / readme.md
rem ==============================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'preview\.ps1' }); if ($p.Count) { $p | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Write-Host ('Preview stopped (' + $p.Count + ' process(es)).') } else { Write-Host 'Preview is not running.' }"
exit /b %ERRORLEVEL%
