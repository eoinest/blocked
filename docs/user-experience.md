# Install, plug in, press

The recipient gets an assembled, pre-flashed button and one Mac app. They should
never need Arduino, Xcode, Homebrew, a terminal, a serial-port name, or a GitHub
token pasted into settings.

## First use

Install/open Blocked → connect GitHub if necessary → allow Chrome access →
enable the button → plug it in → press on a Chrome PR.

Setup explains the exact action and identifies the GitHub account before enabling
it. Existing GitHub CLI credentials are reused. Otherwise the app shows a device
code and opens GitHub's authorization page. GitHub's page identifies the client
as GitHub CLI; no separate Blocked OAuth app is registered. Chrome's macOS
Automation consent cannot be bypassed. Startup at login is visible and optional.

## Everyday use

- Plugging in connects automatically. A held key or reconnect never submits.
- A fresh press on the focused Chrome PR sends the configured review. The default
  is **Request changes**, body **blocked**.
- Brief feedback confirms success or explains a failure without stealing focus.
- Enable/pause is remembered across restarts. No per-launch rearming or per-review
  confirmation is required. The menu exposes Pause and the full last result.
- Custom actions and troubleshooting overrides live in Settings. Changing them
  asks the user to enable the new configuration once.
- Firmware flashing and RESET/BOOT access are the maker's service tasks, not
  recipient onboarding. Ship it flashed, with a known data cable.

## Implemented versus still to prove

| Part | State |
| --- | --- |
| Native setup window, account display, device-code sign-in | Implemented; fake-process tests and native layout check pass |
| GitHub helper included for Intel and Apple Silicon | Implemented, pinned official binaries and checksums, MIT notices included |
| Remember enable/pause; automatic USB rediscovery | Implemented; activation/protocol logic tested; real hardware reconnect still pending |
| Optional launch at login | Implemented using SMAppService; actual registration/approval on recipient Mac not tested |
| Nonactivating success/error feedback | Implemented; full Chrome-focus interaction still needs live validation |
| Chrome permission and front-window/tab reader | Implemented; live foreground-window smoke test remains unresolved on this host |
| Signed, notarized downloadable installer | Not yet produced; current build uses ad-hoc signing |
| Clean Mac with no gh, existing-gh Mac, revoked permissions, restart/wake, USB reconnect and one authorized real review | Acceptance testing still required |

The development scripts build the app; they do not register login items, sign in,
submit reviews or publish a release. Tests do not alter the user's GitHub account.

Primary platform references: [Apple main-app login service](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp),
[Apple registration/approval](https://developer.apple.com/documentation/servicemanagement/smappservice/register()),
[GitHub CLI device-flow implementation](https://github.com/cli/cli/blob/v2.100.0/internal/authflow/flow.go),
[GitHub CLI release provenance](../companion/ThirdPartyNotices/GitHubCLI.md).
