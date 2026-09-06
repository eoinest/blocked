import AppKit

/// First-run setup UI. Authentication and device work are supplied by the app.
final class SetupWindow: NSWindowController {
    var onConnectGitHub: (() -> Void)?
    var onAllowChrome: (() -> Void)?
    var onEnable: ((Bool) -> Void)?
    var onCancelSignIn: (() -> Void)?

    private let githubStatus = SetupWindow.text("Connect the GitHub account that will post your reviews.")
    private let chromeStatus = SetupWindow.text("Allow Blocked to read the active tab in your focused Chrome window.")
    private let buttonStatus = SetupWindow.text("Plug in your Blocked button when you are ready. You can finish setup first.")
    private let messageLabel = SetupWindow.text("")
    private let explanationLabel = SetupWindow.text("")
    private let codeLabel = NSTextField(labelWithString: "")
    private let codeRow = NSStackView()
    private let githubButton = NSButton(title: "Connect GitHub", target: nil, action: nil)
    private let chromeButton = NSButton(title: "Allow Chrome", target: nil, action: nil)
    private let enableButton = NSButton(title: "Enable Blocked", target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: "Open Blocked when I log in", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set up Blocked"
        window.minSize = NSSize(width: 520, height: 620)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        updateAction("Request changes", body: "blocked")
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("SetupWindow is created programmatically")
    }

    func updateGitHub(_ text: String, code: String? = nil) {
        githubStatus.stringValue = text
        let visibleCode = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        codeLabel.stringValue = visibleCode
        codeRow.isHidden = visibleCode.isEmpty
    }

    func updateChrome(_ text: String, allowed: Bool) {
        chromeStatus.stringValue = text
        chromeButton.title = allowed ? "Allowed" : "Allow Chrome"
        chromeButton.isEnabled = !allowed
    }

    func updateButton(_ text: String) {
        buttonStatus.stringValue = text
    }

    func updateAction(_ title: String, body: String) {
        let message = body.isEmpty ? "" : " with the message “\(body)”"
        explanationLabel.stringValue = "Pressing your physical button posts a “\(title)” review\(message) on the pull request in your focused Chrome tab, using your connected GitHub account."
    }

    func setReady(_ ready: Bool) {
        enableButton.isEnabled = ready
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        loginCheckbox.state = enabled ? .on : .off
    }

    func showMessage(_ text: String) {
        messageLabel.stringValue = text
        messageLabel.isHidden = text.isEmpty
    }

    private static func text(_ value: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: value)
        field.font = .systemFont(ofSize: 13)
        field.textColor = .secondaryLabelColor
        field.maximumNumberOfLines = 0
        field.lineBreakMode = .byWordWrapping
        field.isSelectable = true
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        return field
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        let document = SetupDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document
        document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor).isActive = true
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])

        let title = NSTextField(labelWithString: "Set up Blocked")
        title.font = .systemFont(ofSize: 25, weight: .semibold)
        stack.addArrangedSubview(title)

        stack.addArrangedSubview(explanationLabel)
        explanationLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        configureAction(githubButton, action: #selector(connectGitHub))
        configureAction(chromeButton, action: #selector(allowChrome))
        configureAction(enableButton, action: #selector(enable))
        enableButton.isEnabled = false
        enableButton.keyEquivalent = "\r"

        let githubSection = section("GitHub", status: githubStatus, action: githubButton)
        codeRow.orientation = .horizontal
        codeRow.alignment = .centerY
        codeRow.spacing = 14
        codeRow.isHidden = true
        codeLabel.font = .monospacedSystemFont(ofSize: 25, weight: .semibold)
        codeLabel.isSelectable = true
        codeLabel.setAccessibilityLabel("GitHub device code")
        let copyButton = NSButton(title: "Copy code", target: self, action: #selector(copyCode))
        copyButton.bezelStyle = .rounded
        codeRow.addArrangedSubview(codeLabel)
        codeRow.addArrangedSubview(copyButton)
        let cancelButton = NSButton(title: "Cancel sign-in", target: self, action: #selector(cancelSignIn))
        cancelButton.bezelStyle = .rounded
        codeRow.addArrangedSubview(cancelButton)
        githubSection.addArrangedSubview(codeRow)

        for view in [githubSection, section("Chrome", status: chromeStatus, action: chromeButton),
                     section("Button", status: buttonStatus, action: nil)] {
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let separator = NSBox()
        separator.boxType = .separator
        stack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        loginCheckbox.state = .on
        stack.addArrangedSubview(loginCheckbox)
        messageLabel.isHidden = true
        stack.addArrangedSubview(messageLabel)
        messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.addArrangedSubview(enableButton)
    }

    private func section(_ title: String, status: NSTextField, action: NSButton?) -> NSStackView {
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 14, weight: .semibold)
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.addArrangedSubview(heading)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        if let action { row.addArrangedSubview(action) }
        let result = NSStackView(views: [row, status])
        result.orientation = .vertical
        result.alignment = .leading
        result.spacing = 7
        row.widthAnchor.constraint(equalTo: result.widthAnchor).isActive = true
        status.widthAnchor.constraint(equalTo: result.widthAnchor).isActive = true
        return result
    }

    private func configureAction(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @objc private func connectGitHub() { onConnectGitHub?() }
    @objc private func allowChrome() { onAllowChrome?() }
    @objc private func enable() { onEnable?(loginCheckbox.state == .on) }
    @objc private func cancelSignIn() { onCancelSignIn?() }

    @objc private func copyCode() {
        guard !codeLabel.stringValue.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codeLabel.stringValue, forType: .string)
    }
}

private final class SetupDocumentView: NSView {
    override var isFlipped: Bool { true }
}
