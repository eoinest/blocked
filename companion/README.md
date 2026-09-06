# Blocked for macOS

A small native menu bar app connects the USB button to the pull request in the active Google Chrome window. No browser extension or injected JavaScript is needed. The default review is **Request changes**, with the body **blocked**.

## Build and install

Requires macOS 13 or later, Xcode with Swift 5.9 or later and its command line tools selected, Google Chrome, and [GitHub CLI](https://cli.github.com/). The build has no third-party Swift dependencies. The packaging script produces a universal app for Apple Silicon and Intel Macs. The universal build uses Xcode's build system; a plain `swift build` can build just the host architecture with Command Line Tools alone.

```sh
# From the repository root:
cd companion
swift test
./scripts/build-app.sh
open dist/Blocked.app
```

Copy `dist/Blocked.app` to `/Applications` if you want to keep it there. In Terminal, run `gh auth login --hostname github.com` if you are not already signed in, and `gh auth status --hostname github.com` to check the account the button will use. The companion uses gh's existing authentication; it does not collect or store a token. A standard Homebrew install is detected at `/opt/homebrew/bin/gh` or `/usr/local/bin/gh`; another absolute executable path can be entered in Settings.

The script signs locally with an ad-hoc signature and a stable bundle ID (`io.github.eoinest.blocked`). This is a source-built prototype, not a notarized download. For distribution to someone else's Mac, use your Developer ID through `SIGNING_IDENTITY` and Apple's signing/notarization workflow, or build from source on that Mac. A new ad-hoc build may require granting Automation access again. No installation or login-item changes happen automatically.

## First use

1. Flash the firmware and connect the button with a **data-capable USB cable**. Close Arduino Serial Monitor first. The ▣ menu should say **Button connected**.
2. Open a pull request on `https://github.com` in Google Chrome and leave that Chrome window focused.
3. Press and release the button. macOS may ask whether Blocked can control Chrome; allow it. The first press is intentionally discarded if the permission dialog takes too long. Refocus Chrome and press again.
4. In the ▣ menu, choose **Last result…** to see the dry-run action, exact PR URL, and body. A dry run never invokes `gh`.
5. Choose **Arm live reviews…** and acknowledge the displayed action and message. Refocus Chrome, then press the button to post. Check the PR to confirm the account and review.

Every launch starts in dry run. **Disarm live reviews** returns to dry run immediately. Settings offers request changes, comment review, or approve, plus a custom message. Saving settings also disarms. These are GitHub PR reviews: “Comment review” is not an issue comment. Only one companion instance should run at a time.

Chrome must be the frontmost application at the moment the app handles the press. Opening the Blocked menu/settings means Chrome is no longer the target. Blocked accepts conversation, files, commits, and checks views of a pull request. It ignores URL query strings and anchors when forming the canonical review URL. Enterprise domains, other browsers, issues, arbitrary subpaths, and commit-specific views are intentionally unsupported in this first version.

Errors appear in **Last result…** and sound the system beep. macOS permissions can be adjusted in **System Settings → Privacy & Security → Automation → Blocked → Google Chrome**. Accessibility, Input Monitoring, and Chrome's “Allow JavaScript from Apple Events” are not needed. If serial discovery fails on a clone, identify its `/dev/cu.*` path and set **Serial port** explicitly; this still requires the firmware identity handshake. Never select another device's port.

## What happens on a press

`USB CDC → identity + sequence check → foreground Chrome + active tab → strict PR URL parser → gh pr review`

The app uses `NSWorkspace.frontmostApplication` and a fixed AppleScript to read Chrome's front-window ID, active-tab ID, and URL. It reads twice, requires matching results, and rejects reads taking one second or more. It then launches `gh` with a separate argument array, without a shell. The operation targets the captured PR URL. A tab switch after `gh` starts cannot recall the already-started network request.

There is no press queue. Busy presses, bursts, duplicate sequence numbers, data delayed by a blocked run loop/sleep, and presses inside the two-second debounce window are discarded. A live attempt reserves that PR for sixty seconds, including failures. `gh` has a twenty-second timeout and is never retried automatically: a timeout may mean GitHub received the review but its response was lost. Check the PR before trying again. GitHub may reject self-reviews, closed PRs, or reviews the signed-in account cannot submit; those errors are shown as returned by gh.

No PR URL or review body is persisted by Blocked, except the configured message in macOS preferences. The latest result stays in memory. Subprocess output uses a private temporary directory removed on completion. User-supplied custom `gh` paths must point to an executable you trust.

## USB protocol v1

CDC serial, 115200 baud, 8 data bits, no parity, one stop bit, no hardware flow control. The host asserts **both DTR and RTS** because the ESP32 Arduino CDC connection implementation requires both. The firmware's USB product name is `Blocked Key`, using Espressif's vendor ID `0x303a` and the LOLIN S2 Mini's existing product ID `0x80c2`. Automatic discovery filters by vendor and product name; an explicitly configured `/dev/cu.*` port bypasses discovery only.

```text
host → board: HELLO\n
board → host: BLOCKED_KEY 1\n
board → host: PRESS 1\n
board → host: PRESS 2\n
host → board: RESULT DRY_RUN\n
host → board: RESULT OK\n
host → board: RESULT ERROR\n
```

Identity is a version/compatibility check, not cryptographic authentication. Sequence numbers must increase within a connection. A new connection starts a fresh session and flushes input. The host retries HELLO while awaiting identity; repeated identity responses do not reset the host's sequence check. The board requires a debounced release after handshaking before emitting a new press; holding the key while plugging it in cannot submit a review. Result lines are optional feedback and can be ignored by the board.

## Verification

`swift test` covers URL boundaries and canonicalization, argument integrity with hostile-looking message text, handshake/dedup behavior, in-flight and cooldown gates, and real subprocess success/failure/timeout using a fake local gh. These tests make no network calls and never submit reviews.

The Swift app and packaging can be built without hardware. Real USB enumeration, DTR/RTS behavior, switch presses, first-run macOS Automation permission, and a deliberately authorized test review still need checking on the intended Mac and board. See the root bring-up instructions.

## Primary references

- [Apple: frontmostApplication](https://developer.apple.com/documentation/appkit/nsworkspace/frontmostapplication)
- [Chromium: AppleScript support](https://www.chromium.org/developers/design-documents/applescript/) — installed Chrome's `Contents/Resources/scripting.sdef` additionally declares `active tab`, `URL`, and window/tab IDs.
- [Apple: NSAppleEventsUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription)
- [Apple: Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events)
- [GitHub CLI: gh pr review](https://cli.github.com/manual/gh_pr_review)
- [ESP32 Arduino: LOLIN board definitions](https://github.com/espressif/arduino-esp32/blob/3.3.1/boards.txt) and [USB CDC implementation](https://github.com/espressif/arduino-esp32/blob/3.3.1/cores/esp32/USBCDC.cpp)
