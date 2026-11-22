# Ghostline for Android

`build-app.sh` builds the app from the open-source Tailscale Android client at the tag pinned in
`../upstream.json`, with `app.patch` (names, icons, log upload to Tailscale Inc. off, Google DNS fallback off) and
the same rebranded network core as the desktop builds. The application ID is `com.vorivant.ghostline`.

There is no server built in. After installing: open the app's settings, choose "Use an alternate server" and enter
your server's address, then sign in and approve the device on your server.

## Signing

Android installs and updates only signed APKs, and every update must be signed with the same key. Create the
release key once, on your own computer, and keep it and its password safe and out of this repository:

```
keytool -genkeypair -keystore ghostline-release.p12 -storetype PKCS12 -alias ghostline -keyalg RSA \
  -keysize 4096 -validity 10950 -dname "CN=Ghostline, O=Vorivant"
```

The release workflow signs with that key when the secrets `ANDROID_KEYSTORE_B64` (the .p12 file,
base64) and `ANDROID_KEYSTORE_PASSWORD` are set in the protected "release" environment (see the header of
`.github/workflows/release.yml`); without them it builds an unsigned APK, which `package.py` refuses
to publish.
