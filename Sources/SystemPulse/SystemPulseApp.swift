import SwiftUI
import AppKit

@main
struct SystemPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var statsManager: SystemStatsManager!
    var licenseManager: LicenseManager!
    var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        licenseManager = LicenseManager.shared
        statsManager = SystemStatsManager()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateMenuBarIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        updatePopoverContent()

        // Watch for license changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(licenseStatusChanged),
            name: NSNotification.Name("LicenseStatusChanged"),
            object: nil
        )

        // Start timer only if licensed
        if licenseManager.isLicensed {
            startUpdateTimer()
        }

        statsManager.refresh()
    }

    @objc func licenseStatusChanged() {
        updatePopoverContent()
        if licenseManager.isLicensed {
            startUpdateTimer()
        }
    }

    func updatePopoverContent() {
        if licenseManager.isLicensed {
            popover.contentSize = NSSize(width: 320, height: 500)
            popover.contentViewController = NSHostingController(
                rootView: DashboardView(statsManager: statsManager)
            )
        } else {
            popover.contentSize = NSSize(width: 280, height: 380)
            popover.contentViewController = NSHostingController(
                rootView: LicenseView(licenseManager: licenseManager)
            )
        }
    }

    func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.statsManager.refresh()
            self?.updateMenuBarIcon()
        }
    }

    func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        let color: NSColor
        if !licenseManager.isLicensed {
            color = .systemGray
        } else {
            let cpu = statsManager.cpuUsage
            if cpu < 50 {
                color = .systemGreen
            } else if cpu < 80 {
                color = .systemYellow
            } else {
                color = .systemRed
            }
        }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [color]))

        button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "System Pulse")?
            .withSymbolConfiguration(config)

        if licenseManager.isLicensed {
            button.toolTip = String(format: "CPU: %.0f%% | MEM: %.0f%%", statsManager.cpuUsage, statsManager.memoryUsage)
        } else {
            button.toolTip = "System Pulse - Click to activate"
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            if licenseManager.isLicensed {
                statsManager.refresh()
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
