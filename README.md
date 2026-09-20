# twingate-on-demand

Keep the Twingate Windows client installed, but off after boot until you start it.

Not affiliated with Twingate. It uses standard Windows mechanisms (service start type, startup approval). Twingate documents the service as `Automatic`, so this setup is unsupported. See [Caveats](#caveats).

## Why two changes

Two things bring Twingate up at boot:

1. **The tray app.** The installer adds `Twingate.lnk` (`Twingate.exe --startup`) to the all-users Startup folder.
2. **The service.** `Twingate.Service` is `Automatic`. With no saved session it does nothing, but after you have signed in it restores the session at boot, with no tray app, and routes your LAN through the tunnel.

Disabling only one is not enough.

## Setup

In an elevated PowerShell.

**1. Set the service to Manual**

```powershell
Set-Service -Name Twingate.Service -StartupType Manual
Stop-Service -Name Twingate.Service -Force
```

**2. Disable the startup entry**

The shortcut is machine-wide, so its flag is read from `HKLM`. Setting only the per-user `HKCU` flag did not stop it.

```powershell
$key   = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
$bytes = [byte[]](3,0,0,0) + [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc())
New-ItemProperty -Path $key -Name 'Twingate.lnk' -PropertyType Binary -Value $bytes -Force
```

This is the value Task Manager writes for Disabled. Nothing is deleted.

**3. Add a Start Menu shortcut**

```powershell
$script = 'C:\path\to\Start-Twingate.ps1'   # edit
$lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Start Twingate.lnk'
$s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$s.TargetPath   = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments    = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$s.IconLocation = 'C:\Program Files\Twingate\Twingate.exe,0'
$s.Save()
```

If Twingate is not in `C:\Program Files\Twingate`, append `-ClientPath "D:\...\Twingate.exe"` to `Arguments` and change `IconLocation`.

## Use

Type "Start Twingate" in Start and approve the UAC prompt. The script starts the service, then opens the client as your normal user. Its window is hidden, so the prompt is the only sign it is running. If something fails, it shows an error box.

Use this shortcut, not the regular Twingate icon: the client cannot connect while the service is stopped.

To stop, quit the client or reboot.

## Verify

After a reboot, with no Twingate window open:

```powershell
Get-Service Twingate.Service     # Stopped / Manual
Get-Process Twingate*            # nothing
Get-NetAdapter -Name Twingate    # Disconnected
```

The real test: start Twingate, sign in, then reboot without quitting.

## Undo

```powershell
Set-Service -Name Twingate.Service -StartupType Automatic
Remove-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' -Name 'Twingate.lnk'
```

## Caveats

- **Updates can undo this.** An update may reset the service to `Automatic` and re-enable the startup entry, and may launch Twingate immediately during that session. Client 2026.239 fixed ["the client application not launching automatically after installation or update"](https://www.twingate.com/changelog/clients). After an update, re-check steps 1 and 2 and stop Twingate if it started.
- Starting the service needs elevation, so expect a UAC prompt each time. Standard-user accounts must also enter admin credentials.
- Tested on Windows 11 with client 2026.239.5147.
