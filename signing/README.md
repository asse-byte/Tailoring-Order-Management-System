# Android release signing — encrypted keystore backup

`rayan-couture-keystore.tar.gz.gpg` is the **encrypted** backup of the release
signing keystore for `com.rayancouture.app`.

It is safe to keep in this (private) repo: the contents are encrypted with
**AES-256** (GPG symmetric, SHA512 s2k). Without the passphrase the file is
useless. The passphrase is **not** stored here — it lives in the owner's
password manager, and nowhere in this repository.

## What's inside

- `rayan-couture-release.jks` — the keystore (PKCS12, RSA 4096, valid to 2053-11-29)
- `KEYSTORE-INFO.txt` — alias, keystore password, fingerprint, app id

## Restore (e.g. on a new machine, or after losing the laptop)

```bash
gpg -d signing/rayan-couture-keystore.tar.gz.gpg > bundle.tar.gz   # asks for the passphrase
tar -xzf bundle.tar.gz
```

Then put `rayan-couture-release.jks` somewhere OUTSIDE this repo (e.g.
`C:/Users/<you>/keystores/`) and point `tailoring_app/android/key.properties`
at it — see `key.properties.example` and `docs/DEPLOYMENT.md`.

## Verify a build really used this key

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```
The signer SHA-256 must be:
`24e6947c00c5b62cb28ae7db2d84bc687a5f06aa102591e802903f95bab668f0`

## Rules

- **Never** commit the decrypted `.jks`, `key.properties`, or the passphrase.
  `.gitignore` blocks the first two; the passphrase is your responsibility.
- This encrypted copy is **one** backup. Keep a second one **offline**
  (USB drive / external disk) — a single GitHub account is a single point of
  failure.
- Losing both the keystore **and** this passphrase means `com.rayancouture.app`
  can never be updated again. There is no recovery, from anyone.
