@echo off
rem ==============================================================
rem  MR712 - deploy home page to website.mr712.ru (WordPress host)
rem  1) site\              -> \\192.168.0.101\wordpress_site\home\
rem  2) mr712-frontpage.php -> ...\wp-content\mu-plugins\
rem  Remove wp-content\mu-plugins\mr712-frontpage.php to revert.
rem  Details: structure.txt / readme.md
rem ==============================================================
robocopy "%~dp0site" "\\192.168.0.101\wordpress_site\home" /MIR /NJH /NJS /NDL /NFL >nul
if %ERRORLEVEL% GEQ 8 (
    echo Deploy FAILED: copy to home
    exit /b 1
)
if not exist "\\192.168.0.101\wordpress_site\wp-content\mu-plugins" mkdir "\\192.168.0.101\wordpress_site\wp-content\mu-plugins"
copy /Y "%~dp0mr712-frontpage.php" "\\192.168.0.101\wordpress_site\wp-content\mu-plugins\mr712-frontpage.php" >nul
if %ERRORLEVEL% NEQ 0 (
    echo Deploy FAILED: mu-plugin copy
    exit /b 1
)
echo Deploy OK: http://website.mr712.ru/
exit /b 0
