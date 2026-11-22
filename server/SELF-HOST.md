# Run your own Ghostline server

Your Ghostline devices need one coordination server. It hands out each device's keys and addresses and tells
devices how to reach each other. It never sees the content of your traffic: that is end-to-end encrypted
(WireGuard) between your devices. When two devices cannot reach each other directly, the server's built-in relay
passes their encrypted packets along.

This kit runs [Headscale](https://github.com/juanfont/headscale) 0.29.7 (open source) behind
[Caddy](https://caddyserver.com) (automatic HTTPS) with Docker Compose.

## What you need

- A small Linux server with a public address (1 vCPU and 1 GB of memory are plenty for a household) with Docker
  and the Docker Compose plugin.
- A domain name, for example `mesh.example.org`, with a DNS A (and AAAA, if the server has IPv6) record pointing at
  the server.
- Open ports: TCP 80 (certificate issuance), TCP 443 (devices, sign-in, relay), UDP 3478 (STUN).

## Set up

```
tar xzf Ghostline-1.0.0-server-kit.tar.gz && cd Ghostline-1.0.0-server-kit
./configure.sh --domain mesh.example.org
docker compose up -d
docker compose exec headscale headscale users create me
```

Check that `https://mesh.example.org/health` answers. Then join your devices (the download page shows the steps) with
`--login-server https://mesh.example.org`.

## Approve devices

- **Interactive:** the join command prints a link. Open it, and run the `headscale auth register ...` command it
  shows on the server: `docker compose exec headscale headscale auth register --user me --auth-id <ID>`.
- **With a key:** `docker compose exec headscale headscale preauthkeys create --user me --expiration 1h` and pass
  the key in a private file (`join.sh --authkey-file`, `join.ps1 -AuthKeyFile`). Delete the file after joining.

List and remove devices: `docker compose exec headscale headscale nodes list` and `... nodes delete -i <ID>`.

## Who may talk to whom

`config/policy.hujson` starts with one rule: each user's devices reach each other and nothing else. Edit it and
restart Headscale (`docker compose restart headscale`). Policy syntax: <https://headscale.net/stable/ref/acls/>.

## Keep it safe

- `data/` holds the database and the server's private keys. Keep it private (`configure.sh` makes it 0700) and
  back it up while the server is stopped.
- The admin API is not reachable from the internet (Caddy answers 404 on `/api`); use the `headscale` command
  on the server.
- Device keys expire after 180 days (`node.expiry` in the config); devices then sign in again.
- The built-in relay only serves devices this server knows (`verify_clients: true`). A device you delete loses its
  peers at once, because every other device drops its key.

## Updating

The images are pinned by digest in `docker-compose.yml`. To update, change the tag and digest to a newer release
from the publisher, read the Headscale release notes for configuration changes, then `docker compose pull` and
`docker compose up -d`.
