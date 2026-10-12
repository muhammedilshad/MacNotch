import AppKit
import Combine
import SwiftUI

/// Size of the physical camera notch, or of the virtual one drawn on Macs without a notch.
struct NotchGeometry: Equatable {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var hasHardwareNotch: Bool

    static let fallback = NotchGeometry(notchWidth: 180, notchHeight: 28, hasHardwareNotch: false)

    static func detect(on screen: NSScreen) -> NotchGeometry {
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            return NotchGeometry(notchWidth: screen.frame.width - left.width - right.width,
                                 notchHeight: screen.safeAreaInsets.top,
                                 hasHardwareNotch: true)
        }
        // Intel Macs and external displays: match the menu bar height (it is 0 when auto-hidden).
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        let height = menuBar >= 20 ? min(menuBar, 40) : 28
        return NotchGeometry(notchWidth: 180, notchHeight: height, hasHardwareNotch: false)
    }
}

/// A message that drops out of the notch: reminders, timers, battery alerts, OCR results.
struct NotchBanner: Identifiable, Equatable {
    struct Action: Identifiable {
        let id = UUID()
        let title: String
        var primary = false
        let perform: () -> Void
    }

    let id = UUID()
    var symbol: String
    var tint: Color
    var title: String
    var subtitle: String?
    var trailing: String?
    var actions: [Action] = []
    /// Seconds before it hides itself; nil keeps it until an action is clicked.
    var duration: TimeInterval? = 6

    static func == (lhs: NotchBanner, rhs: NotchBanner) -> Bool { lhs.id == rhs.id }
}

final class NotchModel: ObservableObject {
    @Published var geometry: NotchGeometry = .fallback
    @Published var expanded = false
    @Published var shapeSize: CGSize = .zero
    @Published var charging: ChargingActivity?
    @Published var banner: NotchBanner?
    @Published var tab: DashboardTab = .home
    /// True while files are being dragged anywhere on screen, so the notch can open its shelf.
    @Published var draggingFiles = false
    @Published var dropTargeted = false
}

/// A borderless panel that sits above the menu bar on every Space, including full-screen apps.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

extension View {
    /// Every shared object the notch views read.
    func notchEnvironment(_ model: NotchModel) -> some View {
        environmentObject(model)
            .environmentObject(AppSettings.shared)
            .environmentObject(NowPlayingMonitor.shared)
            .environmentObject(BatteryMonitor.shared)
            .environmentObject(CalendarMonitor.shared)
            .environmentObject(AudioController.shared)
            .environmentObject(AudioSpectrum.shared)
            .environmentObject(SystemMonitor.shared)
            .environmentObject(PrivacyMonitor.shared)
            .environmentObject(ClipboardMonitor.shared)
            .environmentObject(ShelfStore.shared)
            .environmentObject(TransferMonitor.shared)
            .environmentObject(FocusTimer.shared)
            .environmentObject(NotificationHub.shared)
    }
}

final class NotchController {
    static let shared = NotchController()

    /// The panel is a fixed transparent canvas; the notch shape grows inside it.
    static let canvasSize = CGSize(width: 820, height: 300)

    let model = NotchModel()
    private var panel: NotchPanel?
    private var timer: Timer?
    private var mouseMonitors: [Any] = []
    private var peekUntil: Date?
    private var chargingSteps: [DispatchWorkItem] = []
    private var bannerQueue: [NotchBanner] = []
    private var bannerDismissal: DispatchWorkItem?
    private var dragBaseline = NSPasteboard(name: .drag).changeCount
    private var chargeLimitShown = false
    private var lowBatteryShown: Set<Int> = []
    private var cancellables = Set<AnyCancellable>()

    func start() {
        let settings = AppSettings.shared
        settings.$notchEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in enabled ? self?.show() : self?.hide() }
            .store(in: &cancellables)

        let player = NowPlayingMonitor.shared
        player.$track
            .removeDuplicates()
            .dropFirst()
            .compactMap { $0 }
            .sink { [weak self] _ in self?.peek() }
            .store(in: &cancellables)
        player.$isPlaying
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in self?.peek() }
            .store(in: &cancellables)

        startFeatures()
        startBatteryWatch()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.reposition()
        }
    }

    /// Starts and stops each background monitor as its setting changes.
    private func startFeatures() {
        let settings = AppSettings.shared
        settings.$showCalendar
            .filter { $0 }
            .sink { _ in CalendarMonitor.shared.start() }
            .store(in: &cancellables)
        settings.$clipboardEnabled
            .combineLatest(settings.$enabledTabs)
            .sink { enabled, tabs in ClipboardMonitor.shared.setRunning(enabled && tabs.contains(.clipboard)) }
            .store(in: &cancellables)
        settings.$downloadsMonitor
            .combineLatest(settings.$enabledTabs)
            .sink { enabled, tabs in TransferMonitor.shared.setRunning(enabled && tabs.contains(.shelf)) }
            .store(in: &cancellables)
        settings.$notificationHub
            .combineLatest(settings.$enabledTabs)
            .sink { enabled, tabs in NotificationHub.shared.setRunning(enabled && tabs.contains(.notifications)) }
            .store(in: &cancellables)
        settings.$privacyIndicators
            .sink { PrivacyMonitor.shared.setRunning($0) }
            .store(in: &cancellables)

        // The real-audio waveform only listens while music plays and the bars are on screen.
        settings.$reactiveWaveform
            .combineLatest(settings.$animateMusicBars, settings.$showMusic, settings.$notchEnabled)
            .map { $0 && $1 && $2 && $3 }
            .combineLatest(NowPlayingMonitor.shared.$isPlaying)
            .map { $0 && $1 }
            .removeDuplicates()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { AudioSpectrum.shared.setRunning($0) }
            .store(in: &cancellables)

        CalendarMonitor.shared.onReminder = { [weak self] event in self?.showReminder(for: event) }
        FocusTimer.shared.onFinish = { [weak self] finished in self?.showFocusFinished(finished) }
    }

    private func peek() {
        let settings = AppSettings.shared
        guard settings.peekOnTrackChange, settings.showMusic, model.banner == nil else { return }
        if !model.expanded { model.tab = .home }
        peekUntil = Date().addingTimeInterval(3.5)
    }

    // MARK: Charging animation and smart charging

    private func startBatteryWatch() {
        // BatteryMonitor reads its state synchronously on start, so dropFirst skips the current value.
        let battery = BatteryMonitor.shared
        battery.$isPluggedIn
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] pluggedIn in
                guard let self else { return }
                if pluggedIn {
                    self.lowBatteryShown.removeAll()
                    self.chargerConnected()
                } else {
                    self.chargeLimitShown = false
                    self.stopChargingAnimation()
                }
            }
            .store(in: &cancellables)
        battery.$level
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] level in self?.levelChanged(to: level) }
            .store(in: &cancellables)
    }

    private func levelChanged(to level: Int) {
        let settings = AppSettings.shared
        let battery = BatteryMonitor.shared
        if battery.isPluggedIn {
            if level >= 100, settings.chargingAnimation {
                playChargingAnimation(full: true)
            } else if settings.chargeLimitAlert > 0, level >= settings.chargeLimitAlert, !chargeLimitShown {
                chargeLimitShown = true
                showBanner(NotchBanner(symbol: "leaf.fill", tint: ChargingView.green,
                                       title: "Battery at \(level)%",
                                       subtitle: "Unplug now to help keep your battery healthy",
                                       trailing: "\(level)%",
                                       actions: [.init(title: "OK", primary: true) {}],
                                       duration: 15))
            }
        } else if settings.lowBatteryAlerts, battery.hasBattery,
                  let threshold = [5, 10, 20].first(where: { level <= $0 }), !lowBatteryShown.contains(threshold) {
            lowBatteryShown.formUnion([5, 10, 20].filter { $0 >= threshold })
            let left = battery.minutesToEmpty.map { "About \(TimeText.duration(TimeInterval($0 * 60))) left" }
            showBanner(NotchBanner(symbol: level <= 10 ? "battery.0percent" : "battery.25percent",
                                   tint: level <= 10 ? .red : .orange,
                                   title: "Low Battery",
                                   subtitle: left ?? "Connect your charger soon",
                                   trailing: "\(level)%",
                                   actions: [.init(title: "OK", primary: true) {}],
                                   duration: 12))
        }
    }

    private func chargerConnected() {
        guard AppSettings.shared.chargingAnimation else { return }
        playChargingAnimation(full: BatteryMonitor.shared.level >= 100)
    }

    /// Plays the plug-in sequence (bolt, then the filling bar) or the "Fully Charged" banner.
    /// Also used by the preview buttons in the main window.
    func playChargingAnimation(full: Bool) {
        let steps: [(ChargingPhase?, TimeInterval)] = full
            ? [(.full, 0), (nil, 3.5)]
            : [(.bolt, 0), (.progress, 1.1), (nil, 5.8)]
        stopChargingAnimation()
        for (phase, delay) in steps {
            let step = DispatchWorkItem { [weak self] in self?.setChargingPhase(phase) }
            chargingSteps.append(step)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: step)
        }
    }

    private func stopChargingAnimation() {
        chargingSteps.forEach { $0.cancel() }
        chargingSteps.removeAll()
        setChargingPhase(nil)
    }

    private func setChargingPhase(_ phase: ChargingPhase?) {
        let activity = phase.map { ChargingActivity(phase: $0) }
        guard activity?.phase != model.charging?.phase else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            model.charging = activity
        }
    }

    // MARK: Banners

    private var bannerAnimation: Animation {
        AppSettings.shared.animateBanners ? .spring(response: 0.42, dampingFraction: 0.74) : .easeInOut(duration: 0.15)
    }

    func showBanner(_ banner: NotchBanner) {
        if model.banner == nil {
            present(banner)
        } else {
            bannerQueue.append(banner)
        }
    }

    private func present(_ banner: NotchBanner) {
        peekUntil = nil
        withAnimation(bannerAnimation) {
            model.expanded = false
            model.banner = banner
        }
        scheduleDismissal(of: banner, after: banner.duration)
    }

    private func scheduleDismissal(of banner: NotchBanner, after delay: TimeInterval?) {
        bannerDismissal?.cancel()
        guard let delay else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.model.banner?.id == banner.id else { return }
            // Stay up while the pointer is over the banner.
            if self.isPointerOverShape() {
                self.scheduleDismissal(of: banner, after: 2)
            } else {
                self.dismissBanner()
            }
        }
        bannerDismissal = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func dismissBanner() {
        bannerDismissal?.cancel()
        withAnimation(bannerAnimation) { model.banner = nil }
        guard !bannerQueue.isEmpty else { return }
        let next = bannerQueue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.present(next) }
    }

    func perform(_ action: NotchBanner.Action) {
        action.perform()
        dismissBanner()
    }

    private func showReminder(for event: CalendarMonitor.Event) {
        let calendar = CalendarMonitor.shared
        var actions: [NotchBanner.Action] = []
        if event.meetingURL != nil {
            actions.append(.init(title: "Join", primary: true) { calendar.join(event) })
        }
        actions.append(.init(title: "Snooze 5 min", primary: event.meetingURL == nil) { calendar.snooze(event) })
        actions.append(.init(title: "Dismiss") {})
        let style = Date.FormatStyle(date: .omitted, time: .shortened)
        NSSound(named: "Tink")?.play()
        showBanner(NotchBanner(symbol: event.meetingURL != nil ? "video.fill" : "calendar",
                               tint: Color(nsColor: event.color),
                               title: event.title,
                               subtitle: "\(event.start.formatted(style)) – \(event.end.formatted(style))",
                               trailing: CalendarMonitor.countdown(to: event),
                               actions: actions,
                               duration: 45))
    }

    private func showFocusFinished(_ finished: FocusTimer.Mode) {
        let timer = FocusTimer.shared
        let next = timer.mode
        let wasFocus = finished == .focus
        showBanner(NotchBanner(symbol: wasFocus ? "checkmark.circle.fill" : "cup.and.saucer.fill",
                               tint: wasFocus ? .orange : .teal,
                               title: wasFocus ? "Focus session done" : "Break's over",
                               subtitle: wasFocus
                                ? "Take a \(TimeText.duration(timer.duration(of: next))) \(next == .longBreak ? "long break" : "break")"
                                : "Ready for another focus session?",
                               trailing: "\(timer.completedSessions) done",
                               actions: [.init(title: "Start \(next.title.lowercased())", primary: true) { timer.start() },
                                         .init(title: "Later") {}],
                               duration: 30))
    }

    // MARK: Screenshot OCR

    func captureScreenText() {
        peekUntil = nil
        model.expanded = false
        TextRecognizer.captureScreenText { [weak self] outcome in self?.showOCRResult(outcome) }
    }

    func recognizeText(in url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = TextRecognizer.recognizeAndCopy(imageAt: url)
            DispatchQueue.main.async { self?.showOCRResult(outcome) }
        }
    }

    private func showOCRResult(_ outcome: TextRecognizer.Outcome) {
        switch outcome {
        case .copied(let text):
            let lines = text.split(separator: "\n").count
            showBanner(NotchBanner(symbol: "text.viewfinder", tint: .accentBlue, title: "Text copied",
                                   subtitle: text.split(separator: "\n").first.map(String.init),
                                   trailing: lines == 1 ? "1 line" : "\(lines) lines"))
        case .noText:
            showBanner(NotchBanner(symbol: "text.viewfinder", tint: .orange, title: "No text found",
                                   subtitle: "Try selecting a larger or sharper area"))
        case .failed(let message):
            showBanner(NotchBanner(symbol: "exclamationmark.triangle.fill", tint: .orange, title: "Couldn't read the screen",
                                   subtitle: message))
        case .cancelled:
            break
        }
    }

    // MARK: Window

    private func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }

    private func show() {
        if panel == nil {
            let panel = NotchPanel(contentRect: NSRect(origin: .zero, size: Self.canvasSize),
                                   styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            // Above the menu bar and its status items, so nothing is drawn over the notch.
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
            panel.colorSpace = .sRGB
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            panel.isMovable = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true

            let host = NSHostingView(rootView: NotchRootView().notchEnvironment(model))
            host.sizingOptions = []
            host.frame = NSRect(origin: .zero, size: Self.canvasSize)
            panel.contentView = host
            self.panel = panel
        }
        reposition()
        panel?.orderFrontRegardless()

        if timer == nil {
            // The timer drives the "peek" after a song starts; mouse monitors make hover instant.
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        if mouseMonitors.isEmpty {
            let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseUp]
            if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in self?.tick() }) {
                mouseMonitors.append(global)
            }
            if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
                self?.tick()
                return event
            }) {
                mouseMonitors.append(local)
            }
        }
    }

    private func hide() {
        timer?.invalidate()
        timer = nil
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors.removeAll()
        panel?.orderOut(nil)
        model.expanded = false
    }

    private func reposition() {
        guard let panel, let screen = targetScreen() else { return }
        model.geometry = NotchGeometry.detect(on: screen)
        let size = Self.canvasSize
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2,
                              y: screen.frame.maxY - size.height,
                              width: size.width, height: size.height),
                       display: true)
    }

    private func hotZone(for size: CGSize) -> CGRect {
        guard let frame = panel?.frame else { return .zero }
        return CGRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    private func isPointerOverShape() -> Bool {
        hotZone(for: model.shapeSize).insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation)
    }

    /// Notices files being dragged anywhere, by watching the drag pasteboard while the button is down.
    private func updateFileDrag() {
        let pasteboard = NSPasteboard(name: .drag)
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            dragBaseline = pasteboard.changeCount
            if model.draggingFiles { model.draggingFiles = false }
            return
        }
        if !model.draggingFiles, pasteboard.changeCount != dragBaseline,
           pasteboard.types?.contains(.fileURL) == true {
            model.draggingFiles = true
        }
    }

    /// Hover tracking. Over the notch the panel takes every click, so nothing in the
    /// menu bar underneath is ever triggered; elsewhere clicks pass straight through.
    private func tick() {
        guard let panel, panel.isVisible else { return }
        let settings = AppSettings.shared
        updateFileDrag()

        // The charging animation is display-only: it never expands and lets clicks through.
        if model.charging != nil {
            if model.expanded { model.expanded = false }
            if !panel.ignoresMouseEvents { panel.ignoresMouseEvents = true }
            return
        }
        // Banners take clicks on their buttons but don't expand into the dashboard.
        if model.banner != nil {
            if model.expanded { model.expanded = false }
            let passThrough = !isPointerOverShape()
            if panel.ignoresMouseEvents != passThrough { panel.ignoresMouseEvents = passThrough }
            return
        }

        let layout = NotchLayout(geometry: model.geometry, settings: settings, player: NowPlayingMonitor.shared,
                                 battery: BatteryMonitor.shared, tab: model.tab)

        // Use the computed size rather than only the measured one, so hit-testing never lags the drawing.
        var size = layout.collapsedSize
        if model.expanded {
            let minimum = layout.minimumExpandedSize
            size = CGSize(width: max(model.shapeSize.width, minimum.width),
                          height: max(model.shapeSize.height, minimum.height))
        }
        // A dragged file gets a more generous target.
        let margin: CGFloat = model.draggingFiles && !model.expanded ? 24 : 2
        let inside = hotZone(for: size).insetBy(dx: -margin, dy: -margin).contains(NSEvent.mouseLocation)

        let dropping = model.draggingFiles && inside && settings.isTabEnabled(.shelf)
        if dropping && !model.expanded { model.tab = .shelf }

        let peeking = (peekUntil ?? .distantPast) > Date()
        let shouldExpand = (inside && (settings.expandOnHover || dropping)) || peeking
        if shouldExpand != model.expanded { model.expanded = shouldExpand }

        let passThrough = !inside
        if panel.ignoresMouseEvents != passThrough { panel.ignoresMouseEvents = passThrough }
    }
}

private struct ShapeSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

struct NotchRootView: View {
    @EnvironmentObject private var model: NotchModel

    var body: some View {
        VStack(spacing: 0) {
            NotchContentView(geometry: model.geometry, expanded: model.expanded, charging: model.charging)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ShapeSizeKey.self, value: proxy.size)
                })
            Spacer(minLength: 0)
        }
        .frame(width: NotchController.canvasSize.width, height: NotchController.canvasSize.height, alignment: .top)
        .onPreferenceChange(ShapeSizeKey.self) { model.shapeSize = $0 }
    }
}
