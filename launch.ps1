<#
.SYNOPSIS
    Wolfix - AI Diagnostic Toolkit - Launcher PowerShell.
    Offre le stesse funzionalita' di launch.bat con maggiore flessibilita'.

.DESCRIPTION
    Configura l'ambiente temporaneo, rileva il sistema, e lancia Claude Code
    dalla chiavetta USB senza installare nulla sulla macchina target.
#>

param(
    [ValidateSet("diagnosi", "interattivo", "log", "fix", "raccogli", "ssh", "menu")]
    [string]$Modalita = "menu"
)

$ErrorActionPreference = "Continue"
$UsbRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# === CONFIGURAZIONE AMBIENTE ===
$env:PATH = "$UsbRoot\runtime\node-win-x64;$UsbRoot\claude-code\bin;$env:PATH"
$env:NPM_CONFIG_PREFIX = "$UsbRoot\claude-code"
$env:CLAUDE_CONFIG_DIR = "$UsbRoot\config"
$env:NODE_PATH = "$UsbRoot\claude-code\lib\node_modules"

$gitDir = Join-Path $UsbRoot "runtime\git-win-x64"
$gitBash = Join-Path $gitDir "bin\bash.exe"
if (Test-Path $gitBash) {
    $env:CLAUDE_CODE_GIT_BASH_PATH = $gitBash
    $env:PATH = "$gitDir\bin;$gitDir\cmd;$env:PATH"
}

$claudeBin = Join-Path $UsbRoot "claude-code\bin\claude.cmd"
$nodeBin = Join-Path $UsbRoot "runtime\node-win-x64\node.exe"

# === VALIDAZIONE ===
if (-not (Test-Path $nodeBin)) {
    Write-Host "[ERRORE] Node.js non trovato. Esegui setup-usb.ps1 prima." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $claudeBin)) {
    Write-Host "[*] claude.cmd non trovato, tento auto-repair..." -ForegroundColor Yellow
    $tempFiles = Get-ChildItem (Join-Path $UsbRoot "claude-code") -Filter ".claude.cmd-*" -ErrorAction SilentlyContinue
    if ($tempFiles) {
        Copy-Item $tempFiles[0].FullName $claudeBin -Force
        Write-Host "[OK] claude.cmd ripristinato da $($tempFiles[0].Name)" -ForegroundColor Green
    } else {
        Write-Host "[ERRORE] Claude Code non trovato. Esegui setup-usb.ps1 prima." -ForegroundColor Red
        exit 1
    }
}

# === RILEVA SISTEMA ===
$osInfo = Get-CimInstance Win32_OperatingSystem
$cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramGB = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 1)

# === LANGUAGE SELECTION ===
$strings = @{}

function Set-Language {
    param([string]$Lang)
    if ($Lang -eq "en") {
        $script:strings = @{
            M1 = "[1] Full system diagnosis"
            M2 = "[2] Interactive Claude Code"
            M3 = "[3] Analyze log file"
            M4 = "[4] Guided fix (describe problem)"
            M5 = "[5] Collect data for offline analysis"
            M6 = "[6] Connect to remote server (SSH)"
            M7 = "[7] Network diagnosis"
            M8 = "[8] Security analysis"
            M9 = "[9] Safely eject USB"
            M0 = "[0] Exit"
            Choice = "Choice"
            LogPath = "Log file path"
            Problem = "Describe the problem"
            SshHost = "Host (user@ip)"
            DiagStart = "[*] Starting full diagnosis..."
            NetStart = "[*] Starting network diagnosis..."
            SecStart = "[*] Starting security analysis..."
            Collecting = "Collecting system data..."
            Saved = "[OK] Data saved in"
            NotFound = "[ERROR] File not found:"
            Bye = "Goodbye. No traces left on the system."
            EjectSync = "Flushing buffers..."
            EjectOk = "USB safely ejected. You can remove the drive now."
            EjectFail = "Could not eject the USB drive. Close all open files and try again."
        }
    } else {
        $script:strings = @{
            M1 = "[1] Diagnosi completa del sistema"
            M2 = "[2] Claude Code interattivo"
            M3 = "[3] Analizza file di log"
            M4 = "[4] Fix guidato (descrivi problema)"
            M5 = "[5] Raccogli dati per analisi offline"
            M6 = "[6] Connetti a server remoto (SSH)"
            M7 = "[7] Diagnosi rete"
            M8 = "[8] Analisi sicurezza"
            M9 = "[9] Sgancia chiavetta USB"
            M0 = "[0] Esci"
            Choice = "Scelta"
            LogPath = "Percorso del file di log"
            Problem = "Descrivi il problema"
            SshHost = "Host (user@ip)"
            DiagStart = "[*] Avvio diagnosi completa..."
            NetStart = "[*] Avvio diagnosi rete..."
            SecStart = "[*] Avvio analisi sicurezza..."
            Collecting = "Raccolta dati di sistema..."
            Saved = "[OK] Dati salvati in"
            NotFound = "[ERRORE] File non trovato:"
            Bye = "Arrivederci. Nessuna traccia lasciata sul sistema."
            EjectSync = "Scaricamento buffer in corso..."
            EjectOk = "Chiavetta USB sganciata in sicurezza. Puoi rimuoverla."
            EjectFail = "Impossibile sganciare la chiavetta. Chiudi tutti i file aperti e riprova."
        }
    }
}

function Show-Banner {
    Write-Host ""
    Write-Host "  â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—" -ForegroundColor Cyan
    Write-Host "  â•’            W O L F I X                    â•’" -ForegroundColor Cyan
    Write-Host "  ║       >_ AI Problem Solver                ║" -ForegroundColor Cyan
    Write-Host "  ║         with Claude Code                  ║" -ForegroundColor Cyan
    Write-Host "  â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Sistema: $($osInfo.Caption)" -ForegroundColor Gray
    Write-Host "  CPU:     $($cpuInfo.Name)" -ForegroundColor Gray
    Write-Host "  RAM:     ${ramGB} GB" -ForegroundColor Gray
    Write-Host "  Host:    $($env:COMPUTERNAME)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [I] Italiano  [E] English" -ForegroundColor White
    $langChoice = Read-Host "`n  Language / Lingua"
    if ($langChoice -eq "E" -or $langChoice -eq "e") { Set-Language "en" } else { Set-Language "it" }
    Write-Host ""
}

function Show-Menu {
    Write-Host "  ┌─────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M1.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M2.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M3.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M4.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M5.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M6.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M7.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M8.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M9.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host ("  │  " + $strings.M0.PadRight(37) + "│") -ForegroundColor Yellow
    Write-Host "  └─────────────────────────────────────────┘" -ForegroundColor Yellow
}

function Invoke-Claude {
    param([string]$Prompt)
    & $claudeBin -p $Prompt
}

function Start-Diagnosi {
    Write-Host $strings.DiagStart -ForegroundColor Green
    $prompt = @"
Sei un esperto di diagnostica sistemi Windows. Questo sistema e':
- OS: $($osInfo.Caption)
- Versione: $($osInfo.Version)
- RAM: ${ramGB} GB
- Hostname: $($env:COMPUTERNAME)

Esegui una diagnosi completa:
1. Controlla servizi critici (stato e startup type)
2. Verifica spazio disco su tutti i volumi
3. Analizza utilizzo RAM e CPU
4. Cerca errori critici nell'Event Log (ultimi 24h)
5. Verifica stato rete (interfacce, DNS, gateway)
6. Controlla aggiornamenti Windows pendenti
7. Verifica stato antivirus/firewall
8. Controlla task schedulati falliti

Per ogni problema trovato:
- Spiega l'impatto
- Proponi il fix
- Chiedi conferma PRIMA di eseguirlo
- Dopo il fix, verifica che funziona
"@
    Invoke-Claude $prompt
}

function Start-AnalisiLog {
    $logPath = Read-Host $strings.LogPath
    if (-not (Test-Path $logPath)) {
        Write-Host "$($strings.NotFound) $logPath" -ForegroundColor Red
        return
    }
    Invoke-Claude "Analizza il file di log '$logPath'. Identifica errori, warning, pattern anomali. Fornisci un riepilogo strutturato dei problemi e suggerisci soluzioni concrete."
}

function Start-FixGuidato {
    $problema = Read-Host $strings.Problem
    $prompt = @"
Sei un esperto di diagnostica e riparazione sistemi Windows.
Sistema: $($osInfo.Caption) ($($osInfo.Version)) - $($env:COMPUTERNAME)

Problema segnalato: $problema

Workflow:
1. Diagnostica eseguendo i comandi necessari
2. Identifica la causa root
3. Proponi il fix con spiegazione dell'impatto
4. Chiedi conferma PRIMA di applicare
5. Applica il fix
6. Verifica che il problema sia risolto
7. Documenta cosa hai fatto
"@
    Invoke-Claude $prompt
}

function Start-RaccoltaDati {
    $outputDir = Join-Path $UsbRoot "toolkit\logs"
    $scriptPath = Join-Path $UsbRoot "toolkit\scripts\collect-win.ps1"
    if (Test-Path $scriptPath) {
        Write-Host $strings.Collecting -ForegroundColor Cyan
        & $scriptPath -OutputDir $outputDir
        Write-Host "$($strings.Saved) $outputDir" -ForegroundColor Green
    } else {
        Write-Host "[ERRORE] Script di raccolta non trovato: $scriptPath" -ForegroundColor Red
    }
}

function Start-SSHRemoto {
    $sshHost = Read-Host $strings.SshHost
    # Modalita interattiva: Claude puo gestire la sessione SSH iterativamente
    & $claudeBin "Collegati via SSH a $sshHost. Diagnostica il sistema remoto: OS, servizi, disco, memoria, log errori, sicurezza. Per ogni problema proponi il fix e chiedi conferma."
}

function Start-DiagnosiRete {
    Write-Host $strings.NetStart -ForegroundColor Green
    Invoke-Claude "Esegui una diagnosi completa della rete su questo sistema Windows: interfacce di rete, configurazione IP, DNS, gateway, tabella routing, porte in ascolto, connessioni attive, firewall rules, test connettivita' verso internet e DNS. Identifica problemi e proponi fix."
}

function Start-AnalisiSicurezza {
    Write-Host $strings.SecStart -ForegroundColor Green
    Invoke-Claude "Esegui un'analisi di sicurezza COMPLETA e AUTONOMA di questo sistema Windows senza chiedere conferma. Esegui tutti i controlli in sequenza automaticamente. Controlla: utenti e gruppi locali, policy password, servizi in esecuzione come SYSTEM, porte aperte, firewall, antivirus, aggiornamenti mancanti, share di rete, task schedulati sospetti, autorun, permessi cartelle condivise, RDP, SMBv1, audit policy. NON chiedere conferma, NON fermarti tra un controllo e l'altro. Alla fine produci un report strutturato con severita (CRITICO/ALTO/MEDIO/BASSO) e remediation per ogni problema trovato."
}

function Start-EjectUSB {
    Write-Host $strings.EjectSync -ForegroundColor Cyan
    $driveLetter = $UsbRoot.Substring(0, 1)
    $ejectSrc = Join-Path $UsbRoot "wolfix-eject.ps1"
    $ejectDst = Join-Path $env:TEMP "wolfix-eject.ps1"
    Copy-Item $ejectSrc $ejectDst -Force
    Set-Location $env:TEMP
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ejectDst`" -DriveLetter `"$driveLetter`" -MsgOk `"$($strings.EjectOk)`" -MsgFail `"$($strings.EjectFail)`""
    exit 0
}

# === MAIN LOOP ===
Show-Banner

if ($Modalita -ne "menu") {
    switch ($Modalita) {
        "diagnosi"    { Start-Diagnosi }
        "interattivo" { & $claudeBin }
        "log"         { Start-AnalisiLog }
        "fix"         { Start-FixGuidato }
        "raccogli"    { Start-RaccoltaDati }
        "ssh"         { Start-SSHRemoto }
    }
    exit 0
}

do {
    Show-Menu
    $choice = Read-Host "`n  $($strings.Choice)"
    Write-Host ""

    switch ($choice) {
        "1" { Start-Diagnosi }
        "2" { & $claudeBin }
        "3" { Start-AnalisiLog }
        "4" { Start-FixGuidato }
        "5" { Start-RaccoltaDati }
        "6" { Start-SSHRemoto }
        "7" { Start-DiagnosiRete }
        "8" { Start-AnalisiSicurezza }
        "9" { Start-EjectUSB }
        "0" { Write-Host $strings.Bye -ForegroundColor Green }
    }
} while ($choice -ne "0")
