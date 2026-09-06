import AppKit

/// Brief feedback without taking focus away from the Chrome PR or adding notification permission.
final class FeedbackPanel {
    private var panel: NSPanel?
    private var dismissal: DispatchWorkItem?
    func show(_ message: String, error: Bool) {
        dismissal?.cancel(); panel?.close()
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let window = NSPanel(contentRect: NSRect(x: frame.maxX - 440, y: frame.maxY - 112, width: 420, height: 92),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.level = .floating; window.isOpaque = false; window.backgroundColor = .clear
        window.hasShadow = true; window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let background = NSVisualEffectView(frame: window.contentView!.bounds)
        background.material = .hudWindow; background.blendingMode = .behindWindow; background.state = .active
        background.wantsLayer = true; background.layer?.cornerRadius = 12
        let label = NSTextField(wrappingLabelWithString: message)
        label.frame = NSRect(x: 18, y: 14, width: 384, height: 64)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = error ? .systemRed : .labelColor
        label.maximumNumberOfLines = 4; background.addSubview(label)
        window.contentView = background; window.orderFrontRegardless(); panel = window
        let work = DispatchWorkItem { [weak self, weak window] in window?.close(); self?.panel = nil }
        dismissal = work; DispatchQueue.main.asyncAfter(deadline: .now() + (error ? 6 : 3), execute: work)
    }
}
