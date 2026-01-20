import SwiftUI
import Charts

struct MainWindowView: View {
    @EnvironmentObject var statsManager: SystemStatsManager
    @EnvironmentObject var claudeManager: ClaudeCodeManager
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var selectedTab: MainTab = .system

    enum MainTab: String, CaseIterable {
        case system = "System"
        case claude = "Claude"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom title bar
            titleBar

            Divider()

            // Main content
            if licenseManager.isLicensed {
                TabView(selection: $selectedTab) {
                    AdvancedSystemView(statsManager: statsManager)
                        .tabItem {
                            Label("System", systemImage: "cpu")
                        }
                        .tag(MainTab.system)

                    AdvancedClaudeView(claudeManager: claudeManager)
                        .tabItem {
                            Label("Claude", systemImage: "terminal")
                        }
                        .tag(MainTab.claude)
                }
            } else {
                LicenseView(licenseManager: licenseManager)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var titleBar: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("System Pulse")
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            Spacer()

            if licenseManager.isTrialActive {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 12))
                    Text("\(licenseManager.trialDaysRemaining) days left in trial")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.15))
                )
            }

            // Live stats in title
            HStack(spacing: 12) {
                MiniStat(icon: "cpu", value: String(format: "%.0f%%", statsManager.cpuUsage), color: .green)
                MiniStat(icon: "memorychip", value: String(format: "%.0f%%", statsManager.memoryUsage), color: .blue)
                MiniStat(icon: "clock", value: formatUptime(statsManager.uptime), color: .secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func formatUptime(_ interval: TimeInterval) -> String {
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct MiniStat: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Advanced System View

struct AdvancedSystemView: View {
    @ObservedObject var statsManager: SystemStatsManager
    @State private var cpuHistory: [DataPoint] = []
    @State private var memoryHistory: [DataPoint] = []
    @State private var networkInHistory: [DataPoint] = []
    @State private var networkOutHistory: [DataPoint] = []
    @State private var historyTimer: Timer?

    struct DataPoint: Identifiable {
        let id = UUID()
        let time: Date
        let value: Double
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Real-time Graphs Row
                HStack(spacing: 16) {
                    // CPU Graph
                    GraphCard(
                        title: "CPU Usage",
                        currentValue: String(format: "%.1f%%", statsManager.cpuUsage),
                        data: cpuHistory,
                        color: .green,
                        icon: "cpu.fill"
                    )

                    // Memory Graph
                    GraphCard(
                        title: "Memory Usage",
                        currentValue: String(format: "%.1f%%", statsManager.memoryUsage),
                        data: memoryHistory,
                        color: .blue,
                        icon: "memorychip.fill"
                    )
                }
                .frame(height: 180)

                // Network Graph
                NetworkGraphCard(
                    inHistory: networkInHistory,
                    outHistory: networkOutHistory,
                    currentIn: statsManager.networkInRate,
                    currentOut: statsManager.networkOutRate
                )
                .frame(height: 160)

                // System Details Row
                HStack(spacing: 16) {
                    // Memory Breakdown
                    MemoryBreakdownCard(
                        used: statsManager.memoryUsed,
                        total: statsManager.memoryTotal
                    )

                    // Load & Battery
                    VStack(spacing: 16) {
                        LoadDetailCard(load: statsManager.loadAverage)

                        if statsManager.hasBattery {
                            BatteryDetailCard(
                                level: statsManager.batteryLevel,
                                charging: statsManager.batteryCharging
                            )
                        }
                    }
                }

                // Process Manager
                ProcessManagerCard(processes: statsManager.topProcesses)
            }
            .padding(20)
        }
        .onAppear { startHistoryTracking() }
        .onDisappear { historyTimer?.invalidate() }
    }

    private func startHistoryTracking() {
        // Add initial point
        addHistoryPoint()

        historyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            addHistoryPoint()
        }
    }

    private func addHistoryPoint() {
        let now = Date()
        let maxPoints = 30 // 1 minute of history at 2s intervals

        cpuHistory.append(DataPoint(time: now, value: statsManager.cpuUsage))
        memoryHistory.append(DataPoint(time: now, value: statsManager.memoryUsage))
        networkInHistory.append(DataPoint(time: now, value: statsManager.networkInRate / 1024)) // KB/s
        networkOutHistory.append(DataPoint(time: now, value: statsManager.networkOutRate / 1024))

        // Trim to max points
        if cpuHistory.count > maxPoints { cpuHistory.removeFirst() }
        if memoryHistory.count > maxPoints { memoryHistory.removeFirst() }
        if networkInHistory.count > maxPoints { networkInHistory.removeFirst() }
        if networkOutHistory.count > maxPoints { networkOutHistory.removeFirst() }
    }
}

// MARK: - Graph Cards

struct GraphCard: View {
    let title: String
    let currentValue: String
    let data: [AdvancedSystemView.DataPoint]
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(currentValue)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
            }

            if data.count >= 2 {
                Chart(data) { point in
                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Text("Collecting data...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

struct NetworkGraphCard: View {
    let inHistory: [AdvancedSystemView.DataPoint]
    let outHistory: [AdvancedSystemView.DataPoint]
    let currentIn: Double
    let currentOut: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purple)
                Text("Network Activity")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                        Text(formatSpeed(currentIn))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Text(formatSpeed(currentOut))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                }
            }

            if inHistory.count >= 2 {
                Chart {
                    ForEach(inHistory) { point in
                        AreaMark(
                            x: .value("Time", point.time),
                            y: .value("In", point.value)
                        )
                        .foregroundStyle(Color.blue.opacity(0.2))

                        LineMark(
                            x: .value("Time", point.time),
                            y: .value("In", point.value)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }

                    ForEach(outHistory) { point in
                        LineMark(
                            x: .value("Time", point.time),
                            y: .value("Out", point.value)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0) KB/s")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Text("Collecting data...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 { return String(format: "%.1f MB/s", bytesPerSec / 1_048_576) }
        if bytesPerSec >= 1024 { return String(format: "%.1f KB/s", bytesPerSec / 1024) }
        return String(format: "%.0f B/s", bytesPerSec)
    }
}

struct MemoryBreakdownCard: View {
    let used: UInt64
    let total: UInt64

    private var usedGB: Double { Double(used) / 1_073_741_824 }
    private var totalGB: Double { Double(total) / 1_073_741_824 }
    private var freeGB: Double { totalGB - usedGB }
    private var percent: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                Text("Memory")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f / %.1f GB", usedGB, totalGB))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }

            // Visual breakdown bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(percent / 100, 1))
                }
            }
            .frame(height: 12)

            HStack {
                MemoryLegend(color: .blue, label: "Used", value: String(format: "%.1f GB", usedGB))
                Spacer()
                MemoryLegend(color: .gray.opacity(0.3), label: "Free", value: String(format: "%.1f GB", freeGB))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

struct MemoryLegend: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
    }
}

struct LoadDetailCard: View {
    let load: (Double, Double, Double)

    var body: some View {
        HStack {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.purple)
            Text("Load")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 12) {
                LoadPill(label: "1m", value: load.0)
                LoadPill(label: "5m", value: load.1)
                LoadPill(label: "15m", value: load.2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

struct LoadPill: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.2f", value))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct BatteryDetailCard: View {
    let level: Int
    let charging: Bool

    var body: some View {
        HStack {
            Image(systemName: charging ? "battery.100.bolt" : "battery.75")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(charging ? .green : (level > 20 ? .primary : .red))
            Text("Battery")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text("\(level)%")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
            if charging {
                Text("Charging")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

struct ProcessManagerCard: View {
    let processes: [SystemStatsManager.AppProcess]
    @State private var sortBy: SortField = .cpu

    enum SortField {
        case cpu, memory, name
    }

    private var sortedProcesses: [SystemStatsManager.AppProcess] {
        switch sortBy {
        case .cpu: return processes.sorted { $0.cpu > $1.cpu }
        case .memory: return processes.sorted { $0.memory > $1.memory }
        case .name: return processes.sorted { $0.name < $1.name }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyan)
                Text("Processes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()

                Picker("Sort", selection: $sortBy) {
                    Text("CPU").tag(SortField.cpu)
                    Text("Memory").tag(SortField.memory)
                    Text("Name").tag(SortField.name)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            // Header
            HStack {
                Text("Process")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("PID")
                    .frame(width: 60, alignment: .trailing)
                Text("CPU")
                    .frame(width: 60, alignment: .trailing)
                Text("MEM")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)

            Divider()

            ForEach(sortedProcesses.prefix(10)) { process in
                HStack {
                    Text(process.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(process.pid)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    Text(String(format: "%.1f%%", process.cpu))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                        .frame(width: 60, alignment: .trailing)
                    Text(String(format: "%.1f%%", process.memory))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Advanced Claude View

struct AdvancedClaudeView: View {
    @ObservedObject var claudeManager: ClaudeCodeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sessions & Today Stats Row
                HStack(spacing: 16) {
                    ActiveSessionsPanel(
                        sessions: claudeManager.sessions,
                        totalMemoryMB: claudeManager.totalMemoryMB
                    )

                    TodayStatsPanel(stats: claudeManager.todayStats)
                }

                // Weekly Usage Chart
                WeeklyUsageChart(weeklyActivity: claudeManager.weeklyActivity)
                    .frame(height: 200)

                // MCP Servers Panel
                if !claudeManager.mcpServers.isEmpty {
                    MCPServersPanel(servers: claudeManager.mcpServers)
                }

                // Quick Actions
                QuickActionsPanel(claudeManager: claudeManager)
            }
            .padding(20)
        }
    }
}

struct ActiveSessionsPanel: View {
    let sessions: [ClaudeCodeManager.ClaudeSession]
    let totalMemoryMB: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purple)
                Text("Active Sessions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(sessions.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }

            if !sessions.isEmpty {
                Divider()

                Text(String(format: "Total Memory: %.0f MB", totalMemoryMB))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                ForEach(sessions) { session in
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("PID \(session.pid)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Spacer()
                        Text(String(format: "%.0f MB", session.memoryMB))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No active sessions")
                    .font(.system(size: 12))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

struct TodayStatsPanel: View {
    let stats: ClaudeCodeManager.DailyStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if let stats = stats {
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        StatBox(value: formatTokens(stats.tokens), label: "Tokens", color: .blue)
                        StatBox(value: String(format: "$%.2f", stats.estimatedCost), label: "Cost", color: .green)
                    }
                    HStack(spacing: 20) {
                        StatBox(value: "\(stats.messageCount)", label: "Messages", color: .purple)
                        StatBox(value: "\(stats.toolCallCount)", label: "Tool Calls", color: .orange)
                    }
                }
            } else {
                Text("No activity today")
                    .font(.system(size: 12))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeeklyUsageChart: View {
    let weeklyActivity: [ClaudeCodeManager.DailyActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
                Text("7-Day Activity")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()

                if let total = weeklyActivity.map({ $0.messageCount }).reduce(0, +) as Int? {
                    Text("\(total) messages this week")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            if weeklyActivity.count >= 2 {
                Chart(weeklyActivity) { activity in
                    BarMark(
                        x: .value("Date", formatDate(activity.date)),
                        y: .value("Messages", activity.messageCount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.7), .blue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            Text(value.as(String.self) ?? "")
                                .font(.system(size: 9))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)")
                                .font(.system(size: 9))
                        }
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Text("Not enough data for chart")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }

    private func formatDate(_ dateString: String) -> String {
        // Convert "2024-01-15" to "Mon"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date)
    }
}

struct MCPServersPanel: View {
    let servers: [ClaudeCodeManager.MCPServerStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cable.connector")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                Text("MCP Servers")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(servers.count) configured")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(servers) { server in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(server.isAvailable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(server.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

struct QuickActionsPanel: View {
    @ObservedObject var claudeManager: ClaudeCodeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.yellow)
                Text("Quick Actions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Kill Orphaned LSPs",
                    description: "Clean up language servers",
                    icon: "xmark.circle.fill",
                    color: .red
                ) {
                    claudeManager.killOrphanedLSPs()
                }

                QuickActionButton(
                    title: "Open Stats Folder",
                    description: "View ~/.claude directory",
                    icon: "folder.fill",
                    color: .blue
                ) {
                    claudeManager.openStatsFolder()
                }

                QuickActionButton(
                    title: "Refresh Data",
                    description: "Update all statistics",
                    icon: "arrow.clockwise",
                    color: .green
                ) {
                    claudeManager.refresh()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
