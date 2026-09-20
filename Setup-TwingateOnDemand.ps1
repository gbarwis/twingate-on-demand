# One-time setup for twingate-on-demand. Safe to run again.
#
#   1. Closes the Twingate client if it is running, sets the
#      service to Manual and stops it.                         (needs admin)
#   2. Disables the machine-wide Twingate startup entry.       (needs admin)
#   3. Creates a "Start Twingate" Start Menu shortcut, and with -Desktop
#      a Desktop shortcut too.                                 (your own profile)
#
# The shortcuts are created in your normal session so they land in your own
# profile. Only steps 1 and 2 are re-launched elevated (one UAC prompt).
#
# Start-Twingate.ps1 must stay in the same folder as this script: the shortcuts
# point at it.
#
# If scripts are blocked, run it as:
#   powershell -ExecutionPolicy Bypass -File .\Setup-TwingateOnDemand.ps1
param(
    [switch]$Desktop,
    [switch]$AdminStepsOnly   # internal: set when the script re-launches itself elevated
)

$twingateClientService = "Twingate.Service"
$twingateClientPath = "C:\Program Files\Twingate\Twingate.exe"
$launcherPath = Join-Path $PSScriptRoot "Start-Twingate.ps1"
$startupApprovedKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-LauncherShortcut([string]$Path) {
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($Path)
    $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`""
    $shortcut.IconLocation = "$twingateClientPath,0"
    $shortcut.Save()
    Write-Host "Shortcut: $Path"
}

function Set-AdminSteps {
    # Close the client first so it doesn't sit there retrying against a stopped service.
    Stop-Process -Name "Twingate" -Force -ErrorAction SilentlyContinue

    Set-Service -Name $twingateClientService -StartupType Manual
    $service = Get-Service -Name $twingateClientService
    if ($service.Status -ne "Stopped") {
        Stop-Service -Name $twingateClientService -Force
    }

    # Same value Task Manager writes when a startup item is set to Disabled.
    $disabled = [byte[]](3, 0, 0, 0) + [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc())
    New-ItemProperty -Path $startupApprovedKey -Name "Twingate.lnk" -PropertyType Binary -Value $disabled -Force | Out-Null
}

try {
    $ErrorActionPreference = "Stop"

    if (-not $AdminStepsOnly) {
        if (-not (Test-Path -LiteralPath $launcherPath)) {
            throw "Start-Twingate.ps1 not found next to this script ($launcherPath)."
        }
        Get-Service -Name $twingateClientService | Out-Null   # fails early if Twingate is not installed

        New-LauncherShortcut (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Start Twingate.lnk")
        if ($Desktop) {
            New-LauncherShortcut (Join-Path ([Environment]::GetFolderPath("Desktop")) "Start Twingate.lnk")
        }
    }

    if (Test-Admin) {
        Set-AdminSteps
    } else {
        Write-Host "Approve the UAC prompt to change the service and startup entry..."
        $elevated = Start-Process -FilePath "powershell.exe" -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-AdminStepsOnly"
        if ($elevated.ExitCode -ne 0) {
            throw "The elevated step failed (exit code $($elevated.ExitCode))."
        }
    }

    if (-not $AdminStepsOnly) {
        Write-Host ""
        Write-Host "Done. Twingate will stay off at boot; start it with the 'Start Twingate' shortcut."
        Write-Host "To pin it to the taskbar: find 'Start Twingate' in Start, right-click it, choose 'Pin to taskbar'."
    }
} catch {
    $message = "Setup failed:`n`n$($_.Exception.Message)"
    if ($AdminStepsOnly) {
        # The elevated window is hidden, so show the error in a message box.
        (New-Object -ComObject WScript.Shell).Popup($message, 0, "Setup-TwingateOnDemand", 16) | Out-Null
    } else {
        Write-Host $message -ForegroundColor Red
    }
    exit 1
}
