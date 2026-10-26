# Contributing

Build with `zsh build.sh` and run `.build/release/Shift --self-test` before submitting a change. Keep conversion logic in `Converter.swift`, drag destination geometry in `Wheel.swift`, and the app lifecycle and SwiftUI controls in `App.swift`.

## Manual drag checks

Use disposable image and PDF fixtures.

- Launch Shift and close its main window. Confirm that the menu bar icon stays available.
- Drag a file from Finder, tap Shift, move into a sector and release. Confirm that the selected conversion runs and the original is unchanged.
- Repeat from the desktop and from each display in a multiple display setup.
- Tap Shift again during a drag. Confirm that the tool wheel appears.
- Cancel outside the wheel and with Escape. Confirm that nothing is converted.
- Drag a supported batch. Confirm that every file is handled and output names do not overwrite existing files.
- Select text and tap Shift after an earlier file drag. Confirm that an old pasteboard does not reopen the wheel.
- Complete a conversion from the main window using the keyboard and verify control labels with VoiceOver.

For a bug report, include your macOS version, Mac architecture, input format, and the exact steps. Attach a small public test fixture when useful.
