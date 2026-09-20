# twingate-on-demand

Keep the Twingate Windows client installed, but off after boot until you start it.

Not affiliated with Twingate. It uses standard Windows mechanisms (service start type, startup approval). Twingate documents the service as `Automatic`, so this setup is unsupported. See [Caveats](#caveats).

This README has three parts:

- [**Setup**](#setup-do-this-once): what you do once so the script works.
- [**Use**](#use-every-time-you-want-twingate): what you do each time you want Twingate.
- [**Undo**](#undo-go-back-to-twingates-normal-behavior): how to put Twingate back to normal.

## Why setup has two parts

Two things bring Twingate up at boot:

1. **The tray app.** The installer adds `Twingate.lnk` (`Twingate.exe --startup`) to the all-users Startup folder.
2. **The service.** `Twingate.Service` is `Automatic`. With no saved session it does nothing, but after you have signed in it restores the session at boot, with no tray app, and routes your LAN through the tunnel.

Turning off only one is not enough.

## Setup (do this once)

The script in this repo only starts Twingate. It does not stop Windows from starting Twingate at boot. Those changes are yours to make, once, using the steps below. After that the script is all you need.

Steps 1 and 2 need an elevated PowerShell (right-click PowerShell, then **Run as administrator**). Step 3 doesn't. Run it in a normal PowerShell so the shortcut lands in your own Start Menu.

First, get the script. Clone this repo or download `Start-Twingate.ps1`, and keep it in a folder that will stay put. The shortcut in step 3 points at that file, so don't move or delete it afterward.

**1. Set the service to Manual**

```powershell
Set-Service -Name Twingate.Service -StartupType Manual
Stop-Service -Name Twingate.Service -Force
```

**2. Turn off the startup entry**

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

Edit the `$script` line first. If Twingate is not in `C:\Program Files\Twingate`, append `-ClientPath "D:\...\Twingate.exe"` to `Arguments` and change `IconLocation`.

## Use (every time you want Twingate)

Once setup is done, nothing starts Twingate for you, so you start it yourself. Each time you want to connect:

1. Type "Start Twingate" in Start and press Enter.
2. Approve the UAC prompt. The script's window is hidden, so this prompt is the only sign it is running.
3. Sign in to Twingate when its window opens.

The script starts the service, then opens the client as your normal user. If something fails, it shows an error box.

Use this shortcut, not the regular Twingate icon: the client cannot connect while the service is stopped.

When you're done, quit the client or reboot.

To check that setup worked, reboot with no Twingate window open, then run:

```powershell
Get-Service Twingate.Service     # Stopped / Manual
Get-Process Twingate*            # nothing
Get-NetAdapter -Name Twingate    # Disconnected
```

The real test: start Twingate, sign in, then reboot without quitting.

## Undo (go back to Twingate's normal behavior)

If you want Twingate to start at boot again, the way it does out of the box, run this in an elevated PowerShell. It puts the service back to `Automatic` and turns the startup entry back on.

```powershell
Set-Service -Name Twingate.Service -StartupType Automatic
Remove-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' -Name 'Twingate.lnk'
```

Then delete the Start Menu shortcut (`Start Twingate.lnk`) if you don't want it, and reboot.

## Caveats

- **Updates can undo this.** An update may reset the service to `Automatic` and re-enable the startup entry, and may launch Twingate immediately during that session. Client 2026.239 fixed ["the client application not launching automatically after installation or update"](https://www.twingate.com/changelog/clients). After an update, re-check steps 1 and 2 and stop Twingate if it started.
- Starting the service needs elevation, so expect a UAC prompt each time. Standard-user accounts must also enter admin credentials.
- Tested on Windows 11 with client 2026.239.5147.
