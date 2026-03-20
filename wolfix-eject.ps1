<#
.SYNOPSIS
    Wolfix - Safe USB Eject Script
    Attempts programmatic eject, falls back to native Windows dialog.
.PARAMETER DriveLetter
    The USB drive letter without colon (e.g., "E")
.PARAMETER MsgOk
    Success message to display
.PARAMETER MsgFail
    Failure message to display
#>
param(
    [Parameter(Mandatory)][string]$DriveLetter,
    [string]$MsgOk = "USB safely ejected. You can remove the drive now.",
    [string]$MsgFail = "Opening Safely Remove Hardware dialog..."
)

Start-Sleep -Seconds 2

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class SafeEject {
    [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
    public static extern int CM_Locate_DevNode(out int p, string d, int f);
    [DllImport("setupapi.dll")]
    public static extern int CM_Get_Parent(out int p, int d, int f);
    [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
    public static extern int CM_Request_Device_Eject(int d, out int v, StringBuilder n, int l, int f);
}
"@

$ejected = $false
try {
    $drv = "${DriveLetter}:"
    $partition = Get-WmiObject -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$drv'} WHERE AssocClass=Win32_LogicalDiskToPartition"
    if ($partition) {
        $disk = Get-WmiObject -Query "ASSOCIATORS OF {$($partition.__RELPATH)} WHERE AssocClass=Win32_DiskDriveToDiskPartition"
        if ($disk) {
            $devInst = 0
            [void][SafeEject]::CM_Locate_DevNode([ref]$devInst, $disk.PNPDeviceID, 0)
            $parent = 0
            [void][SafeEject]::CM_Get_Parent([ref]$parent, $devInst, 0)
            $veto = 0
            $vetoName = New-Object System.Text.StringBuilder 256
            $r = [SafeEject]::CM_Request_Device_Eject($parent, [ref]$veto, $vetoName, 256, 0)
            if ($r -eq 0 -and $veto -eq 0) { $ejected = $true }
        }
    }
} catch {}

if ($ejected) {
    Write-Host $MsgOk -ForegroundColor Green
    Start-Sleep -Seconds 3
} else {
    Write-Host $MsgFail -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    Start-Process rundll32.exe -ArgumentList "shell32.dll,Control_RunDLL hotplug.dll"
    Write-Host ""
    Write-Host "Premi Invio per chiudere / Press Enter to close"
    Read-Host
}
