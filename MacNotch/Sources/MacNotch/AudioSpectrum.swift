import Accelerate
import AudioToolbox
import CoreAudio
import Foundation

/// Live loudness of a few frequency bands of whatever the Mac is playing, for the waveform.
///
/// Uses a Core Audio process tap (macOS 14.2+), which asks for "System Audio Recording" permission
/// the first time. Without it, or on older macOS versions, `isLive` stays false and the waveform
/// falls back to its built-in animation.
final class AudioSpectrum: ObservableObject {
    static let shared = AudioSpectrum()
    static let bandCount = 5
    /// Marks the private aggregate device, so device lists can hide it.
    static let tapUIDPrefix = "MacNotchTap"

    @Published private(set) var levels = [Float](repeating: 0, count: bandCount)
    @Published private(set) var isLive = false

    private var tap: AnyObject?
    private let analyzer = SpectrumAnalyzer(bands: bandCount)
    private var lastPublish = Date.distantPast

    func setRunning(_ running: Bool) {
        if running { start() } else { stop() }
    }

    private func start() {
        guard tap == nil, #available(macOS 14.2, *) else { return }
        let tap = SystemAudioTap()
        do {
            try tap.start { [weak self] samples, frames, channels, sampleRate in
                self?.process(samples, frames: frames, channels: channels, sampleRate: sampleRate)
            }
            self.tap = tap
        } catch {
            NSLog("MacNotch: system audio tap unavailable: \(error)")
        }
    }

    private func stop() {
        if #available(macOS 14.2, *) { (tap as? SystemAudioTap)?.stop() }
        tap = nil
        levels = [Float](repeating: 0, count: Self.bandCount)
        isLive = false
    }

    /// Runs on the tap's audio queue.
    private func process(_ samples: UnsafePointer<Float>, frames: Int, channels: Int, sampleRate: Double) {
        guard let bands = analyzer.feed(samples, frames: frames, channels: channels, sampleRate: sampleRate) else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPublish) > 1.0 / 40.0 else { return }
        lastPublish = now
        DispatchQueue.main.async { [weak self] in
            guard let self, self.tap != nil else { return }
            self.levels = bands
            // Silence from an un-permitted tap reads as all zeros; only call it live once sound arrives.
            if !self.isLive, bands.contains(where: { $0 > 0.02 }) { self.isLive = true }
        }
    }
}

/// FFT over a mono mix, reduced to log-spaced bands with peak-normalised, smoothed levels.
private final class SpectrumAnalyzer {
    private let size = 1024
    private let bandCount: Int
    private let fft: vDSP.FFT<DSPSplitComplex>?
    private let window: [Float]
    private var buffer: [Float] = []
    private var smoothed: [Float]
    private var peaks: [Float]

    init(bands: Int) {
        bandCount = bands
        fft = vDSP.FFT(log2n: vDSP_Length(log2(Double(size))), radix: .radix2, ofType: DSPSplitComplex.self)
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: size, isHalfWindow: false)
        smoothed = [Float](repeating: 0, count: bands)
        peaks = [Float](repeating: 0.01, count: bands)
        buffer.reserveCapacity(size * 2)
    }

    func feed(_ samples: UnsafePointer<Float>, frames: Int, channels: Int, sampleRate: Double) -> [Float]? {
        for frame in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels { sum += samples[frame * channels + channel] }
            buffer.append(sum / Float(channels))
        }
        guard buffer.count >= size, let fft else { return nil }
        let frame = Array(buffer.suffix(size))
        buffer.removeAll(keepingCapacity: true)

        let windowed = vDSP.multiply(frame, window)
        let half = size / 2
        var realIn = [Float](repeating: 0, count: half)
        var imagIn = [Float](repeating: 0, count: half)
        var realOut = [Float](repeating: 0, count: half)
        var imagOut = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)

        realIn.withUnsafeMutableBufferPointer { realInPtr in
            imagIn.withUnsafeMutableBufferPointer { imagInPtr in
                realOut.withUnsafeMutableBufferPointer { realOutPtr in
                    imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                        var input = DSPSplitComplex(realp: realInPtr.baseAddress!, imagp: imagInPtr.baseAddress!)
                        windowed.withUnsafeBufferPointer { samplesPtr in
                            samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                                vDSP_ctoz($0, 2, &input, 1, vDSP_Length(half))
                            }
                        }
                        var output = DSPSplitComplex(realp: realOutPtr.baseAddress!, imagp: imagOutPtr.baseAddress!)
                        fft.forward(input: input, output: &output)
                        vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(half))
                    }
                }
            }
        }

        // Band edges from 40 Hz to 14 kHz, spaced evenly on a log scale.
        let binWidth = sampleRate / Double(size)
        let low = log10(40.0), high = log10(14_000.0)
        var levels = [Float](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            let from = pow(10, low + (high - low) * Double(band) / Double(bandCount))
            let to = pow(10, low + (high - low) * Double(band + 1) / Double(bandCount))
            let first = max(1, Int(from / binWidth))
            let last = min(half - 1, max(first, Int(to / binWidth)))
            var energy: Float = 0
            for bin in first...last { energy += magnitudes[bin] }
            energy = sqrt(energy / Float(last - first + 1))

            // Each band adapts to its own recent peak, so quiet and loud music both fill the bars.
            peaks[band] = max(energy, peaks[band] * 0.995, 0.0001)
            let target = min(1, energy / peaks[band])
            let speed: Float = target > smoothed[band] ? 0.6 : 0.18
            smoothed[band] += (target - smoothed[band]) * speed
            levels[band] = smoothed[band]
        }
        return levels
    }
}

/// A private tap on everything the Mac plays, read through a private aggregate device.
@available(macOS 14.2, *)
private final class SystemAudioTap {
    enum TapError: Error { case status(String, OSStatus) }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "MacNotch.audiotap", qos: .userInteractive)

    func start(handler: @escaping (UnsafePointer<Float>, Int, Int, Double) -> Void) throws {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "MacNotch waveform"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else { throw TapError.status("create tap", status) }

        var format = AudioStreamBasicDescription()
        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var formatAddress = CA.address(kAudioTapPropertyFormat)
        AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &formatSize, &format)
        let sampleRate = format.mSampleRate > 0 ? format.mSampleRate : 48_000

        let outputID: AudioObjectID = CA.get(AudioObjectID(kAudioObjectSystemObject),
                                              kAudioHardwarePropertyDefaultOutputDevice, default: 0)
        guard let outputUID = CA.string(outputID, kAudioDevicePropertyDeviceUID) else {
            stop()
            throw TapError.status("output device", -1)
        }
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MacNotch Tap",
            kAudioAggregateDeviceUIDKey: "\(AudioSpectrum.tapUIDPrefix)-\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                               kAudioSubTapUIDKey: description.uuid.uuidString]],
        ]
        status = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard status == noErr else { stop(); throw TapError.status("aggregate device", status) }

        status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            guard let buffer = buffers.first, let data = buffer.mData else { return }
            let channels = max(1, Int(buffer.mNumberChannels))
            let frames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size / channels
            guard frames > 0 else { return }
            handler(data.assumingMemoryBound(to: Float.self), frames, channels, sampleRate)
        }
        guard status == noErr else { stop(); throw TapError.status("io proc", status) }

        status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else { stop(); throw TapError.status("start", status) }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        procID = nil
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    deinit { stop() }
}
