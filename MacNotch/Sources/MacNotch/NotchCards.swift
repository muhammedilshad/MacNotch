import AppKit
import SwiftUI

/// Now-playing card: artwork with the playing app's icon, song details, a scrubbable progress bar,
/// playback and Spotify controls, the output device menu and a volume slider.
struct MusicCard: View {
    @EnvironmentObject private var player: NowPlayingMonitor
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var audio: AudioController

    private static let artworkSize: CGFloat = 76

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                if let track = player.track {
                    details(track)
                    if settings.showProgress, player.timing != nil { progress }
                    controls
                    if settings.showVolume { volume }
                } else {
                    emptyState
                }
            }
        }
    }

    // MARK: Pieces

    @ViewBuilder private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack(alignment: .bottomTrailing) {
            if let image = player.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Self.artworkSize, height: Self.artworkSize)
                    .clipShape(shape)
            } else {
                shape
                    .fill(Color.white.opacity(0.08))
                    .frame(width: Self.artworkSize, height: Self.artworkSize)
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45)))
            }
            if let icon = player.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .offset(x: 6, y: 6)
            }
        }
        .onTapGesture { player.openPlayer() }
        .help(player.track.map { "Open \($0.source)" } ?? "")
    }

    private func details(_ track: NowPlayingMonitor.Track) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(track.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            let subtitle = [track.artist, track.album == track.title ? "" : track.album]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            Text(subtitle.isEmpty ? track.source : subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
        }
        .lineLimit(1)
    }

    private var progress: some View {
        TimelineView(.periodic(from: Date(), by: 0.5)) { context in
            let duration = player.timing?.duration ?? 1
            let position = player.position(at: context.date)
            HStack(spacing: 6) {
                Text(TimeText.clock(position))
                ScrubBar(value: position / max(duration, 1), enabled: player.canSeek) { fraction in
                    player.seek(to: fraction * duration)
                }
                Text("-" + TimeText.clock(max(0, duration - position)))
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            if settings.spotifyControls && player.isSpotify {
                toggleButton("shuffle", on: player.spotifyShuffle) { player.toggleSpotifyShuffle() }
            }
            controlButton("backward.fill") { player.send(.previous) }
            controlButton(player.isPlaying ? "pause.fill" : "play.fill", size: 17) { player.send(.togglePlayPause) }
            controlButton("forward.fill") { player.send(.next) }
            if settings.spotifyControls && player.isSpotify {
                toggleButton("repeat", on: player.spotifyRepeat) { player.toggleSpotifyRepeat() }
            }
            Spacer(minLength: 4)
            OutputDeviceMenu()
            if player.isPlaying {
                MusicBars(playing: true)
                    .frame(width: 20, height: 13)
                    .padding(.leading, 4)
            }
        }
    }

    private var volume: some View {
        HStack(spacing: 6) {
            Button { audio.setMuted(!audio.isMuted) } label: {
                Image(systemName: audio.isMuted || audio.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 14)
            }
            .buttonStyle(.plain)
            ScrubBar(value: audio.isMuted ? 0 : Double(audio.volume), enabled: audio.canSetVolume, continuous: true) { value in
                audio.setVolume(Float(value))
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not playing")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Play music or a video in any app")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
            if let spotify = AppInfo.lookup(NowPlayingMonitor.spotifyBundleID) {
                Button { player.launchSpotify(play: true) } label: {
                    HStack(spacing: 6) {
                        Image(nsImage: spotify.icon).resizable().frame(width: 16, height: 16)
                        Text("Play on Spotify").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.85)))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat = 14, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleButton(_ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(on ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.45))
                .frame(width: 24, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// AirPlay-style menu for choosing the speaker and microphone.
struct OutputDeviceMenu: View {
    @EnvironmentObject private var audio: AudioController

    var body: some View {
        Menu {
            Section("Output") {
                ForEach(audio.outputs) { device in
                    Button { audio.makeDefaultOutput(device) } label: {
                        if device.id == audio.defaultOutput {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            }
            Section("Input") {
                ForEach(audio.inputs) { device in
                    Button { audio.makeDefaultInput(device) } label: {
                        if device.id == audio.defaultInput {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "airplayaudio")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sound output and input")
    }
}

/// Thin slider that thickens while dragged. `continuous` reports every change (volume);
/// otherwise only the final value is reported (seeking).
struct ScrubBar: View {
    let value: Double
    var enabled = true
    var continuous = false
    var tint: Color = .white
    let onChange: (Double) -> Void

    @StateObject private var drag = DragState()

    final class DragState: ObservableObject {
        @Published var value: Double?
    }

    var body: some View {
        GeometryReader { proxy in
            let shown = min(1, max(0, drag.value ?? value))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(tint.opacity(enabled ? 0.9 : 0.4))
                    .frame(width: max(0, proxy.size.width * shown))
            }
            .frame(height: drag.value == nil ? 4 : 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    guard enabled else { return }
                    let fraction = min(1, max(0, gesture.location.x / max(proxy.size.width, 1)))
                    drag.value = fraction
                    if continuous { onChange(fraction) }
                }
                .onEnded { _ in
                    guard enabled, let final = drag.value else { return }
                    onChange(final)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { drag.value = nil }
                })
            .animation(.easeOut(duration: 0.12), value: drag.value == nil)
        }
        .frame(height: 12)
    }
}

/// Month, a strip of days centred on today, and today's events with a countdown to the next one.
struct CalendarCard: View {
    @EnvironmentObject private var calendar: CalendarMonitor

    private static let dayOffsets = Array(-2...2)

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 8) {
                header(today: context.date)
                events(now: context.date)
            }
        }
    }

    private func header(today: Date) -> some View {
        let cal = Calendar.current
        return HStack(alignment: .bottom, spacing: 8) {
            Text(today.formatted(.dateTime.month(.abbreviated)))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize()

            HStack(spacing: 0) {
                ForEach(Self.dayOffsets, id: \.self) { offset in
                    let day = cal.date(byAdding: .day, value: offset, to: today) ?? today
                    let isToday = offset == 0
                    VStack(spacing: 0) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Color.accentBlue)
                            .opacity(isToday ? 1 : 0)
                        Text("\(cal.component(.day, from: day))")
                            .font(.system(size: isToday ? 17 : 12, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isToday ? Color.accentBlue : .white.opacity(0.55))
                            .monospacedDigit()
                    }
                    .frame(width: 24)
                }
            }
            // Days fade out towards the edges, like a scrolling wheel.
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                         .init(color: .black, location: 0.3),
                                         .init(color: .black, location: 0.7),
                                         .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
        }
    }

    @ViewBuilder private func events(now: Date) -> some View {
        if calendar.access == .denied {
            emptyState(symbol: "calendar.badge.exclamationmark", text: "Allow calendar access in System Settings")
        } else if calendar.events.isEmpty {
            emptyState(symbol: "calendar", text: "Nothing for today")
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(calendar.events.prefix(2)) { event in
                    HStack(spacing: 7) {
                        Capsule()
                            .fill(Color(nsColor: event.color))
                            .frame(width: 3, height: 24)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(Self.subtitle(event, now: now))
                                .font(.system(size: 9.5))
                                .foregroundStyle(event.id == calendar.nextEvent?.id ? Color.accentBlue : .white.opacity(0.5))
                        }
                        .lineLimit(1)
                        Spacer(minLength: 0)
                        if event.meetingURL != nil {
                            Button { calendar.join(event) } label: {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.black)
                                    .frame(width: 20, height: 18)
                                    .background(Capsule().fill(Color.green))
                            }
                            .buttonStyle(.plain)
                            .help("Join meeting")
                        }
                    }
                }
            }
        }
    }

    private func emptyState(symbol: String, text: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 12))
            Text(text).font(.system(size: 11)).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.5))
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private static func subtitle(_ event: CalendarMonitor.Event, now: Date) -> String {
        if event.isAllDay { return "All day" }
        let style = Date.FormatStyle(date: .omitted, time: .shortened)
        let time = event.start.formatted(style)
        return event.end > now && event.start < now.addingTimeInterval(12 * 3600)
            ? "\(time) · \(CalendarMonitor.countdown(to: event, from: now))"
            : time
    }
}

/// Clock, date, custom text and world clocks.
struct ClockCard: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if settings.showTime {
                ClockText(fontSize: 22, compact: false)
            }
            if settings.showDate {
                DateText(fontSize: 12)
            }
            if settings.showCustomText {
                let text = settings.customText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            if !settings.worldClocks.isEmpty {
                TimelineView(.everyMinute) { context in
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(settings.worldClocks.prefix(3), id: \.self) { identifier in
                            WorldClockRow(identifier: identifier, date: context.date, use24Hour: settings.use24Hour)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

struct WorldClockRow: View {
    let identifier: String
    let date: Date
    let use24Hour: Bool

    var body: some View {
        if let zone = TimeZone(identifier: identifier) {
            HStack(spacing: 4) {
                Text(WorldClock.city(identifier))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(WorldClock.time(date, in: zone, use24Hour: use24Hour))
                    .foregroundStyle(.white.opacity(0.9))
                    .monospacedDigit()
                if let offset = WorldClock.dayOffset(date, in: zone) {
                    Text(offset)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.accentBlue)
                }
            }
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
        }
    }
}

enum WorldClock {
    static func city(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }

    static func time(_ date: Date, in zone: TimeZone, use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }

    /// "+1" or "-1" when that city is already on another day.
    static func dayOffset(_ date: Date, in zone: TimeZone) -> String? {
        var there = Calendar(identifier: .gregorian)
        there.timeZone = zone
        let local = Calendar.current
        let a = local.dateComponents([.year, .month, .day], from: date)
        let b = there.dateComponents([.year, .month, .day], from: date)
        guard let localDay = local.date(from: a), let remoteDay = local.date(from: b) else { return nil }
        let difference = local.dateComponents([.day], from: localDay, to: remoteDay).day ?? 0
        return difference == 0 ? nil : (difference > 0 ? "+\(difference)" : "\(difference)")
    }

    static func offsetDescription(_ identifier: String) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return "" }
        let hours = Double(zone.secondsFromGMT() - TimeZone.current.secondsFromGMT()) / 3600
        if hours == 0 { return "Same time" }
        let value = hours.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(hours)) : String(format: "%.1f", hours)
        return hours > 0 ? "+\(value) h" : "\(value) h"
    }
}

extension Color {
    static let accentBlue = Color(red: 0.24, green: 0.56, blue: 1.0)
}
