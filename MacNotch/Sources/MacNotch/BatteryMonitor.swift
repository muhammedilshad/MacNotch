import Foundation
import IOKit
import IOKit.ps

/// Battery level and charger state, updated by IOKit power-source notifications.
final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    @Published private(set) var hasBattery = false
    @Published private(set) var level = 0
    @Published private(set) var isPluggedIn = false
    @Published private(set) var isCharging = false
    /// Minutes until full or empty, when macOS has an estimate.
    @Published private(set) var minutesToFull: Int?
    @Published private(set) var minutesToEmpty: Int?
    @Published private(set) var adapterWatts: Int?
    @Published private(set) var health: Health?

    struct Health: Equatable {
        var cycleCount: Int
        /// Current full-charge capacity as a percentage of the design capacity.
        var capacityPercent: Int
        var temperatureCelsius: Double
    }

    var isFull: Bool { isPluggedIn && level >= 100 }

    private var source: CFRunLoopSource?

    /// Reads the current state synchronously, so subscribers can skip the initial value.
    func start() {
        guard source == nil else { return }
        refresh()
        source = IOPSNotificationCreateRunLoopSource({ _ in
            BatteryMonitor.shared.refresh()
        }, nil)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode) }
    }

    private func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }

        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = max(description[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
            let pluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            update(hasBattery: true,
                   level: min(100, Int((Double(current) / Double(maximum) * 100).rounded())),
                   pluggedIn: pluggedIn,
                   charging: description[kIOPSIsChargingKey] as? Bool ?? false)
            refreshDetails(description, pluggedIn: pluggedIn)
            return
        }
        update(hasBattery: false, level: 0, pluggedIn: false, charging: false)
    }

    private func refreshDetails(_ description: [String: Any], pluggedIn: Bool) {
        // -1 means "still calculating".
        let toFull = (description[kIOPSTimeToFullChargeKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
        let toEmpty = (description[kIOPSTimeToEmptyKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
        if minutesToFull != toFull { minutesToFull = toFull }
        if minutesToEmpty != toEmpty { minutesToEmpty = toEmpty }

        let adapter = pluggedIn ? IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] : nil
        let watts = adapter?[kIOPSPowerAdapterWattsKey] as? Int
        if adapterWatts != watts { adapterWatts = watts }

        let newHealth = Self.readHealth()
        if health != newHealth { health = newHealth }
    }

    private static func readHealth() -> Health? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        // Apple silicon Macs keep most of these inside "BatteryData"; Intel Macs list them at the top level.
        let data = property("BatteryData") as? [String: Any] ?? [:]
        func value(_ key: String) -> Int? { property(key) as? Int ?? data[key] as? Int }

        guard let cycles = value("CycleCount"), let design = value("DesignCapacity"), design > 0 else { return nil }
        let maximum = value("AppleRawMaxCapacity") ?? value("NominalChargeCapacity") ?? design
        let temperature = value("Temperature") ?? value("VirtualTemperature") ?? 0
        return Health(cycleCount: cycles,
                      capacityPercent: min(100, Int((Double(maximum) / Double(design) * 100).rounded())),
                      temperatureCelsius: Double(temperature) / 100)
    }

    private func update(hasBattery: Bool, level: Int, pluggedIn: Bool, charging: Bool) {
        if self.hasBattery != hasBattery { self.hasBattery = hasBattery }
        if self.level != level { self.level = level }
        if isPluggedIn != pluggedIn { isPluggedIn = pluggedIn }
        if isCharging != charging { isCharging = charging }
    }
}
