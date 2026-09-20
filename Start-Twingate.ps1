# Starts Twingate on demand. The Twingate service is set to Manual and the
# client's startup entry is disabled, so nothing runs until this script is used.
#
# Starting the service needs admin, so the script re-launches itself elevated
# (one UAC prompt). The client UI is opened through explorer.exe so it runs as
# the normal user rather than elevated.

$twingateClientPath = "C:\Program Files\Twingate\Twingate.exe"
$twingateClientService = "Twingate.Service"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process -FilePath "powershell.exe" -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`""
    exit
}

$service = Get-Service -Name $twingateClientService -ErrorAction Stop
if ($service.Status -ne "Running") {
    Start-Service -Name $twingateClientService
    $service.WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
}

if (-not (Get-Process -Name "Twingate" -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$twingateClientPath`""
}
