@echo off
title Wolfix - AI Diagnostic Toolkit
chcp 65001 >nul 2>&1

set "USB_ROOT=%~dp0"
set "USB_ROOT=%USB_ROOT:~0,-1%"

powershell -NoProfile -Command ^
  "Write-Host ''; " ^
  "Write-Host '  ================================================' -F Cyan; " ^
  "Write-Host '   __        _____  _     _____ ___ __  __' -F Cyan; " ^
  "Write-Host '   \ \      / / _ \| |   |  ___|_ _\ \/ /' -F Cyan; " ^
  "Write-Host '    \ \ /\ / / | | | |   | |_   | | \  / ' -F Cyan; " ^
  "Write-Host '     \ V  V /| |_| | |___|  _|  | | /  \ ' -F Cyan; " ^
  "Write-Host '      \_/\_/  \___/|_____|_|   |___/_/\_\' -F Cyan; " ^
  "Write-Host ''; " ^
  "Write-Host '    >_ AI Problem Solver with Anthropic' -F Cyan; " ^
  "Write-Host ''; " ^
  "Write-Host '    v0.1.0' -F DarkGray; " ^
  "Write-Host '  ================================================' -F Cyan; " ^
  "Write-Host ''; " ^
  "Write-Host '  [I] Italiano  [E] English' -F White; " ^
  "Write-Host ''"
set "LANG="
set /p "LANG=Language / Lingua: "
if /i "%LANG%"=="E" goto set_en
goto set_it

:set_en
set "M1=[1] Full system diagnosis"
set "M2=[2] Interactive Claude Code"
set "M3=[3] Analyze log file"
set "M4=[4] Guided fix"
set "M5=[5] Collect data for offline analysis"
set "M6=[6] Connect to remote server (SSH)"
set "M7=[7] Network diagnosis"
set "M8=[8] Security analysis"
set "M9=[9] Safely eject USB"
set "M0=[0] Exit"
set "MSG_OK=[OK] Environment configured."
set "MSG_CHOICE=Choice: "
set "MSG_INVALID=Invalid choice."
set "MSG_BACK=Back to menu."
set "MSG_EXIT=To return to menu: type /exit or press Ctrl+C"
set "MSG_LOGPATH=Log file path: "
set "MSG_PROBLEM=Describe the problem: "
set "MSG_COLLECTING=Collecting system data..."
set "MSG_SAVED=Data saved in"
set "MSG_SSHHOST=Host (user@ip): "
set "MSG_NETSTART=Starting network diagnosis..."
set "MSG_SECSTART=Starting security analysis..."
set "MSG_DIAGSTART=Starting full diagnosis..."
set "MSG_BYE=Goodbye."
set "MSG_NOTFOUND=File not found."
set "MSG_EJECT_SYNC=Flushing buffers..."
set "MSG_EJECT_OK=USB safely ejected. You can remove the drive now."
set "MSG_EJECT_FAIL=Could not eject the USB drive. Close all open files and try again."
goto env_setup

:set_it
set "M1=[1] Diagnosi completa del sistema"
set "M2=[2] Claude Code interattivo"
set "M3=[3] Analizza file di log"
set "M4=[4] Fix guidato"
set "M5=[5] Raccogli dati per analisi offline"
set "M6=[6] Connetti a server remoto SSH"
set "M7=[7] Diagnosi rete"
set "M8=[8] Analisi sicurezza"
set "M9=[9] Sgancia chiavetta USB"
set "M0=[0] Esci"
set "MSG_OK=[OK] Ambiente configurato."
set "MSG_CHOICE=Scelta: "
set "MSG_INVALID=Scelta non valida."
set "MSG_BACK=Tornato al menu."
set "MSG_EXIT=Per uscire e tornare al menu: scrivi /exit oppure premi Ctrl+C"
set "MSG_LOGPATH=Percorso del file di log: "
set "MSG_PROBLEM=Descrivi il problema: "
set "MSG_COLLECTING=Raccolta dati di sistema..."
set "MSG_SAVED=Dati salvati in"
set "MSG_SSHHOST=Host (user@ip): "
set "MSG_NETSTART=Avvio diagnosi rete..."
set "MSG_SECSTART=Avvio analisi sicurezza..."
set "MSG_DIAGSTART=Avvio diagnosi completa..."
set "MSG_BYE=Arrivederci."
set "MSG_NOTFOUND=File non trovato."
set "MSG_EJECT_SYNC=Scaricamento buffer in corso..."
set "MSG_EJECT_OK=Chiavetta USB sganciata in sicurezza. Puoi rimuoverla."
set "MSG_EJECT_FAIL=Impossibile sganciare la chiavetta. Chiudi tutti i file aperti e riprova."
goto env_setup

:env_setup
set "NODE_DIR=%USB_ROOT%\runtime\node-win-x64"
if not exist "%NODE_DIR%\node.exe" (
    echo [ERRORE] Node.js non trovato in %NODE_DIR%
    echo Esegui prima setup-usb.ps1 per preparare la chiavetta.
    pause
    exit /b 1
)

set "CLAUDE_BIN=%USB_ROOT%\claude-code\claude.cmd"
if not exist "%CLAUDE_BIN%" (
    echo [*] claude.cmd non trovato, tento auto-repair...
    for %%F in ("%USB_ROOT%\claude-code\.claude.cmd-*") do (
        copy "%%F" "%CLAUDE_BIN%" >nul 2>&1
        echo [OK] claude.cmd ripristinato da %%~nxF
        goto claude_ok
    )
    echo [ERRORE] Claude Code non trovato.
    echo Esegui prima setup-usb.ps1 per preparare la chiavetta.
    pause
    exit /b 1
)
:claude_ok

set "PATH=%NODE_DIR%;%USB_ROOT%\claude-code;%PATH%"
set "NPM_CONFIG_PREFIX=%USB_ROOT%\claude-code"
set "CLAUDE_CONFIG_DIR=%USB_ROOT%\config"
set "NODE_PATH=%USB_ROOT%\claude-code\lib\node_modules"

set "GIT_DIR=%USB_ROOT%\runtime\git-win-x64"
if exist "%GIT_DIR%\bin\bash.exe" (
    set "CLAUDE_CODE_GIT_BASH_PATH=%GIT_DIR%\bin\bash.exe"
    set "PATH=%GIT_DIR%\bin;%GIT_DIR%\cmd;%PATH%"
)

echo %MSG_OK%
echo.

:menu
echo  --------------------------------------------
echo    %M1%
echo    %M2%
echo    %M3%
echo    %M4%
echo    %M5%
echo    %M6%
echo    %M7%
echo    %M8%
echo    %M9%
echo    %M0%
echo  --------------------------------------------
echo.
set "CHOICE="
set /p "CHOICE=%MSG_CHOICE%"

if "%CHOICE%"=="1" goto diagnosi
if "%CHOICE%"=="2" goto interattivo
if "%CHOICE%"=="3" goto analizza_log
if "%CHOICE%"=="4" goto fix_guidato
if "%CHOICE%"=="5" goto raccogli_dati
if "%CHOICE%"=="6" goto ssh_remoto
if "%CHOICE%"=="7" goto diagnosi_rete
if "%CHOICE%"=="8" goto analisi_sicurezza
if "%CHOICE%"=="9" goto sgancia_usb
if "%CHOICE%"=="0" goto fine
echo %MSG_INVALID%
echo.
goto menu

:diagnosi
echo.
echo %MSG_DIAGSTART%
echo %MSG_EXIT%
echo.
call "%CLAUDE_BIN%" "Diagnostica questo sistema Windows: servizi, disco, RAM, CPU, Event Log, rete, DNS, aggiornamenti. Proponi fix e chiedi conferma."
echo.
echo %MSG_BACK%
echo.
goto menu

:interattivo
echo.
echo %MSG_EXIT%
echo.
call "%CLAUDE_BIN%"
echo.
echo %MSG_BACK%
echo.
goto menu

:analizza_log
echo.
set "LOGPATH="
set /p "LOGPATH=%MSG_LOGPATH%"
if "%LOGPATH%"=="" goto menu
if not exist "%LOGPATH%" (
    echo %MSG_NOTFOUND%
    goto menu
)
echo %MSG_EXIT%
echo.
call "%CLAUDE_BIN%" "Analizza questo file di log, identifica errori e anomalie. File: %LOGPATH%"
echo.
echo %MSG_BACK%
echo.
goto menu

:fix_guidato
echo.
set "PROBLEMA="
set /p "PROBLEMA=%MSG_PROBLEM%"
if "%PROBLEMA%"=="" goto menu
echo %MSG_EXIT%
echo.
call "%CLAUDE_BIN%" "Diagnostica e ripara questo problema: %PROBLEMA%. Esegui comandi diagnostici, identifica la causa, proponi il fix e chiedi conferma prima di applicarlo."
echo.
echo %MSG_BACK%
echo.
goto menu

:raccogli_dati
echo.
echo %MSG_COLLECTING%
powershell -ExecutionPolicy Bypass -File "%USB_ROOT%\toolkit\scripts\collect-win.ps1" -OutputDir "%USB_ROOT%\toolkit\logs"
echo %MSG_SAVED% %USB_ROOT%\toolkit\logs
echo.
goto menu

:ssh_remoto
echo.
set "SSH_HOST="
set /p "SSH_HOST=%MSG_SSHHOST%"
if "%SSH_HOST%"=="" goto menu
echo %MSG_EXIT%
echo.
call "%CLAUDE_BIN%" "Collegati via SSH a %SSH_HOST% e diagnostica il sistema remoto. Proponi fix e chiedi conferma."
echo.
echo %MSG_BACK%
echo.
goto menu

:diagnosi_rete
echo.
echo %MSG_NETSTART%
echo %MSG_EXIT%
echo.
call "%CLAUDE_BIN%" "Esegui una diagnosi completa della rete su questo sistema Windows: interfacce di rete, configurazione IP, DNS, gateway, tabella routing, porte in ascolto, connessioni attive, firewall rules, test connettivita' verso internet e DNS. Identifica problemi e proponi fix."
echo.
echo %MSG_BACK%
echo.
goto menu

:analisi_sicurezza
echo.
echo %MSG_SECSTART%
echo %MSG_EXIT%
echo.
call "%CLAUDE_BIN%" "Esegui un'analisi di sicurezza COMPLETA e AUTONOMA di questo sistema Windows senza chiedere conferma. Esegui tutti i controlli in sequenza automaticamente. Controlla: utenti e gruppi locali, policy password, servizi in esecuzione come SYSTEM, porte aperte, firewall, antivirus, aggiornamenti mancanti, share di rete, task schedulati sospetti, autorun, permessi cartelle condivise, RDP, SMBv1, audit policy. NON chiedere conferma, NON fermarti tra un controllo e l'altro. Alla fine produci un report strutturato con severita (CRITICO/ALTO/MEDIO/BASSO) e remediation per ogni problema trovato."
echo.
echo %MSG_BACK%
echo.
goto menu

:sgancia_usb
echo.
echo %MSG_EJECT_SYNC%
set "USB_DRIVE=%USB_ROOT:~0,2%"
set "USB_LETTER=%USB_ROOT:~0,1%"
copy "%USB_ROOT%\wolfix-eject.ps1" "%TEMP%\wolfix-eject.ps1" >nul 2>&1
cd /d "%TEMP%"
start "" /D "%TEMP%" powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\wolfix-eject.ps1" -DriveLetter "%USB_LETTER%" -MsgOk "%MSG_EJECT_OK%" -MsgFail "%MSG_EJECT_FAIL%"
exit

:fine
echo %MSG_BYE%
timeout /t 2 >nul
exit /b 0
