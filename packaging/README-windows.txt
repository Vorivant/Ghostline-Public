Ghostline for Windows 10/11 (x64)

1. Right-click the downloaded zip, Properties, tick "Unblock", OK. Then unzip it.
2. Open PowerShell as Administrator in the unzipped folder.
3. powershell -ExecutionPolicy Bypass -File .\install.ps1
4. powershell -ExecutionPolicy Bypass -File .\join.ps1 -LoginServer https://<your server>
   Without -AuthKeyFile it prints a sign-in link; approve the device on your server.
5. ghostline status   (in a new terminal) shows your devices.

Remove: powershell -ExecutionPolicy Bypass -File .\uninstall.ps1   (add -PurgeData to delete this PC's mesh identity)
Help:   https://vorivant.com, ghostline@vorivant.com
Licences: LICENSE, THIRD-PARTY-NOTICES.md, LICENSE-*.txt (wintun.dll is WireGuard LLC's, see LICENSE-wintun.txt),
PATENTS-tailscale.txt and licenses\.
