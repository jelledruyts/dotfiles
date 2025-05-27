$WingetPackageCollections = @(
    @{
        Name     = "Core"
        Packages = @('7zip.7zip', 'Microsoft.Office')
    },
    @{
        Name     = "Development"
        Packages = @('Microsoft.VisualStudioCode', 'Microsoft.DotNet.SDK.8', 'Microsoft.AzureCLI', 'Telerik.Fiddler.Classic', 'OpenJS.NodeJS.LTS')
    },
    @{
        Name     = "Optional"
        Packages = @('EpicGames.EpicGamesLauncher')
    }
)

function Read-Prompt {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    $response = Read-Host "$Message (Y/n)"
    return ($response -eq 'y' -or $response -eq 'yes' -or $response -eq '')
}

function New-SymbolicLinksRecursive {
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
            winget install -e --id $package
        }
    }
}

function Install-WingetPackageCollection {
    param (
        [Parameter(Mandatory)]
        [hashtable]$PackageCollection
    )

    if (Read-Prompt -Message "Install ""$($PackageCollection.Name)"" packages?") {
        Install-WingetPackages -Packages $PackageCollection.Packages
    }
}

function Install-WingetPackageCollections {
    param (
        [Parameter(Mandatory)]
        [object[]]$PackageCollections
    )

    foreach ($collection in $PackageCollections) {
        Install-WingetPackageCollection -PackageCollection $collection
    }
}

Install-WingetPackageCollections -PackageCollections $WingetPackageCollections

New-SymbolicLinksRecursive -SourceDir "$PSScriptRoot/home" -TargetDir $HOME