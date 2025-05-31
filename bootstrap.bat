REM Install prerequisites
winget install -e --id Git.Git
winget install -e --id Microsoft.PowerShell

REM Clone the dotfiles repository
mkdir "%USERPROFILE%\Local\Code"
"%PROGRAMFILES%\Git\cmd\git" clone https://github.com/jelledruyts/dotfiles.git "%USERPROFILE%\Local\Code\dotfiles"

@ECHO OFF
ECHO.
ECHO From a new ADMIN PowerShell Core terminal, you can now run the installation script:
ECHO %USERPROFILE%\Local\Code\dotfiles\install.ps1
ECHO.