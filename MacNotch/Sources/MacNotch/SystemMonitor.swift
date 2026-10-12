import AppKit
import CoreMediaIO
import Darwin
import Foundation

/// CPU, memory, disk, network throughput and local dev servers for the dashboard tab.
/// Sampling only runs while something is showing it (see `addClient`/`removeClient`).
final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    struct DevServer: Identifiable, Equatable {
        var id: Int { port }
        let port: Int
        let process: String
        let pid: Int32
    }

    @Published private(set) var cpu: Double = 0
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published private(set) var diskFree: Int64 = 0
    @Published private(set) var diskTotal: Int64 = 0
    @Published private(set) var downloadSpeed: Double = 0
    @Published private(set) var uploadSpeed: Double = 0
    /// Recent download/upload speeds, oldest first, for the sparkline.
    @Published private(set) var downloadHistory: [Double] = Array(repeating: 0, count: 40)
    @Published private(set) var uploadHistory: [Double] = Array(repeating: 0, count: 40)
    @Published private(set) var localAddress: String?
    @Published private(set) var devServers: [DevServer] = []

    private var clients = 0
    private var timer: Timer?
    private var previousCPU: (busy: UInt64, total: UInt64)?
    private var previousBytes: (received: UInt32, sent: UInt32, at: Date)?
    private var tick = 0

    var memoryFraction: Double { memoryTotal == 0 ? 0 : Double(memoryUsed) / Double(memoryTotal) }
    var diskUsedFraction: Double { diskTotal == 0 ? 0 : 1 - Double(diskFree) / Double(diskTotal) }

    func addClient() {
        clients += 1
        guard timer == nil else { return }
        sample()
        refreshDevServers()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.sample() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func removeClient() {
        clients = max(0, clients - 1)
        guard clients == 0 else { return }
        timer?.invalidate()
        timer = nil
        previousBytes = nil
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
        sampleNetwork()
        tick += 1
        if tick % 10 == 1 { sampleDisk() }
        if tick % 5 == 0 { refreshDevServers() }
    }

    // MARK: CPU and memory

    private func sampleCPU() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        let busy = user + system + nice
        let total = busy + idle
        if let previous = previousCPU, total > previous.total {
            cpu = Double(busy - previous.busy) / Double(total - previous.total)
        }
        previousCPU = (busy, total)
    }

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        // Matches Activity Monitor's "Memory Used": app memory + wired + compressed.
        let page = UInt64(vm_kernel_page_size)
        let app = UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)
        memoryUsed = (app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
    }

    private func sampleDisk() {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else { return }
        diskFree = values.volumeAvailableCapacityForImportantUsage ?? 0
        diskTotal = Int64(values.volumeTotalCapacity ?? 0)
    }

    // MARK: Network

    private func sampleNetwork() {
        var received: UInt32 = 0, sent: UInt32 = 0
        var address: String?
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return }
        defer { freeifaddrs(list) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            let name = String(cString: entry.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip"), let socket = entry.ifa_addr else { continue }
            if socket.pointee.sa_family == UInt8(AF_LINK), let data = entry.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                received &+= stats.ifi_ibytes
                sent &+= stats.ifi_obytes
            } else if socket.pointee.sa_family == UInt8(AF_INET), address == nil {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(socket, socklen_t(socket.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let text = String(cString: host)
                    if !text.hasPrefix("169.254") { address = text }
                }
            }
        }

        let now = Date()
        if let previous = previousBytes {
            let seconds = max(0.2, now.timeIntervalSince(previous.at))
            // The 32-bit counters wrap every 4 GB; wrapping subtraction handles that.
            downloadSpeed = Double(received &- previous.received) / seconds
            uploadSpeed = Double(sent &- previous.sent) / seconds
            downloadHistory = Array((downloadHistory + [downloadSpeed]).suffix(40))
            uploadHistory = Array((uploadHistory + [uploadSpeed]).suffix(40))
        }
        previousBytes = (received, sent, now)
        if localAddress != address { localAddress = address }
    }

    // MARK: Dev servers

    private static let ignoredProcesses: Set<String> = [
        "ControlCenter", "rapportd", "sharingd", "identityservicesd", "Spotify", "Dropbox", "MacNotch",
        "remoted", "AirPlayXPCHelper", "Adobe Desktop Service", "Creative Cloud", "figma_agent",
    ]

    /// Lists TCP ports the user's processes listen on, via lsof.
    private func refreshDevServers() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-nP", "+c", "0", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            var servers: [Int: DevServer] = [:]
            var pid: Int32 = 0
            var command = ""
            for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                guard let tag = line.first else { continue }
                let value = String(line.dropFirst())
                switch tag {
                case "p": pid = Int32(value) ?? 0
                case "c": command = value
                case "n":
                    guard let port = value.split(separator: ":").last.flatMap({ Int($0) }),
                          !Self.ignoredProcesses.contains(command),
                          !Self.isSystemProcess(pid),
                          servers[port] == nil else { continue }
                    servers[port] = DevServer(port: port, process: command, pid: pid)
                default: break
                }
            }
            let sorted = servers.values.sorted { $0.port < $1.port }
            DispatchQueue.main.async {
                if self?.devServers != sorted { self?.devServers = sorted }
            }
        }
    }

    /// macOS's own services (AirPlay, Remote Desktop, sharing…) aren't dev servers.
    private static func isSystemProcess(_ pid: Int32) -> Bool {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return false }
        let path = String(cString: buffer)
        return ["/System/", "/usr/libexec/", "/usr/sbin/", "/Library/Apple/"].contains { path.hasPrefix($0) }
    }

    func open(_ server: DevServer) {
        if let url = URL(string: "http://localhost:\(server.port)") { NSWorkspace.shared.open(url) }
    }

    func stop(_ server: DevServer) {
        kill(server.pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refreshDevServers() }
    }
}

/// Whether any app is using the camera or a microphone, like the dots on an iPhone.
final class PrivacyMonitor: ObservableObject {
    static let shared = PrivacyMonitor()

    @Published private(set) var cameraInUse = false
    @Published private(set) var microphoneInUse = false

    private var timer: Timer?

    func setRunning(_ running: Bool) {
        if running, timer == nil {
            poll()
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.poll() }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if !running {
            timer?.invalidate()
            timer = nil
            cameraInUse = false
            microphoneInUse = false
        }
    }

    private func poll() {
        let camera = Self.isCameraInUse()
        let microphone = AudioController.shared.isMicrophoneInUse()
        if camera != cameraInUse { cameraInUse = camera }
        if microphone != microphoneInUse { microphoneInUse = microphone }
    }

    private static func isCameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == 0, size > 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == 0 else { return false }

        var runningAddress = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                                                       mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                                                       mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard))
        return devices.contains { device in
            var running: UInt32 = 0
            var dataUsed: UInt32 = 0
            let status = CMIOObjectGetPropertyData(device, &runningAddress, 0, nil,
                                                   UInt32(MemoryLayout<UInt32>.size), &dataUsed, &running)
            return status == 0 && running != 0
        }
    }
}

enum ByteFormat {
    static func speed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unit = 0
        while value >= 1000, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        return unit == 0 ? "\(Int(value)) \(units[unit])" : String(format: value < 10 ? "%.1f %@" : "%.0f %@", value, units[unit])
    }

    /// "512M", "16G", "1.2T".
    static func compact(_ bytes: Int64) -> String {
        let gigabytes = Double(bytes) / 1_000_000_000
        if gigabytes >= 1000 { return String(format: "%.1fT", gigabytes / 1000) }
        if gigabytes >= 10 { return "\(Int(gigabytes))G" }
        if gigabytes >= 1 { return String(format: "%.1fG", gigabytes) }
        return "\(Int(gigabytes * 1000))M"
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
