# Privacy

Ghostline is software you run yourself. Vorivant runs no service for it.

- **What the apps send, and where.** Each device talks to the coordination server you set up yourself (Headscale,
  [server/SELF-HOST.md](server/SELF-HOST.md)) and to your other devices. When two devices cannot reach each other
  directly, the encrypted WireGuard traffic goes through the relay built into your own server. The client is designed
  not to upload logs or contact Vorivant or Tailscale Inc. for coordination. An independent platform-by-platform
  network-egress acceptance report has not yet been published; review this claim as a design goal until tested.
- **What is compiled out.** Log and network-flow upload, the self-updater and its update checks, the built-in list
  of Tailscale Inc. relay servers, bootstrap DNS through those relays, the web client, debug endpoints, serve and
  funnel. See the build tags in [build.sh](build.sh) and the edits in [rebrand/rules.json](rebrand/rules.json).
- **What your server learns.** Your coordination server holds what a mesh needs: each device's name, operating
  system, public key, mesh address and the network addresses it can be reached at, plus the user names you create.
  Your relay sees encrypted traffic between your devices and their IP addresses. Neither can read your traffic.
- **Captive-portal and connectivity checks.** Desktop source changes limit the configured checks to your own server;
  Android captive-portal detection is omitted. Network captures on shipped builds are still required to verify this.
- **Downloads.** The Vorivant website serves the download files. Its own privacy notice covers website visits.

Ghostline is not an internet VPN: the websites you visit still see your normal IP address.

Questions: ghostline@vorivant.com. Security reports: [SECURITY.md](SECURITY.md).
