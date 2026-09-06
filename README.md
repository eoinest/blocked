# blocked

A physical button for a very specific code review style.

Open a pull request in Google Chrome. Press the key. GitHub gets a
**Request changes** review that says:

> blocked

An ESP32-S2 Mini, one mechanical switch, a printed case, and a small native Mac
menu bar app. No browser extension, cloud service, or GitHub token on the board.

![Blender enclosure concept: blocked key](enclosure/preview.png)

**Status:** initial prototype. Source, firmware, and printable enclosure files
are provided; physical assembly and an actual button-to-review test are still
required. The companion starts in dry-run mode on every launch.

Verified locally: ESP32-S2 firmware compile, button-state regression checks,
eight companion tests, a universal Intel/Apple Silicon Mac app build, and mesh
checks for the printable parts. [CI configuration](ci/) is supplied as
an inactive template because the initial publishing credentials lacked workflow
permission.

## The build

| Part | Plan |
| --- | --- |
| Controller | Your existing LOLIN-style ESP32-S2 Mini, powered by USB-C |
| Key | Gateron Baby Kangaroo 2.0 tactile switch with a custom 1.5u `blocked` keycap |
| Wiring | Two soldered wires: GPIO4 → switch → GND; internal pull-up |
| Case | 46 × 42 × 22 mm body; two M1.6 screws through dedicated PCB mounting holes; two hidden M2 case screws; brass inserts, rear USB-C cutout, recessed feet |
| Mac | Native Swift menu bar app, USB serial, Chrome Automation, existing `gh` credentials |

The board sends a debounced press over USB serial. The Mac app checks that
Google Chrome is frontmost, reads the active tab in its front window, validates
the GitHub PR URL, and runs:

```sh
gh pr review https://github.com/OWNER/REPO/pull/NUMBER --request-changes --body blocked
```

That command really posts a review. Use the app's dry-run mode during setup.
The review is authored by the account authenticated in **GitHub CLI**, which may
differ from the account signed into Chrome. GitHub's permissions and branch
rules still apply.

## Make one

1. Start with the [condensed shopping list](BOM.md) and [custom keycap order settings](keycap/README.md), then check your board against [the hardware guide](docs/hardware.md).
2. Verify the switch coupon and clip the switch into the lid using the [key mounting guide](docs/key-mounting.md). Solder the two wires, then [build and flash the firmware](firmware/README.md).
3. [Build and install the Mac companion](companion/README.md). Run `gh auth login`
   on the recipient's Mac and grant the app Automation access to Chrome.
4. Focus a PR and press the button in dry-run mode. Verify the target and body.
5. Check [component dimensions and remaining measurements](docs/component-accuracy.md), then print the insert coupons and remaining [enclosure parts](docs/enclosure.md).
   Mount the PCB through its two dedicated holes with M1.6 × 4 mm screws, then
   close the lid with two M2 × 8 mm countersunk screws. Both use brass inserts.
   Add the keycap and adhesive feet.
6. Enable live reviews in the app when ready.

The [key mounting guide](docs/key-mounting.md) covers the switch's plate clips,
reinforced lid, centred Tab keycap socket, full travel and service access.

See [the staged bring-up checklist](docs/bring-up.md) for assembly and the
physical acceptance checks. Setup needs a USB data cable, a soldering iron,
and a Mac development toolchain. The board uses no Wi-Fi.

## Customize it

The companion supports request-changes, comment, and approve review actions,
with an editable message. Its default is request-changes + `blocked`. The
enclosure is parametric so you can adjust dimensions and printer tolerances.
The initial supported browser is stable Google Chrome on macOS; the supported
GitHub host is `github.com`.

| Directory | Contents |
| --- | --- |
| [`firmware/`](firmware/) | ESP32-S2 Arduino sketch, pinned build configuration, button-state tests |
| [`companion/`](companion/) | Swift menu bar app, settings, app packaging, automated tests |
| [`enclosure/`](enclosure/) | Editable CAD, printable parts, fit coupon, preview |
| [`docs/`](docs/) | Sourced hardware research, architecture, assembly and validation |

[Architecture and alternatives](docs/architecture.md) explains why USB serial
and macOS automation were chosen. [Contributions](CONTRIBUTING.md) are welcome.

## License

MIT, including the original firmware, companion, documentation, and enclosure
design files. See [LICENSE](LICENSE).
