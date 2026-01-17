import Foundation
import IOKit
import IOKit.ps

class SystemStatsManager: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var gpuUsage: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var memoryTotal: UInt64 = 0
    @Published var networkInRate: Double = 0
    @Published var networkOutRate: Double = 0
    @Published var batteryLevel: Int = 100
    @Published var batteryCharging: Bool = false
    @Published var hasBattery: Bool = false
    @Published var uptime: TimeInterval = 0
    @Published var topProcesses: [AppProcess] = []
    @Published var loadAverage: (Double, Double, Double) = (0, 0, 0)

    private var previousCPUInfo: host_cpu_load_info?
    private var previousNetworkIn: UInt64 = 0
    private var previousNetworkOut: UInt64 = 0
    private var lastUpdate: Date = Date()

    struct AppProcess: Identifiable {
        let id = UUID()
        let pid: Int32
        let name: String
        let cpu: Double
        let memory: Double
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let cpu = self.getCPUUsage()
            let gpu = self.getGPUUsage()
            let (memUsed, memTotal) = self.getMemoryUsage()
            let memPercent = memTotal > 0 ? Double(memUsed) / Double(memTotal) * 100 : 0
            let (netIn, netOut) = self.getNetworkBytes()
            let (battLevel, charging, hasBatt) = self.getBatteryStatus()
            let uptimeVal = self.getUptime()
            let processes = self.getTopProcesses()
            let load = self.getLoadAverage()

            let now = Date()
            let interval = now.timeIntervalSince(self.lastUpdate)

            let inDiff = netIn >= self.previousNetworkIn ? netIn - self.previousNetworkIn : 0
            let outDiff = netOut >= self.previousNetworkOut ? netOut - self.previousNetworkOut : 0
            let inRate = interval > 0 ? Double(inDiff) / interval : 0
            let outRate = interval > 0 ? Double(outDiff) / interval : 0

            self.previousNetworkIn = netIn
            self.previousNetworkOut = netOut
            self.lastUpdate = now

            DispatchQueue.main.async {
                self.cpuUsage = cpu
                self.gpuUsage = gpu
                self.memoryUsed = memUsed
                self.memoryTotal = memTotal
                self.memoryUsage = memPercent
                self.networkInRate = max(0, inRate)
                self.networkOutRate = max(0, outRate)
                self.batteryLevel = battLevel
                self.batteryCharging = charging
                self.hasBattery = hasBatt
                self.uptime = uptimeVal
                self.topProcesses = processes
                self.loadAverage = load
            }
        }
    }

    private func getCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let current = cpuInfo
        defer { previousCPUInfo = current }

        guard let previous = previousCPUInfo else { return 0 }

        let userDiff = Double(current.cpu_ticks.0) - Double(previous.cpu_ticks.0)
        let systemDiff = Double(current.cpu_ticks.1) - Double(previous.cpu_ticks.1)
        let idleDiff = Double(current.cpu_ticks.2) - Double(previous.cpu_ticks.2)
        let niceDiff = Double(current.cpu_ticks.3) - Double(previous.cpu_ticks.3)

        let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
        if totalTicks == 0 { return 0 }

        return ((userDiff + systemDiff + niceDiff) / totalTicks) * 100
    }

    private func getGPUUsage() -> Double {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        let result = IOServiceGetMatchingServices(0, matching, &iterator)
        guard result == KERN_SUCCESS else { return 0 }

        defer { IOObjectRelease(iterator) }

        var entry: io_object_t = IOIteratorNext(iterator)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }

            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = properties?.takeRetainedValue() as? [String: Any],
               let perfStats = props["PerformanceStatistics"] as? [String: Any] {

                if let usage = perfStats["Device Utilization %"] as? Double {
                    return usage
                }
                if let usage = perfStats["GPU Activity(%)"] as? Double {
                    return usage
                }
            }
        }
        return 0
    }

    private func getMemoryUsage() -> (UInt64, UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 0) }

        let pageSize = UInt64(vm_kernel_page_size)
        let total = ProcessInfo.processInfo.physicalMemory

        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        return (used, total)
    }

    private func getNetworkBytes() -> (UInt64, UInt64) {
        // Use netstat -ibn for interface bytes (more reliable parsing)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/netstat")
        task.arguments = ["-ibn"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return (0, 0) }

            var bytesIn: UInt64 = 0
            var bytesOut: UInt64 = 0

            let lines = output.components(separatedBy: "\n")

            for line in lines {
                // Match en0, en1, etc. but skip Link# lines (those are different format)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("en") else { continue }

                let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)

                // Format: Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
                // Index:  0    1   2       3       4     5     6      7     8     9      10
                // But for Link# rows format differs, so we check for numeric Ibytes position
                if parts.count >= 10 {
                    // Find the bytes columns - they're large numbers
                    // Ibytes is usually at index 6, Obytes at index 9
                    if let inB = UInt64(parts[6]), let outB = UInt64(parts[9]) {
                        bytesIn += inB
                        bytesOut += outB
                    }
                }
            }
            return (bytesIn, bytesOut)
        } catch {
            return (0, 0)
        }
    }

    private func getBatteryStatus() -> (Int, Bool, Bool) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty,
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return (100, false, false)
        }

        let level = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
        let charging = desc[kIOPSIsChargingKey] as? Bool ?? false

        return (level, charging, true)
    }

    private func getUptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        if sysctl(&mib, 2, &boottime, &size, nil, 0) != -1 {
            let bootDate = Date(timeIntervalSince1970: Double(boottime.tv_sec))
            return Date().timeIntervalSince(bootDate)
        }
        return 0
    }

    private func getTopProcesses() -> [AppProcess] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Aceo", "pid,pcpu,pmem,comm", "-r"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            return output.components(separatedBy: "\n")
                .dropFirst()
                .prefix(8)
                .compactMap { line -> AppProcess? in
                    let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                    guard parts.count >= 4,
                          let pid = Int32(parts[0]),
                          let cpu = Double(parts[1]),
                          let mem = Double(parts[2]) else { return nil }

                    let name = String(parts[3]).components(separatedBy: "/").last ?? String(parts[3])
                    return AppProcess(pid: pid, name: name, cpu: cpu, memory: mem)
                }
        } catch {
            return []
        }
    }

    private func getLoadAverage() -> (Double, Double, Double) {
        var loadavg: [Double] = [0, 0, 0]
        getloadavg(&loadavg, 3)
        return (loadavg[0], loadavg[1], loadavg[2])
    }
}
