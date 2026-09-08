# Sharing the macOS app

`companion/scripts/package-release.sh` creates one DMG containing `Blocked.app`, an Applications shortcut, and recipient instructions. The app includes the pinned GitHub CLI for Intel and Apple Silicon; recipients need macOS 13 or newer, Chrome, and their own GitHub account. They can install and complete setup without Terminal or Homebrew. The physical button must already have compatible firmware.

## Private beta

After the app's source changes and tests are complete, run from the repository root:

```sh
companion/scripts/package-release.sh --offline
```

`--offline` uses the existing verified GitHub CLI archive cache. Omit it to allow missing archives to download. The script builds a fresh universal app, verifies its bundled executable and license, checks code signatures, then mounts the finished DMG read-only to check its contents. Only generated app files and the checked-in recipient text are staged; no Keychain items, GitHub configuration, or app preferences are copied.

The output is `companion/dist/Blocked-0.3.0-beta.dmg`, with a SHA256 sidecar. Send the DMG itself. The beta uses ad-hoc signing by default and is **not Apple-notarized**. After trying to launch it, a recipient may need **System Settings → Privacy & Security → Open Anyway**. Managed Macs may prohibit that exception. See [Apple's first-open guidance](https://support.apple.com/en-us/102445). The current development machine has an Apple Development identity, which is not a Developer ID Application distribution identity.

The recipient drags the app into Applications and opens it there, signs in to GitHub, grants Chrome automation access, and optionally enables Open at Login. Existing sender sign-in state does not transfer. A beta DMG does not establish that Gatekeeper will accept the app on a fresh Mac; first-run setup and USB operation still require a recipient-machine test.

The 0.3.0 beta was built successfully with cached dependencies. Its mounted root contained exactly `Blocked.app`, `Applications`, and `Start Here.txt`. Both the app and bundled GitHub CLI passed Intel/Apple Silicon architecture checks; the delivered app passed strict signature verification and included its icon and both licenses. The DMG is 34,542,941 bytes. No notarization was requested or performed; its SHA256 is recorded beside it in `Blocked-0.3.0-beta.dmg.sha256`.

## Developer ID and notarization

For a future public release, obtain a **Developer ID Application** certificate and create a `notarytool` Keychain credential profile separately. Once those exist, explicitly request signing and notarization:

```sh
companion/scripts/package-release.sh --offline \
  --sign 'Developer ID Application: YOUR NAME (TEAMID)' \
  --notarize-profile YOUR_PROFILE
```

Add `--notary-keychain /path/to/your.keychain-db` only when the credential profile is stored in a specific Keychain. Credentials are read by Apple's tool; they are not command arguments or package contents. `--offline` only affects dependency downloads: an explicit notarization request uploads the app and DMG to Apple.

The script signs the nested GitHub CLI and app with hardened runtime and secure timestamps, submits the app archive, requires an `Accepted` response, staples and validates its ticket, then creates and notarizes the DMG. It also assesses the stapled app and DMG with Gatekeeper. A failed submission, timeout, rejected status, stapling failure, or verification failure aborts before publishing a new final DMG. Existing output from an earlier run remains unchanged; submission JSON is retained in `companion/dist/` for diagnosis.

Successful notarization produces `companion/dist/Blocked-0.3.0.dmg`. Using `--sign` alone still produces the `-beta` filename because it has not been notarized. The optional notarization path is implemented but has not been exercised with a distribution certificate or uploaded to Apple during this work. See [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
