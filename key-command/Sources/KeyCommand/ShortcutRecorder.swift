import AppKit
import KeyCommandCore

final class ShortcutRecorder: NSView {
    var shortcut: Shortcut? { didSet { needsDisplay = true } }
    private var recording = false
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { recording = true; window?.makeFirstResponder(self); needsDisplay = true }
    override func resignFirstResponder() -> Bool { recording = false; needsDisplay = true; return true }
    override func keyDown(with event: NSEvent) {
        guard recording, !event.isARepeat else { return }
        if event.keyCode == 53 { recording = false; needsDisplay = true; return }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let keyNames: [UInt16: String] = [36:"Return",48:"Tab",49:"Space",51:"Delete",76:"Enter",117:"Forward Delete",123:"←",124:"→",125:"↓",126:"↑",115:"Home",119:"End",116:"Page Up",121:"Page Down",122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",105:"F13",107:"F14",113:"F15",106:"F16",64:"F17",79:"F18",80:"F19",90:"F20"]
        let name = keyNames[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        let label = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + name
        let candidate = Shortcut(keyCode: event.keyCode, modifiers: UInt64(flags.rawValue), label: label)
        guard candidate.isValid else { return }
        shortcut = candidate; recording = false; needsDisplay = true
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }; return false
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
        path.fill(); (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke(); path.lineWidth = 2; path.stroke()
        let text = recording ? "Press your shortcut…  Esc to cancel" : shortcut?.label ?? "Click here to record a shortcut"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 20, weight: .medium), .foregroundColor: NSColor.labelColor]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: NSPoint(x: (bounds.width-size.width)/2, y:(bounds.height-size.height)/2), withAttributes: attributes)
    }
}
