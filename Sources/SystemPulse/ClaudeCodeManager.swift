import Foundation
import AppKit

/// Manager for Claude Code statistics and session monitoring
class ClaudeCodeManager: ObservableObject {
    @Published var sessions: [ClaudeSession] = []
    @Published var todayStats: DailyStats?
    @Published var weeklyActivity: [DailyActivity] = []
    @Published var mcpServers: [MCPServerStatus] = []
    @Published var totalMemoryMB: Double = 0
    @Published var hasClaudeDirectory: Bool = true

    private let claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    private let claudeJson = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    private let mcpJson = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mcp.json")

    struct ClaudeSession: Identifiable {
        let id = UUID()
        let pid: Int32
        let cpu: Double
        let memoryMB: Double
        let command: String
    }

    struct DailyStats {
        let messageCount: Int
        let sessionCount: Int
        let toolCallCount: Int
        let tokens: Int
        let estimatedCost: Double
    }

    struct DailyActivity: Identifiable {
        let id = UUID()
        let date: String
        let messageCount: Int
        let tokens: Int
    }

    struct MCPServerStatus: Identifiable {
        let id = UUID()
        let name: String
        let isAvailable: Bool
        let source: String // "global" or "project"
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let sessions = self.getClaudeSessions()
            let totalMem = sessions.reduce(0) { $0 + $1.memoryMB }
            let stats = self.getTodayStats()
            let weekly = self.getWeeklyActivity()
            let mcpStatus = self.getMCPServerStatus()
            let hasDir = FileManager.default.fileExists(atPath: self.claudeDir.path)

            DispatchQueue.main.async {
                self.sessions = sessions
                self.totalMemoryMB = totalMem
                self.todayStats = stats
                self.weeklyActivity = weekly
                self.mcpServers = mcpStatus
                self.hasClaudeDirectory = hasDir
            }
        }
    }

    // MARK: - Claude Sessions

    private func getClaudeSessions() -> [ClaudeSession] {
        // Use ps with full command to identify actual Claude Code CLI sessions
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-eo", "pid,pcpu,rss,command"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var seenPids = Set<Int32>()

            return output.components(separatedBy: "\n")
                .dropFirst()
                .compactMap { line -> ClaudeSession? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                    guard parts.count >= 4,
                          let pid = Int32(parts[0]),
                          let cpu = Double(parts[1]),
                          let rssKB = Double(parts[2]) else { return nil }

                    let fullCommand = String(parts[3])

                    // Only match actual Claude Code CLI sessions:
                    // - Contains "claude" in path AND has a project directory argument
                    // - OR is the main claude binary with -p flag (project mode)
                    let isClaudeCLI = (fullCommand.contains("/claude") || fullCommand.hasPrefix("claude ")) &&
                                      (fullCommand.contains(" -p ") || fullCommand.contains(" --project"))

                    // Also match standalone claude processes that are the main entry point
                    let isMainClaude = fullCommand.hasSuffix("/claude") ||
                                       (fullCommand.contains("/@anthropic/claude") && !fullCommand.contains("node"))

                    guard (isClaudeCLI || isMainClaude) && !seenPids.contains(pid) else { return nil }
                    seenPids.insert(pid)

                    return ClaudeSession(
                        pid: pid,
                        cpu: cpu,
                        memoryMB: rssKB / 1024.0,
                        command: "Claude Code"
                    )
                }
        } catch {
            return []
        }
    }

    // MARK: - Stats Cache Parsing

    private func getTodayStats() -> DailyStats? {
        let statsFile = claudeDir.appendingPathComponent("stats-cache.json")
        guard let data = try? Data(contentsOf: statsFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        var messageCount = 0
        var sessionCount = 0
        var toolCallCount = 0
        var tokens = 0

        // Get activity stats
        if let dailyActivity = json["dailyActivity"] as? [[String: Any]] {
            if let todayActivity = dailyActivity.first(where: { $0["date"] as? String == todayString }) {
                messageCount = todayActivity["messageCount"] as? Int ?? 0
                sessionCount = todayActivity["sessionCount"] as? Int ?? 0
                toolCallCount = todayActivity["toolCallCount"] as? Int ?? 0
            }
        }

        // Get token counts
        if let dailyTokens = json["dailyModelTokens"] as? [[String: Any]] {
            if let todayTokens = dailyTokens.first(where: { $0["date"] as? String == todayString }),
               let tokensByModel = todayTokens["tokensByModel"] as? [String: Int] {
                tokens = tokensByModel.values.reduce(0, +)
            }
        }

        // Estimate cost based on model usage (rough approximation)
        // Using Sonnet pricing: $3/$15 per million tokens (input/output)
        // Using Opus pricing: $15/$75 per million tokens
        let estimatedCost = estimateCost(from: json, for: todayString)

        return DailyStats(
            messageCount: messageCount,
            sessionCount: sessionCount,
            toolCallCount: toolCallCount,
            tokens: tokens,
            estimatedCost: estimatedCost
        )
    }

    private func estimateCost(from json: [String: Any], for dateString: String) -> Double {
        guard let dailyTokens = json["dailyModelTokens"] as? [[String: Any]],
              let todayEntry = dailyTokens.first(where: { $0["date"] as? String == dateString }),
              let tokensByModel = todayEntry["tokensByModel"] as? [String: Int] else {
            return 0
        }

        var cost: Double = 0
        for (model, tokenCount) in tokensByModel {
            // Rough estimate: assume 30% input, 70% output split
            let inputTokens = Double(tokenCount) * 0.3
            let outputTokens = Double(tokenCount) * 0.7

            if model.contains("opus") {
                // Opus: $15/M input, $75/M output
                cost += (inputTokens / 1_000_000 * 15) + (outputTokens / 1_000_000 * 75)
            } else {
                // Sonnet: $3/M input, $15/M output
                cost += (inputTokens / 1_000_000 * 3) + (outputTokens / 1_000_000 * 15)
            }
        }
        return cost
    }

    private func getWeeklyActivity() -> [DailyActivity] {
        let statsFile = claudeDir.appendingPathComponent("stats-cache.json")
        guard let data = try? Data(contentsOf: statsFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        let calendar = Calendar.current
        let today = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var activities: [DailyActivity] = []

        // Build a lookup for tokens by date
        var tokensByDate: [String: Int] = [:]
        if let dailyTokens = json["dailyModelTokens"] as? [[String: Any]] {
            for entry in dailyTokens {
                if let date = entry["date"] as? String,
                   let tokensByModel = entry["tokensByModel"] as? [String: Int] {
                    tokensByDate[date] = tokensByModel.values.reduce(0, +)
                }
            }
        }

        // Get daily activity for last 7 days
        if let dailyActivity = json["dailyActivity"] as? [[String: Any]] {
            for entry in dailyActivity {
                guard let dateStr = entry["date"] as? String,
                      let date = dateFormatter.date(from: dateStr),
                      date >= sevenDaysAgo else { continue }

                let messageCount = entry["messageCount"] as? Int ?? 0
                let tokens = tokensByDate[dateStr] ?? 0

                activities.append(DailyActivity(
                    date: dateStr,
                    messageCount: messageCount,
                    tokens: tokens
                ))
            }
        }

        // Sort by date and take last 7
        activities.sort { $0.date < $1.date }
        return Array(activities.suffix(7))
    }

    // MARK: - MCP Server Status

    private func getMCPServerStatus() -> [MCPServerStatus] {
        var servers: [MCPServerStatus] = []

        // Check global .mcp.json
        if let data = try? Data(contentsOf: mcpJson),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let mcpServers = json["mcpServers"] as? [String: Any] {
            for (name, _) in mcpServers {
                servers.append(MCPServerStatus(
                    name: name,
                    isAvailable: true, // Assume available if configured
                    source: "global"
                ))
            }
        }

        // Check ~/.claude.json for global mcpServers key at root level
        if let data = try? Data(contentsOf: claudeJson),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let mcpServers = json["mcpServers"] as? [String: Any] {
            for (name, _) in mcpServers {
                // Avoid duplicates
                if !servers.contains(where: { $0.name == name }) {
                    servers.append(MCPServerStatus(
                        name: name,
                        isAvailable: true,
                        source: "global"
                    ))
                }
            }
        }

        return servers
    }

    // MARK: - Quick Actions

    func killOrphanedLSPs() {
        let lspPatterns = [
            "typescript-language-server",
            "tsserver",
            "eslint_d",
            "pyright",
            "pylsp",
            "rust-analyzer",
            "gopls",
            "sourcekit-lsp"
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            for pattern in lspPatterns {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                task.arguments = ["-f", pattern]
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice

                try? task.run()
                task.waitUntilExit()
            }
        }
    }

    func openStatsFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: claudeDir.path)
    }
}
