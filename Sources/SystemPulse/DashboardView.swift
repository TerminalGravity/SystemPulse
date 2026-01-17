import SwiftUI

struct DashboardView: View {
    @ObservedObject var statsManager: SystemStatsManager

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient accent
            headerSection

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    // CPU & GPU side by side
                    HStack(spacing: 10) {
                        StatCard(
                            title: "CPU",
                            value: String(format: "%.1f%%", statsManager.cpuUsage),
                            icon: "cpu.fill",
                            color: colorForPercent(statsManager.cpuUsage),
                            percent: statsManager.cpuUsage
                        )
                        StatCard(
                            title: "GPU",
                            value: String(format: "%.1f%%", statsManager.gpuUsage),
                            icon: "rectangle.3.group.fill",
                            color: colorForPercent(statsManager.gpuUsage),
                            percent: statsManager.gpuUsage
                        )
                    }

                    // Memory - full width
                    StatCard(
                        title: "Memory",
                        value: "\(formatBytes(statsManager.memoryUsed)) / \(formatBytes(statsManager.memoryTotal))",
                        icon: "memorychip.fill",
                        color: colorForPercent(statsManager.memoryUsage),
                        percent: statsManager.memoryUsage
                    )

                    // Network I/O
                    HStack(spacing: 10) {
                        NetworkCard(
                            title: "Download",
                            value: formatBytesPerSec(statsManager.networkInRate),
                            icon: "arrow.down.circle.fill",
                            color: Color(red: 0.3, green: 0.6, blue: 1.0)
                        )
                        NetworkCard(
                            title: "Upload",
                            value: formatBytesPerSec(statsManager.networkOutRate),
                            icon: "arrow.up.circle.fill",
                            color: Color(red: 1.0, green: 0.6, blue: 0.3)
                        )
                    }

                    // Load Average with visual indicator
                    LoadCard(load: statsManager.loadAverage)

                    // Battery (if present)
                    if statsManager.hasBattery {
                        BatteryCard(
                            level: statsManager.batteryLevel,
                            charging: statsManager.batteryCharging
                        )
                    }

                    // Processes section
                    ProcessesCard(processes: statsManager.topProcesses)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            // Footer
            footerSection
        }
        .frame(width: 320, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("System Pulse")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(uptimeString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
    }

    private var footerSection: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .medium))
                Text("Quit")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.separatorColor).opacity(0.1))
    }

    private var uptimeString: String {
        let totalSeconds = Int(statsManager.uptime)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func colorForPercent(_ percent: Double) -> Color {
        switch percent {
        case 0..<40: return Color(red: 0.3, green: 0.8, blue: 0.4)
        case 40..<70: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case 70..<90: return Color(red: 1.0, green: 0.6, blue: 0.2)
        default: return Color(red: 1.0, green: 0.35, blue: 0.35)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1fGB", gb)
    }

    private func formatBytesPerSec(_ bytes: Double) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB/s", bytes / 1_073_741_824)
        } else if bytes >= 1_048_576 {
            return String(format: "%.1f MB/s", bytes / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.0f KB/s", bytes / 1024)
        }
        return "0 B/s"
    }
}

// MARK: - Stat Card with Gradient Progress

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let percent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            // Progress bar with gradient
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))

                    // Fill with gradient
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * min(percent, 100) / 100))
                        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            .frame(height: 6)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Network Card

struct NetworkCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Load Card

struct LoadCard: View {
    let load: (Double, Double, Double)

    private var loadColor: Color {
        let avg = load.0
        switch avg {
        case 0..<4: return Color(red: 0.3, green: 0.8, blue: 0.4)
        case 4..<8: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case 8..<12: return Color(red: 1.0, green: 0.6, blue: 0.2)
        default: return Color(red: 1.0, green: 0.35, blue: 0.35)
        }
    }

    var body: some View {
        HStack {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(loadColor)

            Text("Load")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 12) {
                LoadValue(value: load.0, label: "1m")
                LoadValue(value: load.1, label: "5m")
                LoadValue(value: load.2, label: "15m")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
    }
}

struct LoadValue: View {
    let value: Double
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text(String(format: "%.1f", value))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
    }
}

// MARK: - Battery Card

struct BatteryCard: View {
    let level: Int
    let charging: Bool

    private var batteryIcon: String {
        if charging { return "battery.100.bolt" }
        switch level {
        case 0..<20: return "battery.25"
        case 20..<50: return "battery.50"
        case 50..<80: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        if charging { return .green }
        if level < 20 { return .red }
        if level < 40 { return .orange }
        return .green
    }

    var body: some View {
        HStack {
            Image(systemName: batteryIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(batteryColor)

            Text("\(level)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            if charging {
                Text("Charging")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Processes Card

struct ProcessesCard: View {
    let processes: [SystemStatsManager.AppProcess]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Top Processes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 16) {
                    Text("CPU")
                        .frame(width: 50, alignment: .trailing)
                    Text("MEM")
                        .frame(width: 44, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()
                .padding(.horizontal, 10)

            // Process rows
            ForEach(Array(processes.prefix(6).enumerated()), id: \.element.id) { index, process in
                ProcessRow(process: process, isEven: index % 2 == 0)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
    }
}

struct ProcessRow: View {
    let process: SystemStatsManager.AppProcess
    let isEven: Bool

    private var cpuColor: Color {
        switch process.cpu {
        case 0..<25: return .secondary
        case 25..<50: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case 50..<100: return Color(red: 1.0, green: 0.5, blue: 0.2)
        default: return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    var body: some View {
        HStack {
            Text(process.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.1f%%", process.cpu))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(cpuColor)
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.1f%%", process.memory))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isEven ? Color.clear : Color.gray.opacity(0.03))
    }
}
