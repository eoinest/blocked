# Key Command

A separate macOS app that turns each ESP32-S2 button into a **shell command or keyboard shortcut**. Assign different actions to different buttons; each assignment follows the board's stable chip ID when USB paths change. It has its own app bundle, preferences, firmware identity and source package. The existing Blocked app remains independent.

## Install and use

1. Open `dist/KeyCommand-0.1.0-beta.dmg`, drag **Key Command.app** to Applications, and launch it. This beta is ad-hoc signed, not Apple-notarized; the included Start Here file explains the first-open step.
2. Flash additional boards with [Key Command firmware](../firmware/key_command/README.md). The original Blocked firmware is a different product and is not automatically converted. Wire each normally-open switch between GPIO 4 and GND.
3. Plug in a board using a USB data cable. Give it a name, choose **Shell command** or **Keyboard shortcut**, configure the action and enable it. New boards start disabled.
4. For shortcuts, explicitly grant Key Command Accessibility access. Pressing the physical button sends the shortcut to the app currently in focus. Shell-only use does not require Accessibility.
5. Leave Key Command running in the menu bar. Enable **Open at login** for automatic startup. Normal USB reconnection needs no reset-button presses or repeated configuration.

The recipient needs the app and a pre-flashed button. No GitHub login, Chrome extension, Homebrew or Swift installation is needed to run the app. Commands can of course depend on tools the recipient has chosen to install.

## Shell commands

Commands run with your macOS user's permissions through `/bin/zsh -lc`. Enter a command or script and choose its working directory. Use absolute executable paths when a tool is not on the configured PATH. Shell expansions, pipes and redirections work because this is an intentional command runner.

A harmless first check:

```sh
/usr/bin/say 'Button connected'
```

The app shows completion status and bounded output, provides a timeout and cancellation, and drops repeated presses while that button's action is running. Commands read from `/dev/null` rather than an interactive terminal. Commands requiring a password prompt or a full interactive terminal need a different workflow. Only configure commands you intend to execute; commands and output are local user data, never bundled into the DMG.

## Keyboard shortcuts

Record the shortcut in the app. A physical press sends a balanced key-down/key-up pair with the chosen modifiers to the focused application. The manual shortcut test provides time to switch to the target app. macOS Accessibility approval is requested only when you choose to grant it; the app does not change system permissions itself.

Keyboard layouts, secure text fields and reserved system shortcuts can affect whether a target accepts a synthesized shortcut. Confirm the actual target app's behavior. This mode does not type a shell command into a terminal.

## Connection behavior

- Only USB devices named **Key Command**, using the Espressif development-board VID, are candidates.
- A separate versioned handshake identifies each board by 12 uppercase hexadecimal characters.
- Multiple connected boards have independent assignments and connection state.
- Duplicate, malformed, unhandshaken and buffered burst events do not run actions.
- Reconnection and a pause after sleep start a fresh handshake; held buttons must be released before another action can fire.
- USB identity associates settings with hardware; it is not cryptographic authentication.

## Build and package

Requires macOS 13+ and the Xcode command-line tools. There are no external Swift package dependencies.

```sh
cd key-command
swift test
./scripts/build-app.sh
./scripts/package-release.sh
```

The scripts create a universal **arm64 + x86_64** app and a verified DMG with an Applications shortcut. They do not modify `/Applications` or flash boards. Artifacts are in `key-command/dist/` and excluded from Git.

For a Developer ID signed and notarized release, with your existing signing identity and Keychain notary profile:

```sh
./scripts/package-release.sh \
  --sign 'Developer ID Application: Your Name (TEAMID)' \
  --notarize-profile YOUR_EXISTING_PROFILE
```

No notarization upload occurs unless that option is supplied. Ad-hoc beta signing does not provide Apple notarization or stable Developer ID permission continuity across builds.

## Hardware and printing

The [two-button print plate](../docs/two-button-print.md) contains two copies of the latest enclosure and two blank Tab caps. The socket-hugging USB collar is still conditional on the actual board and seated cable; follow the [USB fit procedure](../docs/usb-fit.md) before committing to the complete print.

The [firmware guide](../firmware/key_command/README.md) covers build, explicit-port upload and protocol diagnostics. Firmware compilation and simulated transport tests do not replace physical tests with the additional boards.

## Platform references

Apple documents [Accessibility trust](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) and [main-app login registration](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp). These system controls are separate from per-button action settings.

MIT licensed; see [LICENSE](../LICENSE).
