#!/usr/bin/env python3
"""Public texts and links of the Ghostline Android app, applied by build-app.sh after app.patch.

    python3 -I android/app_texts.py APP_DIR CONTROL_URL

The upstream app links to Tailscale Inc.'s admin console, sign-in, privacy policy, terms, support and knowledge base,
and its welcome screen states Tailscale Inc.'s data collection. None of that applies to Ghostline (your own server,
no telemetry), so every link goes to this project's documents and the texts below replace upstream's. Fails if any
text is not found or a tailscale.com link is left in Links.kt. Standard library only.
"""
import re
import sys
from pathlib import Path

REPO = "https://github.com/Vorivant/Ghostline-Public"
DOC = REPO + "/blob/main/"
LINKS = {
    "SERVER_URL": DOC + "server/SELF-HOST.md",
    "SIGNIN_URL": DOC + "server/SELF-HOST.md",
    "PRIVACY_POLICY_URL": DOC + "PRIVACY.md",
    "TERMS_URL": DOC + "LICENSE",
    "DOCS_URL": REPO + "#readme",
    "START_GUIDE_URL": REPO + "#quick-start",
    "LICENSES_URL": DOC + "THIRD-PARTY-NOTICES.md",
    "DELETE_ACCOUNT_URL": DOC + "server/SELF-HOST.md",
    "TAILNET_LOCK_KB_URL": DOC + "server/SELF-HOST.md",
    "KEY_EXPIRY_KB_URL": DOC + "server/SELF-HOST.md",
    "INSTALL_TAILSCALE_KB_URL": REPO + "#quick-start",
    "INSTALL_UNSTABLE_KB_URL": REPO + "#quick-start",
    "MAGICDNS_KB_URL": DOC + "server/SELF-HOST.md",
    "TROUBLESHOOTING_KB_URL": REPO + "#readme",
    "SUPPORT_URL": REPO + "/issues",
    "TAILDROP_KB_URL": REPO + "#readme",
    "TAILFS_KB_URL": REPO + "#readme",
    "SUBNET_ROUTERS_KB_URL": DOC + "server/SELF-HOST.md",
}
STRINGS = {
    "welcome1": "Ghostline connects your own devices into one private, encrypted network.",
    "welcome2": "Devices connect to each other directly where they can, and through your own server's relay where "
                "they cannot. Your server coordinates the network. This app sends no logs or usage data to Vorivant or "
                "anyone else.",
    "client_remote_logging_disable_confirm_message": "Ghostline never uploads logs; this setting has no effect.",
    "delete_tailnet": "Remove devices or users",
    "contact_support": "Open the guide",
    "request_deletion_nonowner": "Your devices and users are stored only on your own server, not by Vorivant. To "
                                 "remove this device, run headscale nodes delete on your server; to remove a user, "
                                 "run headscale users destroy. Open the guide for details.",
    "request_deletion_owner_part1": "Your devices and users are stored only on your own server, not by Vorivant. "
                                    "To remove them, see",
    "request_deletion_owner_part2a": "(headscale nodes delete and headscale users destroy on your server).",
    "request_deletion_owner_part2b": "Nothing about this network is stored anywhere else.",
    "bug_report_instructions_linktext": "open an issue&#160;",
    "bug_report_id_desc": "Ghostline uploads no logs, so this ID is only a reference for your own report.",
    "about_view_footnotes": "This app is built from the open-source Tailscale Android client "
                            "(BSD-3-Clause, © Tailscale Inc &amp; contributors). It is not made or endorsed by "
                            "Tailscale Inc.\\n\\nTailscale is a registered trademark of Tailscale Inc. WireGuard is a "
                            "registered trademark of Jason A. Donenfeld.",
}


# Hard-coded links outside Links.kt: (file under android/src/main/java/com/tailscale/ipn/ui, old, new).
CODE_LINKS = [
    ("view/UserSwitcherView.kt", 'Uri.parse("https://tailscale.com/contact/support")',
     'Uri.parse("%sserver/SELF-HOST.md")' % DOC),
    ("view/UserSwitcherView.kt", 'LinkAnnotation.Url("https://login.tailscale.com/admin/settings/general")',
     'LinkAnnotation.Url("%sserver/SELF-HOST.md")' % DOC),
    ("view/UserSwitcherView.kt", 'append("Settings > General")', 'append("the self-hosting guide")'),
]
# A link the app opens must never point at Tailscale Inc.; these forms are what opens one.
OPENED_LINK = re.compile(r'(?:Uri\.parse|LinkAnnotation\.Url|openUri)\(\s*"https?://[^"]*tailscale\.com[^"]*"')


def main():
    app, control = Path(sys.argv[1]), sys.argv[2]
    links = app / "android/src/main/java/com/tailscale/ipn/ui/Links.kt"
    text = links.read_text(encoding="utf-8")
    if "@REMOTA_CONTROL_URL@" not in text:
        sys.exit("app_texts: Links.kt has no control URL placeholder")
    text = text.replace("@REMOTA_CONTROL_URL@", control)
    admin = 'const val ADMIN_URL = SERVER_URL + "/admin"'
    if text.count(admin) != 1:
        sys.exit("app_texts: Links.kt has no single ADMIN_URL")
    text = text.replace(admin, 'const val ADMIN_URL = "%s"' % (DOC + "server/SELF-HOST.md"))
    for name, url in LINKS.items():
        text, n = re.subn(r'(const val %s =\s*)"[^"]*"' % name, lambda m: m.group(1) + '"%s"' % url, text)
        if n != 1:
            sys.exit("app_texts: Links.kt has no single %s" % name)
    if "tailscale.com" in text:
        sys.exit("app_texts: a tailscale.com link is left in Links.kt")
    links.write_text(text, encoding="utf-8")

    ui = app / "android/src/main/java/com/tailscale/ipn/ui"
    for rel, old, new in CODE_LINKS:
        f = ui / rel
        t = f.read_text(encoding="utf-8")
        if t.count(old) != 1:
            sys.exit("app_texts: %s has no single %s" % (rel, old))
        f.write_text(t.replace(old, new), encoding="utf-8")
    for f in sorted((app / "android/src/main/java").rglob("*.kt")):
        if OPENED_LINK.search(f.read_text(encoding="utf-8")):
            sys.exit("app_texts: %s still opens a tailscale.com link" % f.relative_to(app))

    strings = app / "android/src/main/res/values/strings.xml"
    xml = strings.read_text(encoding="utf-8")
    for name, value in STRINGS.items():
        value = value.replace("'", "\\'")
        xml, n = re.subn(r'(<string name="%s"[^>]*>)[^<]*(</string>)' % name,
                         lambda m: m.group(1) + value + m.group(2), xml)
        if n != 1:
            sys.exit("app_texts: strings.xml has no single %s" % name)
    strings.write_text(xml, encoding="utf-8")
    # Translations of the replaced texts would still say what upstream says: drop them, English is used instead.
    for f in sorted((app / "android/src/main/res").glob("values-*/strings.xml")):
        t = f.read_text(encoding="utf-8")
        for name in STRINGS:
            t = re.sub(r'\s*<string name="%s"[^>]*>[^<]*</string>' % name, "", t)
        f.write_text(t, encoding="utf-8")


if __name__ == "__main__":
    main()
