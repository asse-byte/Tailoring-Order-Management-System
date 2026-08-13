# Android release signing — encrypted keystore backup

`rayan-couture-keystore.tar.gz.gpg` is the **encrypted** backup of the release
signing keystore for `com.rayancouture.app`.

> ⚠️ **This repository is PUBLIC** (verified against the GitHub API on
> 2026-08-13: `visibility: public`). An earlier version of this file called the
> repo private and concluded the backup was safe to keep here. That was wrong,
> and the conclusion it supported does not hold.
>
> Anyone on the internet can download this file. The contents are encrypted
> with **AES-256** (GPG symmetric, SHA512 s2k), so the passphrase is the *only*
> thing standing between a stranger and the ability to sign APKs as
> `com.rayancouture.app`. Unlike a leaked password on a live service, there is
> no rate limit and no lockout: an attacker cracks it offline, at their own
> pace, forever. Assume the ciphertext is already in someone else's hands.
>
> **What to do, in order:**
> 1. Confirm the passphrase is long and random (a 5+ word diceware phrase or
>    32+ random characters). A human-memorable password is not sufficient here.
> 2. If it is anything weaker, treat the signing key as compromised: generate a
>    new keystore and move to Play App Signing (which lets Google hold the key
>    and makes an upload-key rotation possible).
> 3. Either way, prefer removing this file from the repo and keeping the backup
>    offline. Deleting it in a new commit does **not** remove it from history —
>    the blob stays fetchable until the history is rewritten and the repo is
>    force-pushed, or the repo is made private.
>
> The passphrase itself is **not** stored here — it lives in the owner's
> password manager, and nowhere in this repository.

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
