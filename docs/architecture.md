# How one key becomes a review

```text
MX switch ── two wires ── ESP32-S2 mini
                              │
                         USB-C / CDC serial
                              │
                       Blocked menu bar app
                              │
                  Is Google Chrome frontmost?
                              │ yes
                  Read front window's active tab
                              │
                    Validate github.com PR URL
                              │
                  gh pr review URL --request-changes
                                   --body blocked
```

The board knows about presses. The Mac knows about the browser and GitHub.
There is no Wi-Fi setup, firmware token, hosted server, or browser extension.

## Why this architecture

| Approach | What it needs | Decision |
| --- | --- | --- |
| USB CDC + native Mac app | One app with bundled gh; Chrome permission; browser sign-in if needed | Implemented. A structured press event is easy to distinguish from keyboard input. |
| USB keyboard shortcut | Global hotkey capture or keyboard automation; a reserved shortcut | Possible later, but a shortcut can conflict with another app and cannot identify the target PR by itself. |
| Chrome extension + native messaging | Extension and installed native host | Useful for more browsers or richer page context; additional installation for this gift. |
| ESP32 calling GitHub over Wi-Fi | Wi-Fi provisioning and credentials on device; still needs the active URL from the Mac | Adds setup without removing the desktop integration. |

The ESP32-S2 supports native USB device operation. Its USB data lines are GPIO19
and GPIO20, so those are reserved for USB. See the
[Espressif USB device guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32s2/api-reference/peripherals/usb_device.html).

Chrome exposes its windows, active tab, and tab URL in its
[AppleScript dictionary](https://chromium.googlesource.com/chromium/src.git/+/lkgr/chrome/browser/ui/cocoa/applescript/scripting.sdef).
The app first checks macOS's frontmost application. It must not select a stale
Chrome window when the user is working in a different app. With multiple Chrome
windows, the target is the active tab in Chrome's front window.
Read-only Apple events address the captured foreground process ID directly;
bundle-ID lookup can select an unrelated background Chrome automation process.

macOS asks the user to let Blocked automate Chrome; the app includes an
[Apple Events usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription).
Reading the URL does not require enabling Chrome's “Allow JavaScript from Apple
Events” setting. This integration does not read page content or passwords.

The companion passes the validated URL and review body as separate process
arguments to [GitHub CLI](https://cli.github.com/manual/gh_pr_review). It uses the
account already authenticated with GitHub CLI, or connects it through the app's
browser device-code flow. The Chrome website login can
be a different account: the review is always authored by the **CLI account**.
GitHub still enforces review permissions and repository rules. A request-changes
review's effect on merging depends on those rules; the button does not create
a branch protection rule.

## Behavior and limits

- Complete account/Chrome setup and enable once; remember enable/pause across
  restarts. Offer a one-press diagnostic that never submits a review.
- Require a fresh button press, the identified serial protocol, an eligible PR
  URL, and Google Chrome as the frontmost app.
- Never submit a review merely because the device is connected or a key is held
  during connection. Debounce mechanical bounce and reject repeated events.
- Ignore presses during an in-flight operation. Do not build a queue of reviews.
- Treat a failed or timed-out network request as uncertain; do not retry it
  automatically. Check GitHub before pressing again.
- The first version targets macOS, stable Google Chrome, and `github.com`.
  Enterprise hosts and other browsers need an explicit implementation.
- USB/Apple Events/network operations are not an atomic snapshot. A tab or PR
  can change during a request; the software reduces that window but cannot make
  an already submitted GitHub request disappear.

For settings, installation, and implementation details see
[the companion README](../companion/README.md). For the exact wire protocol see
[the firmware](../firmware/).
