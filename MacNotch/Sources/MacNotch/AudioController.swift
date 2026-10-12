import AudioToolbox
import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let uid: String
    let name: String
}

/// Output and input devices, the system volume, and whether any app is using a microphone.
final class AudioController: ObservableObject {
    static let shared = AudioController()

    @Published private(set) var outputs: [AudioDevice] = []
    @Published private(set) var inputs: [AudioDevice] = []
    @Published private(set) var defaultOutput: AudioObjectID = 0
    @Published private(set) var defaultInput: AudioObjectID = 0
    @Published private(set) var volume: Float = 0
    @Published private(set) var isMuted = false
    @Published private(set) var canSetVolume = false

    private var started = false
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var listenedDevice: AudioObjectID = 0

    func start() {
        guard !started else { return }
        started = true
        refresh()
        for selector in [kAudioHardwarePropertyDevices,
                         kAudioHardwarePropertyDefaultOutputDevice,
                         kAudioHardwarePropertyDefaultInputDevice] {
            var address = CA.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { [weak self] _, _ in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        let devices = CA.deviceIDs().compactMap { id -> (AudioDevice, Bool, Bool)? in
            guard let uid = CA.string(id, kAudioDevicePropertyDeviceUID),
                  !uid.hasPrefix(AudioSpectrum.tapUIDPrefix) else { return nil }
            let name = CA.string(id, kAudioObjectPropertyName) ?? "Unknown"
            return (AudioDevice(id: id, uid: uid, name: name),
                    CA.hasStreams(id, scope: kAudioObjectPropertyScopeOutput),
                    CA.hasStreams(id, scope: kAudioObjectPropertyScopeInput))
        }
        let newOutputs = devices.filter(\.1).map(\.0)
        let newInputs = devices.filter(\.2).map(\.0)
        if newOutputs != outputs { outputs = newOutputs }
        if newInputs != inputs { inputs = newInputs }

        let system = AudioObjectID(kAudioObjectSystemObject)
        let output: AudioObjectID = CA.get(system, kAudioHardwarePropertyDefaultOutputDevice, default: 0)
        let input: AudioObjectID = CA.get(system, kAudioHardwarePropertyDefaultInputDevice, default: 0)
        if output != defaultOutput { defaultOutput = output }
        if input != defaultInput { defaultInput = input }
        listenForVolume(on: output)
        readVolume()
    }

    // MARK: Volume

    private func listenForVolume(on device: AudioObjectID) {
        guard device != listenedDevice else { return }
        let selectors = [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute]
        if let volumeListener, listenedDevice != 0 {
            for selector in selectors {
                var address = CA.address(selector, scope: kAudioObjectPropertyScopeOutput)
                AudioObjectRemovePropertyListenerBlock(listenedDevice, &address, .main, volumeListener)
            }
        }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.readVolume() }
        for selector in selectors {
            var address = CA.address(selector, scope: kAudioObjectPropertyScopeOutput)
            AudioObjectAddPropertyListenerBlock(device, &address, .main, listener)
        }
        volumeListener = listener
        listenedDevice = device
    }

    private func readVolume() {
        let device = defaultOutput
        var address = CA.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioObjectPropertyScopeOutput)
        var settable: DarwinBoolean = false
        let hasVolume = AudioObjectHasProperty(device, &address)
            && AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
        let newVolume: Float32 = CA.get(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                        scope: kAudioObjectPropertyScopeOutput, default: 0)
        let muted: UInt32 = CA.get(device, kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput, default: 0)
        if canSetVolume != hasVolume { canSetVolume = hasVolume }
        if abs(volume - newVolume) > 0.001 { volume = newVolume }
        if isMuted != (muted != 0) { isMuted = muted != 0 }
    }

    func setVolume(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        volume = clamped
        CA.set(defaultOutput, kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
               scope: kAudioObjectPropertyScopeOutput, value: Float32(clamped))
        if isMuted && clamped > 0 { setMuted(false) }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        CA.set(defaultOutput, kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput, value: UInt32(muted ? 1 : 0))
    }

    // MARK: Devices

    func makeDefaultOutput(_ device: AudioDevice) {
        let system = AudioObjectID(kAudioObjectSystemObject)
        CA.set(system, kAudioHardwarePropertyDefaultOutputDevice, value: device.id)
        CA.set(system, kAudioHardwarePropertyDefaultSystemOutputDevice, value: device.id)
    }

    func makeDefaultInput(_ device: AudioDevice) {
        CA.set(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice, value: device.id)
    }

    /// True while any app records from a microphone.
    func isMicrophoneInUse() -> Bool {
        inputs.contains { device in
            let running: UInt32 = CA.get(device.id, kAudioDevicePropertyDeviceIsRunningSomewhere, default: 0)
            return running != 0
        }
    }
}

/// Small helpers over the CoreAudio property API.
enum CA {
    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func get<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, default fallback: T) -> T {
        var address = address(selector, scope: scope)
        guard AudioObjectHasProperty(object, &address) else { return fallback }
        var value = fallback
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) }
        return status == noErr ? value : fallback
    }

    @discardableResult
    static func set<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, value: T) -> Bool {
        var address = address(selector, scope: scope)
        var value = value
        let size = UInt32(MemoryLayout<T>.size)
        return withUnsafeMutablePointer(to: &value) {
            AudioObjectSetPropertyData(object, &address, 0, nil, size, $0)
        } == noErr
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    static func deviceIDs() -> [AudioObjectID] {
        var address = address(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func hasStreams(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: scope)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }
}
