import SwiftUI

// MARK: - Main Claude Code View

struct ClaudeCodeView: View {
    @ObservedObject var claudeManager: ClaudeCodeManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                // Active Sessions Card
                ClaudeSessionsCard(
                    sessions: claudeManager.sessions,
                    totalMemoryMB: claudeManager.totalMemoryMB
                )

                // Today's Usage Card with Sparkline
                TodayUsageCard(
                    stats: claudeManager.todayStats,
                    weeklyActivity: claudeManager.weeklyActivity
                )

                // MCP Server Status Card
                if !claudeManager.mcpServers.isEmpty {
                    MCPStatusCard(servers: claudeManager.mcpServers)
                }

                // Quick Actions Card
                QuickActionsCard(claudeManager: claudeManager)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Tab Selector View

struct TabSelectorView: View {
    @Binding var selectedTab: DashboardTab

    var body: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "System",
                icon: "cpu",
                isSelected: selectedTab == .system,
                action: { selectedTab = .system }
            )

            TabButton(
                title: "Claude",
                icon: "terminal",
                isSelected: selectedTab == .claude,
                action: { selectedTab = .claude }
            )
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? .white : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

enum DashboardTab {
    case system
    case claude
}

// MARK: - Active Sessions Card

struct ClaudeSessionsCard: View {
    let sessions: [ClaudeCodeManager.ClaudeSession]
    let totalMemoryMB: Double

    private var pidsString: String {
        sessions.prefix(3).map { String($0.pid) }.joined(separator: ", ")
        + (sessions.count > 3 ? "..." : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)
                    .frame(width: 16)

                Text("Active Sessions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(sessions.count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            if !sessions.isEmpty {
                HStack(spacing: 4) {
                    Text(String(format: "%.0fMB total", totalMemoryMB))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("PIDs: \(pidsString)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("No active Claude sessions")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
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

// MARK: - Today's Usage Card

struct TodayUsageCard: View {
    let stats: ClaudeCodeManager.DailyStats?
    let weeklyActivity: [ClaudeCodeManager.DailyActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 16)

                Text("Today's Usage")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()
            }

            if let stats = stats {
                HStack(spacing: 12) {
                    UsageMetric(
                        value: formatTokens(stats.tokens),
                        label: "tokens"
                    )
                    UsageMetric(
                        value: String(format: "$%.2f", stats.estimatedCost),
                        label: "est. cost"
                    )
                    UsageMetric(
                        value: "\(stats.messageCount)",
                        label: "messages"
                    )
                }

                // Sparkline
                if weeklyActivity.count >= 2 {
                    SparklineView(
                        data: weeklyActivity.map { Double($0.messageCount) }
                    )
                    .frame(height: 24)
                    .padding(.top, 4)
                }
            } else {
                Text("No activity today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}

struct UsageMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let data: [Double]

    private var normalizedData: [Double] {
        guard let maxValue = data.max(), maxValue > 0 else { return data }
        return data.map { $0 / maxValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let barWidth = width / CGFloat(max(data.count, 1)) - 2

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(normalizedData.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.blue],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: barWidth,
                            height: max(2, height * CGFloat(value))
                        )
                }
            }
        }
    }
}

// MARK: - MCP Status Card

struct MCPStatusCard: View {
    let servers: [ClaudeCodeManager.MCPServerStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cable.connector")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(width: 16)

                Text("MCP Servers")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Server status indicators
            FlowLayout(spacing: 8) {
                ForEach(servers) { server in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(server.isAvailable ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(server.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
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

// MARK: - Flow Layout for MCP Servers

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    @ObservedObject var claudeManager: ClaudeCodeManager
    @State private var showingKillConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.yellow)
                    .frame(width: 16)

                Text("Quick Actions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()
            }

            HStack(spacing: 8) {
                ActionButton(
                    title: "Kill LSPs",
                    icon: "xmark.circle",
                    color: .red
                ) {
                    claudeManager.killOrphanedLSPs()
                }

                ActionButton(
                    title: "Open Stats",
                    icon: "folder",
                    color: .blue
                ) {
                    claudeManager.openStatsFolder()
                }

                ActionButton(
                    title: "Refresh",
                    icon: "arrow.clockwise",
                    color: .green
                ) {
                    claudeManager.refresh()
                }
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

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
