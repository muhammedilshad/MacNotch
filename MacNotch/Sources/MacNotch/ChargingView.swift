import SwiftUI

enum ChargingPhase: Equatable {
    /// A glowing bolt sweeps in right after the charger is connected.
    case bolt
    /// "Charging…", a glowing bar filling up to the battery level, and the percentage.
    case progress
    /// "Fully Charged" at 100%.
    case full
}

struct ChargingActivity: Equatable {
    var phase: ChargingPhase
    var startedAt = Date()
}

/// The notch while the charging animation plays. Every frame is computed from the time since the
/// phase started, so the animation needs no view state.
struct ChargingView: View {
    static let green = Color(red: 0.24, green: 0.96, blue: 0.56)

    let geometry: NotchGeometry
    let activity: ChargingActivity

    @EnvironmentObject private var battery: BatteryMonitor

    static func wingWidth(for phase: ChargingPhase) -> CGFloat {
        phase == .bolt ? 70 : 150
    }

    private var wing: CGFloat { Self.wingWidth(for: activity.phase) }
    private var height: CGFloat { geometry.notchHeight }
    /// On a camera notch the middle is hidden, so the bar gets its own strip underneath.
    private var barBelow: Bool { geometry.hasHardwareNotch }
    private var level: Int { activity.phase == .full ? 100 : battery.level }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let t = max(0, context.date.timeIntervalSince(activity.startedAt))
            VStack(spacing: 0) {
                // ZStacks keep each section's width even when it has nothing to show.
                HStack(spacing: 0) {
                    ZStack { leftWing(t) }.frame(width: wing, height: height, alignment: .leading)
                    ZStack { center(t) }.frame(width: geometry.notchWidth, height: height)
                    ZStack { rightWing(t) }.frame(width: wing, height: height, alignment: .trailing)
                }
                if barBelow && activity.phase == .progress {
                    ChargeBar(fraction: fillFraction(t), time: t)
                        .frame(height: 5)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 7)
                }
            }
            .frame(width: 2 * wing + geometry.notchWidth)
        }
    }

    /// The bar eases up from empty to the current level.
    private func fillFraction(_ t: Double) -> Double {
        let progress = min(1, t / 1.4)
        let eased = 1 - pow(1 - progress, 3)
        return Double(level) / 100 * eased
    }

    @ViewBuilder private func leftWing(_ t: Double) -> some View {
        switch activity.phase {
        case .bolt:
            if barBelow {
                BoltSwoosh(time: t).padding(.leading, 6)
            }
        case .progress:
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Self.green)
                    .shadow(color: Self.green.opacity(0.9), radius: 4)
                Text("Charging…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .fixedSize()
            .padding(.leading, 12)
        case .full:
            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(Self.green)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.black)
                }
                .frame(width: 17, height: 17)
                .scaleEffect(0.6 + 0.4 * min(1, t / 0.35))
                Text("Fully Charged")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .fixedSize()
            .padding(.leading, 12)
        }
    }

    @ViewBuilder private func center(_ t: Double) -> some View {
        if !barBelow {
            switch activity.phase {
            case .bolt: BoltSwoosh(time: t).padding(.horizontal, 10)
            case .progress: ChargeBar(fraction: fillFraction(t), time: t).frame(height: 5).padding(.horizontal, 6)
            case .full: EmptyView()
            }
        }
    }

    @ViewBuilder private func rightWing(_ t: Double) -> some View {
        if activity.phase != .bolt {
            let shown = activity.phase == .full ? 100 : Int((fillFraction(t) * 100).rounded())
            HStack(spacing: 6) {
                Text("\(shown)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(shown >= 30 ? Self.green : .white)
                BatteryGlyph(fraction: Double(shown) / 100)
            }
            .fixedSize()
            .padding(.trailing, 12)
        }
    }
}

/// A bolt that pops in, trailed by a glowing swoosh drawn from left to right.
private struct BoltSwoosh: View {
    let time: Double

    var body: some View {
        let draw = min(1, time / 0.8)
        let eased = 1 - pow(1 - draw, 3)
        ZStack(alignment: .leading) {
            Canvas { context, size in
                var path = Path()
                let mid = size.height * 0.55
                for step in stride(from: 0.0, through: Double(size.width), by: 2) {
                    let x = step / Double(size.width)
                    let y = mid + size.height * 0.22 * sin(x * .pi * 1.6 + 0.6) * (1 - x * 0.4)
                    if step == 0 { path.move(to: CGPoint(x: step, y: y)) } else { path.addLine(to: CGPoint(x: step, y: y)) }
                }
                let trimmed = path.trimmedPath(from: 0, to: eased)
                context.stroke(trimmed,
                               with: .linearGradient(Gradient(colors: [ChargingView.green.opacity(0.3), ChargingView.green, .white]),
                                                     startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .shadow(color: ChargingView.green, radius: 4)
            .shadow(color: ChargingView.green.opacity(0.6), radius: 9)
            Image(systemName: "bolt.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(ChargingView.green)
                .shadow(color: ChargingView.green, radius: 6)
                .scaleEffect(0.4 + 0.6 * min(1, time / 0.25))
                .opacity(min(1, time / 0.15))
        }
    }
}

/// Glowing bar with a spray of particles at its leading edge.
private struct ChargeBar: View {
    let fraction: Double
    let time: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let head = max(proxy.size.height, width * fraction)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [ChargingView.green.opacity(0.75), ChargingView.green],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: head)
                    .shadow(color: ChargingView.green.opacity(0.9), radius: 5)
                Canvas { context, size in
                    for index in 0..<14 {
                        let seed = Double(index) * 0.618_034
                        let life = (time * 0.9 + seed).truncatingRemainder(dividingBy: 1)
                        let x = head + 2 + life * 26 + sin(seed * 40) * 3
                        let y = size.height / 2 + sin(seed * 25 + time * 3) * (2 + life * 5)
                        let r = 1.2 * (1 - life) + 0.4
                        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                                     with: .color(ChargingView.green.opacity(0.85 * (1 - life))))
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

struct BatteryGlyph: View {
    let fraction: Double

    var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1.4)
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(ChargingView.green)
                    .frame(width: max(3, 21 * fraction))
                    .padding(2.5)
            }
            .frame(width: 26, height: 13)
            Capsule()
                .fill(Color.white.opacity(0.85))
                .frame(width: 2, height: 5)
        }
    }
}
