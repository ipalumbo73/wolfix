# Wolfix  >_ AI Problem Solver with Anthropic

**Portable AI-powered diagnostic toolkit for Windows, Linux, and macOS.**

*Runs entirely from a USB drive. No installation required. No traces left on the target system.*

*Powered by [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Anthropic](https://www.anthropic.com/)*

---

## Why Wolfix

If you have an Anthropic subscription (API key or Claude Max), Wolfix lets you carry your AI assistant on a USB drive and use it on any machine -- without installing anything. This is ideal for:

- **IT technicians** who work on client machines and cannot install third-party software
- **System administrators** who need quick diagnostics across multiple servers
- **Consultants** who need a portable, zero-footprint troubleshooting toolkit
- **Compliance environments** where no tools can be left behind after an intervention

### Advantages of running from USB

- **Your subscription, everywhere.** Use your existing Anthropic account on any machine -- just plug in and go.
- **No software conflicts.** Wolfix carries its own Node.js runtime, Git, and Claude Code. Nothing touches the host system's packages or PATH permanently.
- **Instant readiness.** No `npm install`, no dependency resolution, no version conflicts. It just works.
- **Portable credentials.** Your authentication stays on the USB drive, not scattered across machines in `~/.config` directories.

---

## Features

- **Zero installation** -- runs entirely from USB, leaves no trace on the target system
- **Cross-platform** -- Windows (10/11, Server 2016-2025), Linux (all major distros), macOS (Intel + Apple Silicon)
- **Interactive diagnostics** -- AI-driven analysis of services, disk, RAM, CPU, event logs, network, and updates
- **Guided repair** -- proposes fixes with clear explanations and asks for confirmation before applying
- **Log analysis** -- parses any log file to identify errors, anomalies, and patterns
- **Security auditing** -- checks users, permissions, open ports, firewall rules, and known vulnerabilities
- **Network diagnostics** -- full stack analysis from interfaces to DNS to firewall
- **Remote access** -- connect to remote servers via SSH for diagnosis and repair
- **Offline data collection** -- gathers system data for later analysis on an air-gapped machine
- **Safe USB eject** -- built-in option to safely unmount and remove the USB drive on all platforms

---

## Supported Platforms

| Platform | Versions | Mode |
|----------|----------|------|
| Windows Desktop | 10, 11 | Full diagnostic and repair |
| Windows Server | 2016, 2019, 2022, 2025 | Full diagnostic and repair |
| Windows Server (legacy) | 2008, 2012 | Data collection only |
| Linux | All major distributions | Full diagnostic and repair |
| macOS (Intel) | 11+ (Big Sur and later) | Full diagnostic and repair |
| macOS (Apple Silicon) | 11+ (Big Sur and later) | Full diagnostic and repair |
| VMware ESXi | 6.x, 7.x, 8.x | Diagnostic and health check |
| VMware vCenter | 6.x, 7.x, 8.x | Diagnostic and health check |

---

## Quick Start

### Prerequisites

- A USB drive with at least **2 GB** of free space (exFAT or NTFS recommended)
- Internet connection on the setup machine
- Windows PC with PowerShell 5.1+ (for the one-time setup)

### Step 1: Prepare the USB drive (one-time)

Insert the USB drive and run from PowerShell:

```powershell
.\setup-usb.ps1 -UsbDrive E
```

Replace `E` with your USB drive letter. This will:

1. Download Node.js portable runtimes (Windows, Linux x64, macOS Intel, macOS ARM64)
2. Download Git Portable for Windows
3. Install Claude Code CLI
4. Prompt you to authenticate (browser login)
5. Copy all launcher scripts and diagnostic tools to the USB drive

The setup takes 5-10 minutes depending on your internet speed.

### Step 2: Authenticate

During setup, the script will open a browser window for authentication. You have two options:

| Method | How to set up |
|--------|---------------|
| **Claude Max subscription** | Log in with your Anthropic account when prompted during setup |
| **API key** | After setup, create a file `config/settings.json` on the USB drive with your key (see [Authentication](#authentication) below) |

### Step 3: Use on any machine

Plug the USB drive into the target machine, then:

| Platform | Command |
|----------|---------|
| **Windows (CMD)** | Double-click `launch.bat` |
| **Windows (PowerShell)** | Run `.\launch.ps1` |
| **Linux** | Run `bash launch.sh` |
| **macOS** | Open Terminal, run `bash launch.sh` |

> **Tip:** On Linux/macOS, the first launch on a new platform takes 10-15 seconds to extract the Node.js runtime to a local temp directory. Subsequent launches are instant.

---

## Authentication

Wolfix stores authentication data in the `config/` directory on the USB drive. This directory is **never committed to Git** (it's in `.gitignore`).

### Option A: Browser login (recommended)

During `setup-usb.ps1`, the script runs `claude login` which opens a browser. Log in with your Anthropic account. The session token is saved to `config/` on the USB drive.

### Option B: API key

If you prefer to use an API key:

1. Generate a key at [console.anthropic.com](https://console.anthropic.com/)
2. On the USB drive, create the file `config/.claude/settings.json`:

```json
{
  "apiKey": "sk-ant-your-key-here"
}
```

Alternatively, you can set the environment variable before launching:

```bash
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
bash launch.sh
```

### Where credentials are stored

```
USB drive/
└── config/           <-- All auth data lives here
    └── .claude/      <-- Claude Code session and settings
```

This directory exists **only on the USB drive**. When you remove the drive, no credentials remain on the target machine.

---

## Menu Options

| # | Option | Description |
|---|--------|-------------|
| 1 | Full System Diagnosis | Checks services, disk, RAM, CPU, event logs, network, updates, and firewall |
| 2 | Interactive Claude Code | Opens a free-form Claude Code session for custom queries |
| 3 | Analyze Log File | Parses a log file to find errors, warnings, and anomalies |
| 4 | Guided Fix | Describe a problem and get a step-by-step diagnosis and repair |
| 5 | Collect Data for Offline | Gathers system information and saves it to the USB drive |
| 6 | Connect to Remote Server | Diagnoses and repairs a remote system over SSH |
| 7 | Network Diagnosis | Analyzes interfaces, IP, DNS, routing, ports, and firewall rules |
| 8 | Security Analysis | Audits users, permissions, open ports, services, and scheduled tasks |
| 9 | Safely Eject USB | Unmounts and ejects the USB drive safely |
| 0 | Exit | Closes the toolkit |

---

## Project Structure

```
wolfix-usb-drive/
├── launch.bat                         # Windows CMD launcher
├── launch.ps1                         # Windows PowerShell launcher
├── launch.sh                          # Linux / macOS launcher
├── wolfix-eject.ps1                   # Windows USB safe eject script
├── setup-usb.ps1                      # One-time USB setup script (run from source)
├── VERSION                            # Current version
├── toolkit/
│   ├── prompts/                       # Platform-specific diagnostic prompts
│   │   ├── windows-health.md
│   │   ├── linux-health.md
│   │   ├── macos-health.md
│   │   ├── esxi-health.md
│   │   ├── vmware-health.md
│   │   └── server-2008-2012.md
│   ├── scripts/                       # Data collection scripts
│   │   ├── collect-win.ps1
│   │   ├── collect-linux.sh
│   │   ├── collect-macos.sh
│   │   └── collect-esxi.sh
│   └── logs/                          # Collected data output (gitignored)
├── runtime/                           # Portable runtimes (created by setup, gitignored)
│   ├── node-win-x64/                  # Node.js for Windows
│   ├── node-linux-x64/                # Node.js for Linux (tar.xz, extracted on first use)
│   ├── node-darwin-x64/               # Node.js for macOS Intel (tar.gz, extracted on first use)
│   ├── node-darwin-arm64/             # Node.js for macOS Apple Silicon (tar.gz, extracted on first use)
│   └── git-win-x64/                   # Git Portable for Windows
├── claude-code/                       # Claude Code CLI (created by setup, gitignored)
└── config/                            # Auth and settings (created by setup, gitignored)
```

---

## How It Works

### Windows

`launch.bat` adds the portable Node.js and Git to the session PATH, sets `CLAUDE_CONFIG_DIR` to the USB's `config/` directory, and launches Claude Code. Git Portable provides the bash shell that Claude Code requires on Windows.

### Linux and macOS

`launch.sh` detects the OS and architecture, extracts the appropriate Node.js runtime from the USB to `/tmp/` (because USB drives are typically mounted with `noexec` and use exFAT which doesn't support symlinks), creates a lightweight wrapper script in `/tmp/`, and launches Claude Code through it.

On the first run per platform, the extraction takes 10-15 seconds. On subsequent runs, the cached runtime in `/tmp/` is reused instantly (until the machine is rebooted).

### USB Eject

The safe eject feature (menu option 9) handles the complexity of unmounting USB drives across platforms:

- **Windows:** Copies the eject script to `%TEMP%`, changes directory away from USB, and uses PowerShell to safely eject
- **Linux:** Terminates processes holding the mount (file manager, shells), then uses `udisksctl` or `umount` to unmount
- **macOS:** Uses `diskutil unmount force` to unmount even when files are in use

---

## Zero Footprint -- Nothing Left Behind

Wolfix is designed so that **nothing is installed on the target machine**:

- **No software installed** -- Node.js, Git, and Claude Code all run from the USB drive
- **No files written to disk** -- no binaries, no libraries, no config files on the host
- **No registry changes** (Windows) -- no entries added or modified
- **No system services** -- no daemons, no launch agents, no scheduled tasks
- **No PATH modifications** -- temporary PATH changes exist only in the shell session
- **No credentials on host** -- API keys and tokens stay on the USB drive

On Linux/macOS, Node.js is temporarily cached in `/tmp/` during the session. This is automatically cleaned up on reboot, or by using the "Safely Eject USB" menu option which deletes the cache before unmounting.

---

## Security Considerations

> **Important:** Read this section carefully before using Wolfix.

### Your credentials are on the USB drive

The `config/` directory on the USB drive contains your Anthropic authentication session or API key. **If the USB drive is lost or stolen, anyone who finds it can use your Anthropic subscription.**

**Recommendations:**

- **Encrypt the USB drive** with BitLocker (Windows), LUKS (Linux), or FileVault (macOS)
- **Never leave the USB drive unattended** when it contains active credentials
- **Revoke sessions** immediately if the drive is lost: go to [console.anthropic.com](https://console.anthropic.com/) and revoke all sessions
- **Use API keys with spending limits** rather than unlimited keys
- **Rotate credentials periodically** -- re-run `setup-usb.ps1` to refresh the login

### Claude Code has shell access

Claude Code executes commands on the target machine to perform diagnostics. While it always asks for confirmation before running destructive commands, you should:

- **Review commands before approving** -- especially `rm`, `systemctl stop`, firewall changes, and service restarts
- **Use on trusted networks** -- Claude Code communicates with Anthropic's API over HTTPS
- **Be cautious with option 8 (Security Analysis)** -- it runs autonomously and may access sensitive files like `/etc/shadow`

### What is NOT stored in this repository

This Git repository contains only the source code and scripts. The following are **never committed** (excluded by `.gitignore`):

- `config/` -- authentication tokens and settings
- `runtime/` -- Node.js and Git binaries
- `claude-code/` -- Claude Code CLI installation
- `toolkit/logs/` -- collected diagnostic data
- `.claude/` -- local Claude Code configuration

---

## Requirements

| Component | Minimum | Notes |
|-----------|---------|-------|
| USB drive | 2 GB free space | exFAT recommended for cross-platform compatibility |
| Internet | Required on target | For Claude Code API communication (HTTPS) |
| Windows setup | PowerShell 5.1+ | For running `setup-usb.ps1` |
| Linux target | Bash, tar | `xz-utils` auto-installed if needed for Node.js extraction |
| macOS target | Bash, tar | Supports both Intel (x64) and Apple Silicon (ARM64) |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Node.js non trovato" on Windows | Run `setup-usb.ps1` first to prepare the USB drive |
| Slow first launch on Linux/macOS | Normal -- Node.js is being extracted to `/tmp/`. Takes 10-15 sec, then instant |
| "Permission denied" on Linux | USB mounted with `noexec` -- this is handled automatically since v0.2.0 |
| USB eject fails on Linux | The script automatically kills blocking processes. If it still fails, close the file manager manually |
| Authentication expired | Re-run `setup-usb.ps1` and log in again, or set `ANTHROPIC_API_KEY` environment variable |

---

## Version History

| Version | Changes |
|---------|---------|
| 0.2.0 | Cross-platform Linux/macOS support, exFAT workarounds, safe USB eject, ASCII banner |
| 0.1.0 | Initial release, Windows only |

---

## License

This project is licensed under the [MIT License](LICENSE).
