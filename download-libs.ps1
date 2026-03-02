$ErrorActionPreference = "Stop"

Write-Host "Downloading Roblox libraries..."

# Create Packages directory if it doesn't exist
if (-not (Test-Path "Packages")) {
    mkdir Packages | Out-Null
}

# Function to download and extract GitHub repo
function DownloadGitHub {
    param(
        [string]$RepoUrl,
        [string]$FolderName,
        [string]$SourcePath = ""
    )
    
    $zipPath = "$FolderName.zip"
    $extractPath = "$FolderName-temp"
    
    Write-Host "Downloading $FolderName..."
    
    try {
        # Download the repo as zip
        $downloadUrl = "$RepoUrl/archive/refs/heads/main.zip"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction SilentlyContinue
        
        if (-not (Test-Path $zipPath)) {
            # Try master branch if main doesn't exist
            $downloadUrl = "$RepoUrl/archive/refs/heads/master.zip"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
        }
        
        # Extract zip
        Expand-Archive $zipPath -DestinationPath $extractPath -Force
        
        # Find the extracted folder
        $extracted = (Get-ChildItem $extractPath -Directory)[0]
        
        if ([string]::IsNullOrEmpty($SourcePath)) {
            $sourcePath = $extracted.FullName
        } else {
            $sourcePath = Join-Path $extracted.FullName $SourcePath
        }
        
        # Copy to Packages
        if (Test-Path "Packages/$FolderName") {
            Remove-Item "Packages/$FolderName" -Recurse -Force
        }
        Copy-Item $sourcePath -Destination "Packages/$FolderName" -Recurse
        
        # Cleanup
        Remove-Item $zipPath -Force
        Remove-Item $extractPath -Recurse -Force
        
        Write-Host "✓ $FolderName downloaded successfully"
    }
    catch {
        Write-Host "✗ Failed to download $FolderName"
        Write-Host $_
    }
}

# Download all libraries
DownloadGitHub "https://github.com/Sleitnick/Knit" "Knit"
DownloadGitHub "https://github.com/evaera/roblox-lua-promise" "Promise" "modules/promise"
DownloadGitHub "https://github.com/Sleitnick/RbxUtil" "Signal" "modules/signal"
DownloadGitHub "https://github.com/MadStudioRoblox/ProfileService" "ProfileService"
DownloadGitHub "https://github.com/Roblox/roact" "Roact"
DownloadGitHub "https://github.com/SirMallard/Iris" "Iris"

Write-Host "All libraries downloaded to Packages folder!"
