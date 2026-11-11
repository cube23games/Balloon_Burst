# TJ-44S — Stable Android APK signing (Termux + GitHub Actions)

**Status:** Draft, pending owner-generated private keystore and CI verification.
**Base:** TJ-44C `d9f3393d`. No change to gameplay or adaptive difficulty.

## Why this change exists

The prior release build used `signingConfigs.debug`. GitHub-hosted
Actions runners can generate a different debug certificate for each run.
Android will not install an APK with a different signing identity over an
already installed app with the same package name. Uninstalling destroys
normal private application data, including stars, money, and progress.

The future APKs for this QA channel must be signed with the **same privately
retained key** and get an **increasing versionCode** every CI run.

## Owner's phone-only setup (once)

1. In Termux, authenticate GitHub CLI as `cube23games`. Check with
   `gh auth status --hostname github.com`. If unauthenticated, run
   `gh auth login -h github.com` and complete the browser flow.
2. Install the prerequisites: `pkg install -y openjdk-17 gh curl coreutils`.
3. Download and review
   `tools/setup_qa_signing_termux.sh` from branch
   `tj-44s-stable-apk-signing`. Run it using `bash`.
4. Choose a new strong, unique password at the hidden prompt. The script
   creates `$HOME/.local/share/balloon-burst/qa-signing.p12`
   in Termux's private storage. If it already exists, it **reuses** it.
5. The script sets **four encrypted repository secrets** directly via `gh`:
   - `BB_SIGNING_KEYSTORE_B64`: base64 of the private PKCS12 file
   - `BB_SIGNING_STORE_PASSWORD`
   - `BB_SIGNING_KEY_ALIAS`
   - `BB_SIGNING_KEY_PASSWORD`
6. **Back up the keystore OFF the phone**, ideally in encrypted storage; keep
   the password separately. Never put the key, plaintext password, base64,
   recovery codes, or CLI tokens in this chat, source control, debug logs,
   unencrypted public storage, or a GitHub issue. Losing the original signing
   key means future install-over-updates cannot be signed compatibly.

The ChatGPT GitHub connector cannot configure repository secrets. They
must be created by the repo owner.

## CI behavior

- Existing Flutter World 1/UI/lead tests continue running first.
- For main and trusted same-repository PRs, CI requires all four secrets,
  fails **closed** if any are absent/invalid, and decodes the keystore into
  ephemeral runner-private storage.
- Fork PRs run tests only; they do not get signing credentials or signed APKs.
- `android/app/build.gradle` does not fall back to debug signing.
- Both public and internal QA APKs use the **same keystore and alias** with
  **the same package ID** `com.cube23.balloonburst`.
- Each workflow run uses `flutter build apk --build-number=$GITHUB_RUN_NUMBER`.
  Both artifacts from that run have the same versionCode, and later runs
  receive a larger versionCode, assuming this one CI workflow remains the
  canonical builder.
- `apksigner verify --verbose --print-certs` verifies both Android
  APKs, compares the certificate SHA-256 fingerprints; `aapt dump badging`
  checks both version codes against the workflow run number. A mismatch
  prevents either artifact from being uploaded.
- CI removes temporary key material on completion. The private key itself
  is never added to the repository.

## One final uninstall is expected

Existing TJ-44C QA APKs were signed with temporary CI debug certificates.
Unless the **exact original debug key** can be recovered, the new permanently
signed APK cannot update those installations. After the owner has securely
backed up anything possible, uninstall the old APK **once** and install the
new stable-signing QA APK. From that point, successive APKs signed with this
same key and a higher versionCode should install as updates and retain data.

**Never claim a fix until a pair of consecutive CI runs have emitted the
same certificate SHA-256 fingerprint, increasing version codes, and an
actual install-over-update has succeeded on a test device.**

## Release channel warning

This key is a long-term **internal QA APK signing** identity. The CI job
named "public release APK" presently signs using the same identity so
the two APK variants can update each other while sharing a package ID.
Do not upload to Google Play without a separate release signing and
Google Play App Signing decision. Android's signing certificate identity
and version-code continuity must be planned before public distribution.

## Security review and follow-ups

- Any trusted same-repo workflow that has access to repository secrets
  must be code-reviewed before merging; malicious code can exfiltrate
  secrets. Use least-privilege repository access.
- GitHub's encrypted secrets are **not a backup** of the keystore you
  can later read back. Preserve a secure original backup.
- Track unrelated missing "Main Menu" action in Endless RunEndOverlay in
  issue #4 rather than modifying game UI in this signing patch.

## Successful signing run #1 — 2026-11-08

GitHub Actions run [42460393482](https://github.com/cube23games/Balloon_Burst/actions/runs/42460393482) at commit
`6d05c227cff66196bf0313ad4649a49e76360f59`, workflow run number `61`, completed successfully.
All unit tests, permanent keystore preparation, both signed APK builds,
certificate SHA-256 comparison, versionCode equality, and both artifact uploads
passed. This confirms **within-run** identity only.

**Next acceptance:** Trigger another run on the identical branch, check
`GITHUB_RUN_NUMBER` rises, ensure the signer fingerprint matches the first
successful run, then install the first QA APK and update it in place using the
second. Confirm the Skyward stars and coin balance survive. Do not claim
install-over-update continuity from CI alone.
