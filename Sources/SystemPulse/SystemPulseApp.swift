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
    var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statsManager = SystemStatsManager()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateMenuBarIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DashboardView(statsManager: statsManager))

        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.statsManager.refresh()
            self?.updateMenuBarIcon()
        }

        statsManager.refresh()
    }

    func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        let cpu = statsManager.cpuUsage
        let color: NSColor

        if cpu < 50 {
            color = .systemGreen
        } else if cpu < 80 {
            color = .systemYellow
        } else {
            color = .systemRed
        }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [color]))

        button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "System Pulse")?
            .withSymbolConfiguration(config)

        button.toolTip = String(format: "CPU: %.0f%% | MEM: %.0f%%", cpu, statsManager.memoryUsage)
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            statsManager.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
