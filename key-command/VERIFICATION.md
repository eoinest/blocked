# Key Command verification

Local checks on September 8, 2026:

- `swift test`: **14 tests passed, 0 failures**. Tests exercise protocol identity and UInt32 rollover, persisted per-device bindings, busy/disabled/diagnostic action gating, multiple USB ports and duplicate IDs, same-path replacement, sleep/partial-frame/burst suppression, shortcut permission/focus/held-key guards, and actual zsh execution.
- Command tests execute harmless fixtures with an isolated shell startup directory. They verify exact script handling, a working-directory path containing shell syntax, pipes/redirection, stderr and exit codes, noninteractive stdin, bounded output, timeout, pre-launch cancellation, and process-group cancellation including a TERM-ignoring descendant.
- Firmware compiled using pinned Arduino ESP32 3.3.1 for LOLIN S2 Mini: **302,342 bytes flash, 34,752 bytes global RAM**. Portable parser/button-state tests passed with address/undefined-behavior sanitizers. No board was flashed.
- Release package builds both **arm64 and x86_64**. Packaging verifies app signatures, the DMG checksum, the mounted app executable against its source, and the Applications shortcut.
- Installed and opened `/Applications/Key Command.app`. Native UI review checked both action views, command pasting/selection, and shortcut capture. Temporary drafts were cleared; no action was enabled, Accessibility approval was not granted, and no shortcut was sent to another app.
- The two-device STL was reimported into Blender: six manifold connected parts, positive volume, all on z0, minimum 6 mm spacing, 98 × 114 mm footprint. Blank-cap sockets remain open; no top or underside lettering is included.

The beta is ad-hoc signed and **not Apple-notarized**. Physical USB detection, unplug/replug with the additional boards, and actual keyboard-shortcut delivery require the new hardware and the user's macOS Accessibility approval. Unit tests verify shortcut policy but do not claim an event was accepted by a real target app. The snug USB collar and cap sockets retain their documented physical-fit requirements.
