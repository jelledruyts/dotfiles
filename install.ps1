function Assert-Elevated {
    # Get the ID and security principal of the current user account
    $myIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myPrincipal = new-object System.Security.Principal.WindowsPrincipal($myIdentity)
    # Check to see if we are currently running "as Administrator"
    $elevated = $myPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    if (!$elevated) {
        Write-Warning "This script requires elevated permissions: please run as Administrator."
        exit
    }
}

function Read-Prompt {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    $response = Read-Host "$Message (Y/n)"
    return ($response -eq 'y' -or $response -eq 'yes' -or $response -eq '')
}

function Add-SymbolicLink {
    param (
        [Parameter(Mandatory)]
        [string]$SourceFile,
        [Parameter(Mandatory)]
        [string]$TargetFile
    )

    if (Test-Path $TargetFile) {
        Write-Warning "Skipped linking ""$SourceFile"" as target ""$TargetFile"" already exists."
    }
    else {
        # Ensure target directory exists
        $targetDir = Split-Path $TargetFile -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -Path $targetDir -ItemType Directory | Out-Null
        }
        New-Item -Path $TargetFile -ItemType SymbolicLink -Value $SourceFile | Out-Null
        Write-Host "Linked ""$SourceFile)"" -> ""$TargetFile"""
    }
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
        Add-SymbolicLink -SourceFile $_.FullName -TargetFile $linkPath
    }
}

function Install-WingetPackage {
    param (
        [Parameter(Mandatory)]
        [string[]]$Package
    )

    winget install --accept-source-agreements --accept-package-agreements --exact --id $package
}

function Install-WingetPackages {
    param (
        [Parameter(Mandatory)]
        [string[]]$Packages
    )

    foreach ($package in $Packages) {
        if (Read-Prompt -Message "Install ""$package"" package?") {
            Write-Host "Installing ""$package""..."
            Install-WingetPackage -Package $package
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

function Install-NerdFonts {
    param (
        [Parameter(Mandatory)]
        [object[]]$NerdFonts
    )

    if ($NerdFonts.count -gt 0) {
        Write-Host "`nInstalling Nerd Fonts..."
        Add-NerdFonts -NerdFonts $NerdFonts
        # Set the first Nerd Font as the default font for Windows Terminal
        Set-WindowsTerminalFont -FontFace $NerdFonts[0].font
    }

}

function Install-WSL {
    param (
        [Parameter(Mandatory)]
        [object[]]$WSLDistributions
    )

    if ($WSLDistributions.count -gt 0) {
        if (Read-Prompt -Message "Install WSL?") {
            Write-Host "`nInstalling WSL distributions..."
            Install-WingetPackage -Package "Microsoft.WSL"
            foreach ($wslDistribution in $WSLDistributions) {
                Write-Host "Installing WSL distribution ""$wslDistribution""..."
                wsl --install $wslDistribution
            }
        }
    }
}

function Enable-RemoteDesktop {
    if (Read-Prompt -Message "Allow Remote Desktop connections to this device?") {
        Write-Host "Allowing Remote Desktop connections..."

        # Enable Remote Desktop
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1

        # Allow Remote Desktop through Windows Firewall
        Enable-NetFirewallRule -Group "@FirewallAPI.dll,-28752" # This is the language-independent group identifier of DisplayGroup "Remote Desktop"

        # Log in locally with the account password at least once to ensure Remote Desktop will work
        $msa = Read-Host "Enter your Microsoft Account email address (or leave empty to skip)"
        runas /u:MicrosoftAccount\$msa "cmd"
    }
}

Assert-Elevated

Write-Host "Reading configuration..."
$config = Get-Content "$PSScriptRoot/config.jsonc" | ConvertFrom-Json -AsHashtable

Write-Host "`nCreating symbolic links..."
Add-SymbolicLinksRecursive -SourceDir "$PSScriptRoot/files/home" -TargetDir $HOME
Add-SymbolicLink -SourceFile "$PSScriptRoot/files/powershell-profile.ps1" -TargetFile $PROFILE.CurrentUserAllHosts

Write-Host "`nInstalling winget packages..."
Install-WingetPackageCollections -PackageCollections $config.winget

Write-Host "`nAdding startup apps..."
Add-StartupApps -StartupApps $config.startup

Write-Host "`nInstalling PowerShell modules..."
Add-PowerShellModules -PowerShellModules $config.powershell

Install-NerdFonts -NerdFonts $config.nerdfonts

Install-WSL -WSLDistributions $config.wsl

Enable-RemoteDesktop

Write-Host "`nInstallation complete!`n"