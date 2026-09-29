[CmdletBinding()]
param(
    [string]$Repository = '',

    [ValidateSet('private', 'public')]
    [string]$Visibility = 'private'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = Join-Path $projectRoot 'build'
$artifactName = 'AirCard-iOS-26.4-unsigned'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Require-Command([string]$Name, [string]$InstallHint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required. $InstallHint"
    }
}

Require-Command 'git' 'Install Git for Windows first.'

# GitHub CLI's MSI updates PATH for new terminals only. Make the common install
# locations available immediately so the same PowerShell window can continue.
if (-not (Get-Command 'gh' -ErrorAction SilentlyContinue)) {
    $ghCandidates = @(
        'C:\Program Files\GitHub CLI\gh.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\GitHub CLI\gh.exe')
    )
    $ghFound = $ghCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($ghFound) {
        $env:Path = "$(Split-Path -Parent $ghFound);$env:Path"
    }
}
Require-Command 'gh' 'Install it with: winget install --id GitHub.cli'

Push-Location $projectRoot
try {
    gh auth status 2>$null | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'GitHub login is required. Starting gh auth login...' -ForegroundColor Yellow
        gh auth login
        if ($LASTEXITCODE -ne 0) {
            throw 'GitHub login did not complete successfully.'
        }
    }

    if ([string]::IsNullOrWhiteSpace($Repository)) {
        $owner = gh api user --jq '.login'
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($owner)) {
            throw 'Could not determine the signed-in GitHub username.'
        }
        $Repository = "$owner/AirCard-iOS-26.4-private"
        Write-Host "Using private repository: $Repository" -ForegroundColor Cyan
    }
    if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw "Repository must use OWNER/REPOSITORY format with the real GitHub username. Received: $Repository"
    }

    # The workspace may be mounted under a different Windows SID. Trust only
    # this exact project directory, never the parent workspace or a wildcard.
    $gitSafePath = [System.IO.Path]::GetFullPath($projectRoot).Replace('\', '/')
    $safeDirectories = @(git config --global --get-all safe.directory 2>$null)
    if ($safeDirectories -notcontains $gitSafePath) {
        git config --global --add safe.directory $gitSafePath
        if ($LASTEXITCODE -ne 0) {
            throw "Could not add the project to Git safe.directory: $gitSafePath"
        }
        Write-Host "Added Git safe.directory: $gitSafePath" -ForegroundColor Cyan
    }

    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.git'))) {
        git init -b main
    }

    # Complete the first commit if a previous run stopped immediately after
    # git init, and commit any later workflow/source updates before pushing.
    git add .
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m 'Build AirCard-iOS 26.4 experimental IPA'
        if ($LASTEXITCODE -ne 0) {
            throw 'Git could not create the source commit. Configure git user.name and user.email, then retry.'
        }
    }

    $remote = git remote get-url origin 2>$null
    if (-not $remote) {
        gh repo view $Repository --json nameWithOwner 1>$null 2>$null
        if ($LASTEXITCODE -eq 0) {
            $remoteUrl = "https://github.com/$Repository.git"
            git remote add origin $remoteUrl
            Write-Host "Using existing GitHub repository: $remoteUrl" -ForegroundColor Cyan
            git push -u origin HEAD
        } else {
            $visibilitySwitch = if ($Visibility -eq 'public') { '--public' } else { '--private' }
            gh repo create $Repository $visibilitySwitch --source . --remote origin --push
        }
    } else {
        $expectedRemote = "github.com/$Repository"
        if ($remote -notlike "*$expectedRemote*") {
            throw "Existing origin points to '$remote', not '$Repository'. Remove or correct origin before retrying."
        }
        git push -u origin HEAD
    }

    gh workflow run build-ipa.yml --repo $Repository
    Start-Sleep -Seconds 3
    $runId = gh run list --repo $Repository --workflow build-ipa.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'
    if (-not $runId) {
        throw 'GitHub did not return a workflow run ID.'
    }

    gh run watch $runId --repo $Repository --exit-status

    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    gh run download $runId --repo $Repository --name $artifactName --dir $outputDir

    $ipa = Join-Path $outputDir 'AirCard-iOS.ipa'
    $checksumFile = Join-Path $outputDir 'AirCard-iOS.ipa.sha256'
    if (-not (Test-Path -LiteralPath $ipa)) {
        throw "Build completed but $ipa was not downloaded."
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ipa).Hash.ToLowerInvariant()
    $expectedHash = ((Get-Content -LiteralPath $checksumFile -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "IPA checksum mismatch. Expected $expectedHash, got $actualHash."
    }

    Write-Host "IPA ready: $ipa" -ForegroundColor Green
    Write-Host "SHA-256: $actualHash"
} finally {
    Pop-Location
}
