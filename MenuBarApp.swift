// WifiCity AutoLogin: menu bar app. Auto-login is on while the app runs; quitting turns it off.
// It checks on launch, on every network change and wake, and every 15 seconds, using the
// bundled `wificity` script, which detects the portal and signs in.
import AppKit
import Network

let home = FileManager.default.homeDirectoryForCurrentUser.path
let appDir = home + "/Library/Application Support/WifiCityAutoLogin"
let script = appDir + "/wificity"
let stateDir = appDir + "/state"
let logPath = home + "/Library/Logs/WifiCityAutoLogin.log"

func readState(_ name: String) -> String {
    ((try? String(contentsOfFile: stateDir + "/" + name, encoding: .utf8)) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    let menu = NSMenu()
    let statusLine = NSMenuItem(title: "Checking…", action: nil, keyEquivalent: "")
    let lastLoginLine = NSMenuItem(title: "Not signed in by the app yet", action: nil, keyEquivalent: "")
    var timer: Timer?
    let monitor = NWPathMonitor()
    let runner = DispatchQueue(label: "wificity.runner")   // serial: one check at a time
    var busy = false
    var pending: String?

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon("wifi.circle", "Checking…")

        let header = NSMenuItem(title: "WifiCity Auto-Login is on", action: nil, keyEquivalent: "")
        header.isEnabled = false
        statusLine.isEnabled = false
        lastLoginLine.isEnabled = false
        menu.addItem(header)
        menu.addItem(statusLine)
        menu.addItem(lastLoginLine)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Connect now", action: #selector(connectNow), keyEquivalent: "r")
        menu.addItem(withTitle: "Log out & Quit…", action: #selector(logOutAndQuit), keyEquivalent: "")
        menu.addItem(withTitle: "Open log", action: #selector(openLog), keyEquivalent: "l")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        for i in menu.items { i.target = self }
        item.menu = menu

        check("app opened")   // opening the app usually means "connect me now"
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.check(nil) }
        monitor.pathUpdateHandler = { [weak self] _ in DispatchQueue.main.async { self?.check("network change") } }
        monitor.start(queue: .global(qos: .utility))
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func setIcon(_ symbol: String, _ tip: String) {
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
            ?? NSImage(systemSymbolName: "wifi", accessibilityDescription: tip)
        img?.isTemplate = true
        item.button?.image = img
        item.button?.toolTip = "WifiCity Auto-Login: " + tip
    }

    func runScript(_ args: [String], then: @escaping () -> Void) {
        runner.async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [script] + args
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
            DispatchQueue.main.async(execute: then)
        }
    }

    func check(_ reason: String?) {
        if busy { pending = pending ?? reason ?? ""; return }   // merge bursts of triggers into one check
        busy = true
        runScript(["run"] + (reason.map { [$0] } ?? [])) { [weak self] in
            guard let self else { return }
            self.busy = false
            self.refresh()
            if let next = self.pending { self.pending = nil; self.check(next.isEmpty ? nil : next) }
        }
    }

    func refresh() {
        let (symbol, text): (String, String)
        switch readState("status") {
        case "online":       (symbol, text) = ("wifi.circle.fill", "Online")
        case "portal":       (symbol, text) = ("exclamationmark.circle", "Signing in…")
        case "no network":   (symbol, text) = ("wifi.slash", "No network")
        case "other portal": (symbol, text) = ("questionmark.circle", "Another network's login page, ignored")
        default:             (symbol, text) = ("wifi.circle", "Checking…")
        }
        setIcon(symbol, text)
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        statusLine.title = "\(text) · checked \(time)"
        let last = readState("last-login")
        lastLoginLine.title = last.isEmpty ? "Not signed in by the app yet" : "Last auto-login: \(last)"
    }

    @objc func didWake() { check("wake from sleep") }
    @objc func connectNow() { check("Connect now") }
    @objc func openLog() { NSWorkspace.shared.open(URL(fileURLWithPath: logPath)) }
    @objc func quit() { NSApp.terminate(nil) }

    @objc func logOutAndQuit() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Log out of WifiCity and quit?"
        a.informativeText = "You will be signed out of the Wi-Fi portal and auto-login will turn off. Open WifiCity AutoLogin again to sign back in."
        a.addButton(withTitle: "Log out & Quit")
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        // Stop every trigger first so nothing signs straight back in.
        timer?.invalidate()
        monitor.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        pending = nil
        setIcon("wifi.slash", "Logging out…")
        // The serial queue lets any check in progress finish before signing out.
        runScript(["logout"]) { NSApp.terminate(nil) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
app.run()
