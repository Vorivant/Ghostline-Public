Ghostline for Linux (systemd)

1. sudo ./install.sh
2. sudo ./join.sh --login-server https://<your server>
   Without --authkey-file it prints a sign-in link; approve the device on your server.
3. ghostline status      shows your devices; ghostline ip shows this device's mesh address.

Remove: sudo ./uninstall.sh   (add --purge to also delete this device's mesh identity)
Help:   ./install.sh --help, ./join.sh --help, https://vorivant.com, ghostline@vorivant.com
Licences: LICENSE, THIRD-PARTY-NOTICES.md, LICENSE-*.txt, PATENTS-tailscale.txt and licenses/.
