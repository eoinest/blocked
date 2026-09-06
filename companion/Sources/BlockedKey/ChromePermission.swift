import AppKit
import Carbon

/// Permission is requested only from the setup button, never as a surprise on startup.
enum ChromePermission {
    static func check(request: Bool, completion: @escaping (Bool, String) -> Void) {
        guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") else {
            completion(false, "Install Google Chrome, then try again."); return
        }
        func determine() {
            DispatchQueue.global(qos: .userInitiated).async {
                let target = NSAppleEventDescriptor(bundleIdentifier: "com.google.Chrome")
                guard var descriptor = target.aeDesc?.pointee else {
                    DispatchQueue.main.async { completion(false, "Could not check Chrome access. Try again.") }
                    return
                }
                let status = withExtendedLifetime(target) {
                    AEDeterminePermissionToAutomateTarget(&descriptor, AEEventClass(typeWildCard), AEEventID(typeWildCard), request)
                }
                let message: String
                switch status {
                case noErr: message = "Allowed to read the focused Chrome tab"
                case OSStatus(errAEEventNotPermitted): message = "Allow Blocked → Google Chrome in System Settings → Privacy & Security → Automation."
                case OSStatus(errAEEventWouldRequireUserConsent): message = "Allow Chrome access once to find your pull request."
                case OSStatus(procNotFound): message = "Open Chrome, then allow access."
                default: message = "Chrome access needs attention (\(status)). Try again."
                }
                DispatchQueue.main.async { completion(status == noErr, message) }
            }
        }
        if request, NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty {
            let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = false
            NSWorkspace.shared.openApplication(at: chromeURL, configuration: configuration) { _, error in
                DispatchQueue.main.async {
                    if let error { completion(false, error.localizedDescription) } else { determine() }
                }
            }
        } else { determine() }
    }
}
