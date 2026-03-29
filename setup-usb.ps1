#Requires -Version 5.1
<#
.SYNOPSIS
    Setup script per preparare la chiavetta USB con Claude Code Portable.
    Esegui questo script UNA VOLTA dal tuo PC principale per configurare la chiavetta.

.PARAMETER UsbDrive
    Lettera del drive USB (es. "E", "F")

.PARAMETER NodeVersion
    Versione di Node.js da scaricare (default: 20.11.1)

.EXAMPLE
    .\setup-usb.ps1 -UsbDrive E
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z]$')]
    [string]$UsbDrive,

    [string]$NodeVersion = "20.11.1"
)

$ErrorActionPreference = "Stop"
$UsbRoot = "${UsbDrive}:\"

# --- Progress Bar ---
$totalSteps = 9
$currentStep = 0

function Show-SetupProgress {
    param(
        [int]$Step,
        [string]$Activity,
        [string]$Status = "",
        [int]$PercentWithinStep = -1
    )
    $overallPercent = [math]::Floor(($Step - 1) / $totalSteps * 100)
    if ($PercentWithinStep -ge 0) {
        $stepContribution = [math]::Floor($PercentWithinStep / $totalSteps)
        $overallPercent = [math]::Min($overallPercent + $stepContribution, 100)
    }

    # Barra ASCII visuale
    $barWidth = 40
    $filled = [math]::Floor($overallPercent / 100 * $barWidth)
    $empty = $barWidth - $filled
    $bar = "[" + ("#" * $filled) + ("-" * $empty) + "]"

    # Sovrascrivi la riga di progresso
    $progressLine = "`r  $bar $overallPercent% - Step $Step/$totalSteps"
    if ($Status) { $progressLine += " - $Status" }
    Write-Host $progressLine -NoNewline -ForegroundColor Cyan

    # Write-Progress nativo per terminali che lo supportano
    $progressParams = @{
        Activity = "Wolfix USB Setup"
        Status = "[$Step/$totalSteps] $Activity"
        PercentComplete = $overallPercent
    }
    if ($Status) { $progressParams["CurrentOperation"] = $Status }
    Write-Progress @progressParams
}

function Complete-Step {
    param([int]$Step, [string]$Activity)
    $overallPercent = [math]::Floor($Step / $totalSteps * 100)
    $barWidth = 40
    $filled = [math]::Floor($overallPercent / 100 * $barWidth)
    $empty = $barWidth - $filled
    $bar = "[" + ("#" * $filled) + ("-" * $empty) + "]"
    Write-Host "`r  $bar $overallPercent% - Step $Step/$totalSteps - Completato!   " -ForegroundColor Green
}

function Invoke-DownloadWithProgress {
    param(
        [string]$Uri,
        [string]$OutFile,
        [int]$Step,
        [string]$Label,
        [int]$MaxRetries = 2
    )
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $webRequest = [System.Net.HttpWebRequest]::Create($Uri)
            $webRequest.Timeout = 120000
            $response = $webRequest.GetResponse()
            $totalBytes = $response.ContentLength
            $stream = $response.GetResponseStream()
            $fileStream = [System.IO.File]::Create($OutFile)
            $buffer = New-Object byte[] 65536
            $downloaded = 0
            $lastUpdate = [DateTime]::Now

            while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fileStream.Write($buffer, 0, $bytesRead)
                $downloaded += $bytesRead
                $now = [DateTime]::Now
                if (($now - $lastUpdate).TotalMilliseconds -ge 200) {
                    $lastUpdate = $now
                    if ($totalBytes -gt 0) {
                        $dlPercent = [math]::Floor($downloaded / $totalBytes * 100)
                        $dlMB = [math]::Round($downloaded / 1MB, 1)
                        $totalMB = [math]::Round($totalBytes / 1MB, 1)
                        Show-SetupProgress -Step $Step -Activity $Label -Status "${dlMB}MB / ${totalMB}MB ($dlPercent%)" -PercentWithinStep $dlPercent
                    }
                }
            }
            $fileStream.Close()
            $stream.Close()
            $response.Close()
            return
        } catch {
            if ($i -eq $MaxRetries) { throw }
            Write-Host ""
            Write-Host "  [RETRY] Tentativo $i fallito, riprovo..." -ForegroundColor Yellow
        }
    }
}

# --- Validazione ---
if (-not (Test-Path $UsbRoot)) {
    Write-Error "Drive ${UsbDrive}: non trovato. Inserisci la chiavetta USB."
    exit 1
}

$freeSpace = (Get-PSDrive $UsbDrive).Free
$requiredSpace = 800MB
if ($freeSpace -lt $requiredSpace) {
    Write-Error "Spazio insufficiente. Servono almeno 800MB liberi. Disponibili: $([math]::Round($freeSpace / 1MB))MB"
    exit 1
}

Write-Host ""
Write-Host "  +============================================+" -ForegroundColor Green
Write-Host "  |   WOLFIX USB SETUP                        |" -ForegroundColor Green
Write-Host "  |   Claude Code Portable Installer           |" -ForegroundColor Green
Write-Host "  +============================================+" -ForegroundColor Green
Write-Host ""
Write-Host "  Drive USB: ${UsbDrive}:   Node.js: $NodeVersion" -ForegroundColor Yellow
Write-Host ""

# --- Creazione struttura directory ---
$currentStep = 1
Show-SetupProgress -Step $currentStep -Activity "Creazione directory" -Status "Preparazione struttura..."
Write-Host ""
Write-Host "  [1/9] Creazione struttura directory..." -ForegroundColor Green

$directories = @(
    "runtime\node-win-x64",
    "runtime\node-linux-x64",
    "runtime\node-darwin-x64",
    "runtime\node-darwin-arm64",
    "runtime\git-win-x64",
    "claude-code",
    "config",
    "config\rules",
    "toolkit\prompts",
    "toolkit\scripts",
    "toolkit\logs"
)

foreach ($dir in $directories) {
    $fullPath = Join-Path $UsbRoot $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    }
}
Complete-Step -Step $currentStep -Activity "Creazione directory"

# --- Download Node.js Windows ---
$currentStep = 2
Show-SetupProgress -Step $currentStep -Activity "Node.js Windows" -Status "Avvio download..."
Write-Host ""
Write-Host "  [2/9] Download Node.js $NodeVersion per Windows x64..." -ForegroundColor Green

$nodeWinZip = Join-Path $env:TEMP "node-win-x64.zip"
$nodeWinUrl = "https://nodejs.org/dist/v${NodeVersion}/node-v${NodeVersion}-win-x64.zip"
$nodeWinDest = Join-Path $UsbRoot "runtime\node-win-x64"

if (-not (Test-Path (Join-Path $nodeWinDest "node.exe"))) {
    Invoke-DownloadWithProgress -Uri $nodeWinUrl -OutFile $nodeWinZip -Step $currentStep -Label "Node.js Windows"
    Write-Host ""
    Show-SetupProgress -Step $currentStep -Activity "Node.js Windows" -Status "Estrazione..." -PercentWithinStep 80
    Write-Host ""
    Expand-Archive -Path $nodeWinZip -DestinationPath (Join-Path $env:TEMP "node-win-extract") -Force
    $extractedDir = Get-ChildItem (Join-Path $env:TEMP "node-win-extract") | Select-Object -First 1
    Copy-Item -Path "$($extractedDir.FullName)\*" -Destination $nodeWinDest -Recurse -Force
    Remove-Item $nodeWinZip -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:TEMP "node-win-extract") -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  Gia' presente, skip." -ForegroundColor Yellow
}
Complete-Step -Step $currentStep -Activity "Node.js Windows"

# --- Download Node.js Linux ---
$currentStep = 3
Show-SetupProgress -Step $currentStep -Activity "Node.js Linux" -Status "Avvio download..."
Write-Host ""
Write-Host "  [3/9] Download Node.js $NodeVersion per Linux x64..." -ForegroundColor Green

$nodeLinuxTar = Join-Path $env:TEMP "node-linux-x64.tar.xz"
$nodeLinuxUrl = "https://nodejs.org/dist/v${NodeVersion}/node-v${NodeVersion}-linux-x64.tar.xz"
$nodeLinuxDest = Join-Path $UsbRoot "runtime\node-linux-x64"

if (-not (Test-Path (Join-Path $nodeLinuxDest "bin"))) {
    Invoke-DownloadWithProgress -Uri $nodeLinuxUrl -OutFile $nodeLinuxTar -Step $currentStep -Label "Node.js Linux"
    Write-Host ""
    Write-Host "  NOTA: Estrai manualmente il .tar.xz su Linux con:"
    Write-Host "    tar -xf node-linux-x64.tar.xz -C /path/to/usb/runtime/node-linux-x64 --strip-components=1" -ForegroundColor Yellow
    Copy-Item $nodeLinuxTar -Destination $nodeLinuxDest -Force
    Remove-Item $nodeLinuxTar -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  Gia' presente, skip." -ForegroundColor Yellow
}
Complete-Step -Step $currentStep -Activity "Node.js Linux"

# --- Download Node.js macOS x64 ---
$currentStep = 4
Show-SetupProgress -Step $currentStep -Activity "Node.js macOS x64" -Status "Avvio download..."
Write-Host ""
Write-Host "  [4/9] Download Node.js $NodeVersion per macOS x64..." -ForegroundColor Green

$nodeMacX64Tar = Join-Path $env:TEMP "node-mac-x64.tar.gz"
$nodeMacX64Url = "https://nodejs.org/dist/v${NodeVersion}/node-v${NodeVersion}-darwin-x64.tar.gz"
$nodeMacX64Dest = Join-Path $UsbRoot "runtime\node-darwin-x64"

if (-not (Test-Path (Join-Path $nodeMacX64Dest "bin"))) {
    Invoke-DownloadWithProgress -Uri $nodeMacX64Url -OutFile $nodeMacX64Tar -Step $currentStep -Label "Node.js macOS x64"
    Write-Host ""
    Copy-Item $nodeMacX64Tar -Destination $nodeMacX64Dest -Force
    Remove-Item $nodeMacX64Tar -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  Gia' presente, skip." -ForegroundColor Yellow
}
Complete-Step -Step $currentStep -Activity "Node.js macOS x64"

# --- Download Node.js macOS ARM64 ---
$currentStep = 5
Show-SetupProgress -Step $currentStep -Activity "Node.js macOS ARM64" -Status "Avvio download..."
Write-Host ""
Write-Host "  [5/9] Download Node.js $NodeVersion per macOS ARM64..." -ForegroundColor Green

$nodeMacArm64Tar = Join-Path $env:TEMP "node-mac-arm64.tar.gz"
$nodeMacArm64Url = "https://nodejs.org/dist/v${NodeVersion}/node-v${NodeVersion}-darwin-arm64.tar.gz"
$nodeMacArm64Dest = Join-Path $UsbRoot "runtime\node-darwin-arm64"

if (-not (Test-Path (Join-Path $nodeMacArm64Dest "bin"))) {
    Invoke-DownloadWithProgress -Uri $nodeMacArm64Url -OutFile $nodeMacArm64Tar -Step $currentStep -Label "Node.js macOS ARM64"
    Write-Host ""
    Copy-Item $nodeMacArm64Tar -Destination $nodeMacArm64Dest -Force
    Remove-Item $nodeMacArm64Tar -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  Gia' presente, skip." -ForegroundColor Yellow
}
Complete-Step -Step $currentStep -Activity "Node.js macOS ARM64"

# --- Download Git Portable per Windows ---
$currentStep = 6
Show-SetupProgress -Step $currentStep -Activity "Git Portable" -Status "Avvio download..."
Write-Host ""
Write-Host "  [6/9] Download Git Portable per Windows..." -ForegroundColor Green

$gitVersion = "2.47.1"
$gitPortableUrl = "https://github.com/git-for-windows/git/releases/download/v${gitVersion}.windows.1/PortableGit-${gitVersion}-64-bit.7z.exe"
$gitDest = Join-Path $UsbRoot "runtime\git-win-x64"

if (-not (Test-Path (Join-Path $gitDest "bin\bash.exe"))) {
    $gitInstaller = Join-Path $env:TEMP "PortableGit.exe"
    Invoke-DownloadWithProgress -Uri $gitPortableUrl -OutFile $gitInstaller -Step $currentStep -Label "Git Portable" -MaxRetries 2
    Write-Host ""
    # Estrai prima in locale (exFAT non supporta estrazione diretta)
    $gitTempDir = Join-Path $env:TEMP "git-portable-extract"
    Show-SetupProgress -Step $currentStep -Activity "Git Portable" -Status "Estrazione in locale..." -PercentWithinStep 60
    Write-Host ""
    if (Test-Path $gitTempDir) { Remove-Item $gitTempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $gitTempDir -Force | Out-Null
    & $gitInstaller -o"$gitTempDir" -y 2>&1 | Out-Null
    Show-SetupProgress -Step $currentStep -Activity "Git Portable" -Status "Copia su USB..." -PercentWithinStep 80
    Write-Host ""
    if (-not (Test-Path $gitDest)) { New-Item -ItemType Directory -Path $gitDest -Force | Out-Null }
    & robocopy $gitTempDir $gitDest /E /NFL /NDL /NP 2>&1 | Out-Null
    Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
    Remove-Item $gitTempDir -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  Gia' presente, skip." -ForegroundColor Yellow
}
Complete-Step -Step $currentStep -Activity "Git Portable"

# --- Installazione Claude Code ---
$currentStep = 7
Show-SetupProgress -Step $currentStep -Activity "Claude Code" -Status "Installazione npm..."
Write-Host ""
Write-Host "  [7/9] Installazione Claude Code..." -ForegroundColor Green

$nodePath = Join-Path $UsbRoot "runtime\node-win-x64\node.exe"
$npmPath = Join-Path $UsbRoot "runtime\node-win-x64\npm.cmd"
$claudeCodeDir = Join-Path $UsbRoot "claude-code"
$claudeTempDir = Join-Path $env:TEMP "claude-code-install"

$env:PATH = "$(Join-Path $UsbRoot 'runtime\node-win-x64');$env:PATH"

# Installa prima in locale (exFAT corrompe npm install diretto)
Show-SetupProgress -Step $currentStep -Activity "Claude Code" -Status "npm install (attendere qualche minuto)..." -PercentWithinStep 10
Write-Host ""
if (Test-Path $claudeTempDir) { Remove-Item $claudeTempDir -Recurse -Force }
& $npmPath install -g @anthropic-ai/claude-code --prefix $claudeTempDir 2>&1 | ForEach-Object {
    if ($_ -match "added|updated|claude") { Write-Host "  $_" -ForegroundColor Gray }
}

# Copia sulla chiavetta con robocopy (affidabile su exFAT)
Show-SetupProgress -Step $currentStep -Activity "Claude Code" -Status "Copia su USB..." -PercentWithinStep 70
Write-Host ""
& robocopy $claudeTempDir $claudeCodeDir /E /NFL /NDL /NP /IS /IT 2>&1 | Out-Null
Remove-Item $claudeTempDir -Recurse -Force -ErrorAction SilentlyContinue
Complete-Step -Step $currentStep -Activity "Claude Code"

# --- Login Claude ---
$currentStep = 8
Show-SetupProgress -Step $currentStep -Activity "Autenticazione" -Status "Login..."
Write-Host ""
Write-Host "  [8/9] Configurazione autenticazione..." -ForegroundColor Green

$env:CLAUDE_CONFIG_DIR = Join-Path $UsbRoot "config"
$claudeBin = Join-Path $claudeCodeDir "bin\claude.cmd"

if (Test-Path $claudeBin) {
    Write-Host "  Avvio login... Segui le istruzioni nel browser." -ForegroundColor Yellow
    & $claudeBin login
} else {
    Write-Host "  ATTENZIONE: claude.cmd non trovato in $claudeBin" -ForegroundColor Red
    Write-Host "  Esegui il login manualmente dopo il setup." -ForegroundColor Yellow
}
Complete-Step -Step $currentStep -Activity "Autenticazione"

# --- Copia launcher e toolkit ---
$currentStep = 9
Show-SetupProgress -Step $currentStep -Activity "Launcher e toolkit" -Status "Copia file..."
Write-Host ""
Write-Host "  [9/9] Copia launcher e toolkit sulla chiavetta..." -ForegroundColor Green

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$filesToCopy = @(
    "launch.bat",
    "launch.ps1",
    "launch.sh",
    "wolfix-eject.ps1",
    "toolkit\prompts\windows-health.md",
    "toolkit\prompts\linux-health.md",
    "toolkit\prompts\esxi-health.md",
    "toolkit\prompts\vmware-health.md",
    "toolkit\prompts\server-2008-2012.md",
    "toolkit\scripts\collect-win.ps1",
    "toolkit\scripts\collect-linux.sh",
    "toolkit\scripts\collect-esxi.sh",
    "toolkit\prompts\macos-health.md",
    "toolkit\scripts\collect-macos.sh",
    "toolkit\scripts\log-session.ps1",
    "VERSION",
    "README.md"
)

foreach ($file in $filesToCopy) {
    $source = Join-Path $scriptDir $file
    $dest = Join-Path $UsbRoot $file
    if (Test-Path $source) {
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item $source $dest -Force
        Write-Host "  Copiato: $file" -ForegroundColor Gray
    }
}
Complete-Step -Step $currentStep -Activity "Launcher e toolkit"

# --- Generate SHA256SUMS ---
Write-Host "  Generating SHA256SUMS..." -ForegroundColor Gray
$hashFiles = @("launch.bat", "launch.sh", "launch.ps1", "wolfix-eject.ps1")
$hashLines = @()
foreach ($hf in $hashFiles) {
    $hfPath = Join-Path $UsbRoot $hf
    if (Test-Path $hfPath) {
        $hash = (Get-FileHash -Path $hfPath -Algorithm SHA256).Hash.ToLower()
        $hashLines += "$hash  $hf"
    }
}
if ($hashLines.Count -gt 0) {
    $hashLines -join "`n" | Set-Content -Path (Join-Path $UsbRoot "SHA256SUMS") -NoNewline -Encoding UTF8
    Write-Host "  SHA256SUMS generato con $($hashLines.Count) file." -ForegroundColor Gray
}

Write-Progress -Activity "Wolfix USB Setup" -Completed

# --- Riepilogo ---
Write-Host ""
Write-Host "  [########################################] 100% - Setup completato!" -ForegroundColor Green
Write-Host ""
Write-Host "  +============================================+" -ForegroundColor Cyan
Write-Host "  |       SETUP COMPLETATO CON SUCCESSO       |" -ForegroundColor Cyan
Write-Host "  +============================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host "Struttura chiavetta ${UsbDrive}:\" -ForegroundColor Yellow
Write-Host "  runtime\         - Node.js portable (Win + Linux + macOS)"
Write-Host "  runtime\git\     - Git Portable (per Windows senza Git)"
Write-Host "  claude-code\     - Claude Code CLI"
Write-Host "  config\          - Configurazione e credenziali"
Write-Host "  toolkit\         - Prompt diagnostici e script"
Write-Host ""
Write-Host "[NOTE] macOS: tar.gz files will be extracted automatically by launch.sh on first run." -ForegroundColor Gray
Write-Host ""
Write-Host "Per usare la chiavetta:" -ForegroundColor Yellow
Write-Host "  Windows:  Doppio click su launch.bat (o launch.ps1)"
Write-Host "  Linux:    bash launch.sh"
Write-Host "  macOS:    bash launch.sh"
Write-Host ""
Write-Host "IMPORTANTE: La chiavetta contiene le tue credenziali." -ForegroundColor Red
Write-Host "Considera di cifrarla con BitLocker o VeraCrypt." -ForegroundColor Red
