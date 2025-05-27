REM Install prerequisites
winget install -e --id Git.Git
winget install -e --id Microsoft.PowerShell

REM Clone the dotfiles repository
mkdir "%USERPROFILE%\Code"
"%PROGRAMFILES%\Git\cmd\git" clone https://github.com/jelledruyts/dotfiles.git "%USERPROFILE%\Code\dotfiles"

@ECHO OFF
ECHO.
ECHO From a new ADMIN PowerShell Core terminal, you can now run the installation script:
ECHO %USERPROFILE%\Code\dotfiles\install.ps1
ECHO.