import SwiftUI
import AppKit

@main
struct SystemPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var statsManager = SystemStatsManager()
    @StateObject private var claudeManager = ClaudeCodeManager()
    @StateObject private var licenseManager = LicenseManager.shared

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(statsManager)
                .environmentObject(claudeManager)
                .environmentObject(licenseManager)
                .onAppear {
                    // Share managers with AppDelegate
                    appDelegate.statsManager = statsManager
                    appDelegate.claudeManager = claudeManager
                    appDelegate.licenseManager = licenseManager
                    // Start updates
                    statsManager.refresh()
                    claudeManager.refresh()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var statsManager: SystemStatsManager!
    var claudeManager: ClaudeCodeManager!
    var licenseManager: LicenseManager!
    var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Regular app - shows in dock AND menubar
        NSApp.setActivationPolicy(.regular)

        // Use shared instance if not already set by App struct
        if licenseManager == nil { licenseManager = LicenseManager.shared }
        if statsManager == nil { statsManager = SystemStatsManager() }
        if claudeManager == nil { claudeManager = ClaudeCodeManager() }

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
        claudeManager.refresh()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When dock icon is clicked, show or create main window
        if !flag {
            for window in NSApp.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(self)
                    return true
                }
            }
        }
        return true
    }

    @objc func licenseStatusChanged() {
        updatePopoverContent()
        if licenseManager.isLicensed {
            startUpdateTimer()
        }
    }

    func updatePopoverContent() {
        if licenseManager.isLicensed {
            popover.contentSize = NSSize(width: 320, height: 520)
            popover.contentViewController = NSHostingController(
                rootView: DashboardView(statsManager: statsManager, claudeManager: claudeManager)
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
            self?.claudeManager.refresh()
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
                claudeManager.refresh()
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
