@echo off
setlocal enabledelayedexpansion

set "FILE=modules\services\scritch.nix"
set "LINE=12"

:: Extract current Noop number using powershell
for /f %%n in ('powershell -Command "((Get-Content '%FILE%')[%LINE%-1] | Select-String 'Noop (\d+)').Matches.Groups[1].Value"') do set "CURRENT=%%n"

set /a NEXT=%CURRENT%+1

echo Bumping Noop %CURRENT% -^> %NEXT%

:: Replace in file
powershell -Command "$content = (Get-Content '%FILE%') | ForEach-Object { if ($_.ReadCount -eq %LINE%) { $_ -replace 'Noop %CURRENT%', 'Noop %NEXT%' } else { $_ } }; [System.IO.File]::WriteAllLines('%FILE%', $content)"

git add .
git commit --amend --no-edit
git push -f

for /f %%h in ('git rev-parse HEAD') do set "HASH=%%h"
set "CMD=sudo nixos-rebuild switch --impure --flake github:CirrusNeptune/nixos-a/%HASH%"
echo %CMD%
echo %CMD% | clip
