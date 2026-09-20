# twingate-on-demand

Keeps the Twingate Windows client installed but off after boot until you start it. This project is not affiliated with Twingate, and although it only uses standard Windows mechanisms (the service start type and Windows' startup approval), Twingate's [troubleshooting article](https://help.twingate.com/articles/2020664128-windows-client-system-service-is-not-running) for a stopped service tells you to set the service's startup type to `Automatic`, so treat this setup as unsupported (see [Caveats](#caveats)).

This README has three parts:

- [**Setup**](#setup-do-this-once) is what you do once so the launcher script works.
- [**Use**](#use-every-time-you-want-twingate) is what you do each time you want Twingate.
- [**Undo**](#undo-go-back-to-twingates-normal-behavior) is how to put Twingate back to normal.

## Why setup has two parts

Two things bring Twingate up at boot; turning off only one of them is not enough.

1. **The tray app.** The installer adds `Twingate.lnk` (`Twingate.exe --startup`) to the all-users Startup folder.
2. **The service.** `Twingate.Service` is `Automatic`. With no saved session it does nothing, but after you have signed in it restores the session at boot, with no tray app, and starts routing traffic for your Twingate resources through the tunnel, which can interfere with local devices when those resources overlap your local network.

## Setup (do this once)

The launcher script only starts Twingate; it can't stop Windows from starting Twingate at boot, so you run the setup once before you use it.

1. **Get the scripts.** Clone this repo or download `Start-Twingate.ps1` and `Setup-TwingateOnDemand.ps1` into a folder that will stay put. The shortcuts point at `Start-Twingate.ps1`, so moving or deleting it later breaks them.

2. **Run the setup script** from that folder in a normal (not elevated) PowerShell. It asks for elevation itself, once, for the two steps that need it:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Setup-TwingateOnDemand.ps1
   ```

   It sets the service to Manual, turns off the startup entry and creates a "Start Twingate" shortcut in your Start Menu. Add `-Desktop` to get a Desktop shortcut too, keeping in mind that if your Desktop is redirected to OneDrive, the shortcut will sync to your other devices, where it won't work. The script can't pin anything to the taskbar because Windows doesn't allow it, but you can do that yourself by right-clicking "Start Twingate" in Start and choosing **Pin to taskbar**.

   Running it again is harmless, which is also how you repair the setup after a Twingate update.

<details>
<summary>Manual setup, instead of the setup script</summary>

<br>

Steps 1 and 2 need an elevated PowerShell (right-click PowerShell, then **Run as administrator**). Step 3 doesn't, and you should run it in a normal PowerShell so the shortcut lands in your own Start Menu.

**1. Set the service to Manual**

```powershell
Set-Service -Name Twingate.Service -StartupType Manual
Stop-Service -Name Twingate.Service -Force
```

**2. Turn off the startup entry**

The startup shortcut is machine-wide, so Windows reads its enabled flag from `HKLM`; setting only the per-user `HKCU` flag is not enough to stop it.

```powershell
$key   = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
$bytes = [byte[]](3,0,0,0) + [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc())
New-ItemProperty -Path $key -Name 'Twingate.lnk' -PropertyType Binary -Value $bytes -Force
```

This is the value Task Manager writes when you set a startup item to Disabled, so nothing is deleted and [Undo](#undo-go-back-to-twingates-normal-behavior) can reverse it.

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

Edit the `$script` line to point at your copy of `Start-Twingate.ps1` before you run it. If Twingate is not installed in `C:\Program Files\Twingate`, also append `-ClientPath "D:\...\Twingate.exe"` to `Arguments` and change `IconLocation`. The setup script doesn't handle a non-default location, so this manual route is the one to use in that case.

</details>

## Use (every time you want Twingate)

Once setup is done nothing starts Twingate for you, so each time you want to connect:

1. Type "Start Twingate" in Start and press Enter.
2. Approve the UAC prompt, which is the only sign that the script is running because its window is hidden.
3. Sign in to Twingate when its window opens.

The script starts the service and then opens the client as your normal user, and if something fails it shows an error box. Use this shortcut and not the regular Twingate icon, because the client cannot connect while the service is stopped. When you're done, quit the client or reboot.

To check that setup worked, reboot with no Twingate window open and run the commands below. The more convincing test is to start Twingate, sign in and then reboot without quitting, since a saved session is what brought the tunnel back at boot before the service was changed.

```powershell
Get-Service Twingate.Service     # Stopped / Manual
Get-Process Twingate*            # nothing
Get-NetAdapter -Name Twingate    # Disconnected
```

## Undo (go back to Twingate's normal behavior)

If you want Twingate to start at boot again, the way it does out of the box, run this in an elevated PowerShell, which puts the service back to `Automatic` and turns the startup entry back on. Then delete the "Start Twingate" shortcuts if you don't want them, and reboot.

```powershell
Set-Service -Name Twingate.Service -StartupType Automatic
Remove-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' -Name 'Twingate.lnk'
```

## Caveats

- **Updates can undo this.** An update may reset the service to `Automatic`, re-enable the startup entry and launch Twingate immediately during the update, and client 2026.239 fixed ["the client application not launching automatically after installation or update"](https://www.twingate.com/changelog/clients). After an update, run the setup script again (or manual steps 1 and 2) and stop Twingate if it started.
- Starting the service needs elevation, so every start shows a UAC prompt, and a standard-user account must also enter admin credentials.
- Tested on Windows 11 with client 2026.239.5147.

## License

[MIT](LICENSE).
