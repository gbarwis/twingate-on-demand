# twingate-on-demand

Keep the Twingate Windows client installed, but completely inactive after boot
until you deliberately start it.

Not affiliated with Twingate. This is a workaround built on documented Windows
mechanisms (service start type, startup approval); Twingate's docs describe the
service as `Automatic`, so an update may undo parts of it (see [Caveats](#caveats)).

## The problem

Out of the box the Windows client comes up at every boot and takes over
networking, which interferes with access to the local LAN and with other VPN
software. Two things start it:

1. **The tray app.** The installer puts `Twingate.lnk` (`Twingate.exe --startup`)
   in the all-users Startup folder. It signs in and brings up the tunnel.
2. **The service.** `Twingate.Service` is set to `Automatic`. On its own with no
   saved session it does nothing, but once you have signed in, the service
   restores that session at boot without the tray app (`Connect with
   AuthMode=Device` in `C:\ProgramData\Twingate\logs\Twingate.Service.log`),
   and routes your LAN through the tunnel.

Stopping only one of them is not enough.

## The fix

| | Change | Needs admin |
|---|---|---|
| 1 | Set `Twingate.Service` start type to **Manual** | yes |
| 2 | Disable the machine-wide `Twingate.lnk` startup entry | yes |
| 3 | Start Twingate through `Start-Twingate.ps1` when you want it | UAC prompt at each start |

After this, nothing Twingate-related runs at boot, even with a saved session.

### 1. Service to Manual

Elevated PowerShell:

```powershell
Set-Service -Name Twingate.Service -StartupType Manual
Stop-Service -Name Twingate.Service -Force
```

### 2. Disable the startup entry

`Twingate.lnk` is in the **all-users** Startup folder, so its enabled/disabled
flag is read from `HKLM`. Setting only the per-user `HKCU` flag (what you get
from some tools) is not enough: the client still launched at boot.
Elevated PowerShell:

```powershell
$key   = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
$bytes = [byte[]](3,0,0,0) + [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc())
New-ItemProperty -Path $key -Name 'Twingate.lnk' -PropertyType Binary -Value $bytes -Force
```

This is the same value Task Manager writes when a startup item is set to
Disabled. It does not delete anything.

### 3. Start Twingate on demand

`Start-Twingate.ps1` re-launches itself elevated (one UAC prompt), starts the
service, then opens the client. The client is opened through `explorer.exe` so
it runs as your normal user and not elevated.

Create a Start Menu shortcut so you can type "Start Twingate" in Start:

```powershell
$script = 'C:\path\to\Start-Twingate.ps1'   # <-- edit
$lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Start Twingate.lnk'
$s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$s.TargetPath   = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments    = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$s.IconLocation = 'C:\Program Files\Twingate\Twingate.exe,0'
$s.Save()
```

The launcher window is hidden, so the UAC prompt is the only sign that it is
running. Use the **Start Twingate** shortcut, not the regular Twingate icon: the
client cannot connect while the service is stopped.

## Stopping

Quit the client, or reboot. With the service on Manual it stays off after a
reboot. (Between quitting and rebooting the service keeps running, but with no
signed-in session it is inert.)

## Verify

After a reboot, with no Twingate window open:

```powershell
Get-Service Twingate.Service          # Stopped / Manual
Get-Process Twingate*                 # nothing
Get-NetAdapter -Name Twingate         # Disconnected
```

The meaningful test is to start Twingate, sign in, then reboot without quitting.

## Undo

```powershell
# elevated
Set-Service -Name Twingate.Service -StartupType Automatic
Remove-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' -Name 'Twingate.lnk'
```

Delete the Start Menu shortcut if you no longer want it.

## Caveats

- Twingate documents the service as `Automatic`. Manual is off the documented
  path, and an update may reset the start type or recreate the startup entry.
  If Twingate comes up on its own again after an update, re-apply steps 1 and 2.
- Starting the service needs admin. On a standard-user account the UAC prompt
  asks for admin credentials each time.
- Tested on Windows 11 with Twingate client `2026.239.5147`.
