function Read-Prompt {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    $response = Read-Host "$Message (Y/n)"
    return ($response -eq 'y' -or $response -eq 'yes' -or $response -eq '')
}

function Add-SymbolicLinksRecursive {
    param (
        [Parameter(Mandatory)]
        [string]$SourceDir,
        [Parameter(Mandatory)]
        [string]$TargetDir
    )

    # Ensure target directory exists
    if (-not (Test-Path $TargetDir)) {
        New-Item -Path $TargetDir -ItemType Directory | Out-Null
    }

    Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
        $linkPath = Join-Path $TargetDir $relativePath
        $linkDir = Split-Path $linkPath

        if (-not (Test-Path $linkDir)) {
            New-Item -Path $linkDir -ItemType Directory -Force | Out-Null
        }

        if (Test-Path $linkPath) {
            Write-Warning "Skipped linking ""$($_.FullName)"" as target ""$linkPath"" already exists."
        }
        else {
            New-Item -Path $linkPath -ItemType SymbolicLink -Value $_.FullName | Out-Null
            Write-Host "Linked ""$($_.FullName)"" -> ""$linkPath"""
        }
    }
}

function Install-WingetPackages {
    param (
        [Parameter(Mandatory)]
        [string[]]$Packages
    )

    foreach ($package in $Packages) {
        if (Read-Prompt -Message "Install ""$package"" package?") {
            Write-Host "Installing ""$package""..."
            winget install --exact --accept-package-agreements --id $package
        }
    }
}

function Install-WingetPackageCollections {
    param (
        [Parameter(Mandatory)]
        [object[]]$PackageCollections
    )

    foreach ($packageCollection in $PackageCollections) {
        if (Read-Prompt -Message "Install ""$($packageCollection.name)"" packages?") {
            Install-WingetPackages -Packages $packageCollection.packages
        }
    }
}

function Add-StartupShortcut {
    param (
        [Parameter(Mandatory)]
        [string]$ExecutablePath,
        [string]$ShortcutName
    )

    if (-not (Test-Path $ExecutablePath)) {
        Write-Warning "Executable path ""$ExecutablePath"" does not exist. Skipping shortcut creation."
        return
    }

    if (-not $ShortcutName) {
        $ShortcutName = $(Split-Path $ExecutablePath -Leaf)
    }

    $startupFolder = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupFolder "$ShortcutName.lnk"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $ExecutablePath
    $shortcut.WorkingDirectory = Split-Path $ExecutablePath
    $shortcut.Save()

    Write-Host "Startup app created at ""$shortcutPath"" for ""$ExecutablePath"""
}

function Add-StartupApps {
    param (
        [Parameter(Mandatory)]
        [object[]]$StartupApps
    )

    foreach ($startupApp in $StartupApps) {
        $executablePath = $startupApp.command.replace('~', $HOME)
        Add-StartupShortcut -ExecutablePath $executablePath -ShortcutName $startupApp.name
    }
}

function Add-PowerShellModules {
    param (
        [Parameter(Mandatory)]
        [object[]]$PowerShellModules
    )

    Set-PSResourceRepository -Name "PSGallery" -Trusted

    foreach ($powerShellModule in $PowerShellModules) {
        Write-Host "Adding ""$powerShellModule""..."
        Install-PSResource -Name $powerShellModule -AcceptLicense
        Import-Module -Name $powerShellModule
    }
}

function Add-NerdFonts {
    param (
        [Parameter(Mandatory)]
        [object[]]$NerdFonts
    )

    Install-PSResource -Name NerdFonts
    Import-Module -Name NerdFonts

    foreach ($nerdFont in $NerdFonts) {
        Write-Host "Adding ""$nerdFont""..."
        Install-NerdFont -Name $nerdFont.name
    }
}

function Set-WindowsTerminalFont {
    param (
        [Parameter(Mandatory)]
        [string]$FontFace
    )

    $settingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $settingsPath)) {
        Write-Warning "Windows Terminal settings.json not found at ""$settingsPath""."
        return
    }

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable

    if (-not $settings.profiles.defaults) {
        $settings.profiles.defaults = @{}
    }

    if (-not $settings.profiles.defaults.font) {
        $settings.profiles.defaults.font = @{}
    }

    $settings.profiles.defaults.font.face = $FontFace

    $settings | ConvertTo-Json -Depth 100 | Set-Content -Path $settingsPath -Encoding UTF8

    Write-Host "Set Windows Terminal default profile font to ""$FontFace""."
}

Write-Host "Reading configuration..."
$config = Get-Content "$PSScriptRoot/config.jsonc" | ConvertFrom-Json -AsHashtable

Write-Host "`nCreating symbolic links..."
Add-SymbolicLinksRecursive -SourceDir "$PSScriptRoot/home" -TargetDir $HOME

Write-Host "`nInstalling winget packages..."
Install-WingetPackageCollections -PackageCollections $config.winget

Write-Host "`nAdding startup apps..."
Add-StartupApps -StartupApps $config.startup

Write-Host "`nInstalling PowerShell modules..."
Add-PowerShellModules -PowerShellModules $config.powershell

if ($config.nerdfonts.count -gt 0) {
    Write-Host "`nInstalling Nerd Fonts..."
    Add-NerdFonts -NerdFonts $config.nerdfonts
    Set-WindowsTerminalFont -FontFace $config.nerdfonts[0].font
}