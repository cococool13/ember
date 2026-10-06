import SwiftUI

/// Ciridae, elevated. Void base, two warm charcoal stages, one rust accent.
/// Rust is for hairlines, the live marker, and the reading that matters now.
enum Theme {
    static let void = Color(red: 11 / 255, green: 11 / 255, blue: 11 / 255)
    static let charcoal = Color(red: 39 / 255, green: 42 / 255, blue: 42 / 255)
    /// Raised stage inside a card: a shade warmer than charcoal.
    static let graphite = Color(red: 48 / 255, green: 50 / 255, blue: 49 / 255)
    static let ember = Color(red: 204 / 255, green: 100 / 255, blue: 55 / 255)
    static let ash = Color(red: 206 / 255, green: 206 / 255, blue: 206 / 255)
    /// Secondary text. Warm mid gray; 6.1:1 on void, 4.5:1 on charcoal.
    static let smoke = Color(red: 146 / 255, green: 143 / 255, blue: 138 / 255)
    /// Hairlines and dividers only. Too dark for text.
    static let steel = Color(red: 72 / 255, green: 72 / 255, blue: 72 / 255)
    static let white = Color.white
    /// Website mini-button border (`#626662`) and muted pill label.
    static let pillBorder = Color(red: 98 / 255, green: 102 / 255, blue: 98 / 255)
    static let pillMuted = Color(red: 174 / 255, green: 181 / 255, blue: 173 / 255)
    static let switchOff = Color(red: 91 / 255, green: 95 / 255, blue: 92 / 255)
    static let knob = Color(red: 248 / 255, green: 248 / 255, blue: 246 / 255)

    static let cardRadius: CGFloat = 12
    static let panelRadius: CGFloat = 14
    static let hairline: CGFloat = 1
    static let panelWidth: CGFloat = 360

    static func display(_ size: CGFloat) -> Font {
        .custom("Barlow Condensed", size: size, relativeTo: .body)
    }

    static func mono(_ size: CGFloat) -> Font {
        .custom("Roboto Mono", size: size, relativeTo: .caption)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular)
    }
}

extension View {
    /// Barlow Condensed 400, uppercase. Titles and labels.
    func emberLabel(_ size: CGFloat = 14) -> some View {
        self
            .font(Theme.display(size))
            .textCase(.uppercase)
            .tracking(size >= 14 ? -0.02 * size : -0.01 * size)
            .fontWeight(.regular)
    }

    /// Roboto Mono reading. Times, kelvin, percentages.
    func emberReading(_ size: CGFloat = 11) -> some View {
        self
            .font(Theme.mono(size))
            .tracking(-0.22)
            .textCase(.uppercase)
    }

    func emberCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.charcoal)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

/// Website mini-button: tight capsule, hairline, rust only when it is the active state.
struct MiniPillStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        MiniPillBody(emphasized: emphasized, isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

private struct MiniPillBody<Label: View>: View {
    var emphasized: Bool
    var isPressed: Bool
    @ViewBuilder var label: () -> Label
    @State private var hover = false

    var body: some View {
        label()
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(emphasized ? Theme.ember : Theme.ash)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .contentShape(Capsule())
            .background(Capsule().fill(Color.white.opacity(hover && !isPressed ? 0.06 : 0)))
            .overlay(
                Capsule().stroke(
                    (emphasized ? Theme.ember : Theme.pillBorder).opacity(isPressed ? 0.5 : 1),
                    lineWidth: Theme.hairline
                )
            )
            .opacity(isPressed ? 0.7 : 1)
            .onHover { hover = $0 }
    }
}

/// Small round hairline stepper, same border as the website mini-button.
struct RoundGlyphStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.ash)
            .frame(width: 22, height: 22)
            .contentShape(Circle())
            .overlay(
                Circle().stroke(Theme.pillBorder.opacity(configuration.isPressed ? 0.5 : 1), lineWidth: Theme.hairline)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Website switch: 30×18 track, rust when on, white knob.
struct EmberSwitch: View {
    @Binding var isOn: Bool
    var label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Theme.ember : Theme.switchOff)
                    .frame(width: 30, height: 18)
                Circle()
                    .fill(Theme.knob)
                    .frame(width: 12, height: 12)
                    .padding(3)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

/// Label on the left, website switch on the right.
struct ToggleRow: View {
    var title: String
    var caption: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .emberLabel(14)
                    .foregroundStyle(Theme.white)
                if let caption {
                    Text(caption)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.smoke)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            EmberSwitch(isOn: $isOn, label: title)
        }
        .padding(.vertical, 12)
    }
}

/// Equal pills. The chosen one takes the rust hairline, like the website night control.
struct SegmentedPills<Option: Hashable>: View {
    var options: [Option]
    var label: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button(label(option)) { selection = option }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selected ? Theme.ember : Theme.pillMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 26)
                    .contentShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            selected ? Theme.ember : Color.white.opacity(0.13),
                            lineWidth: Theme.hairline
                        )
                    )
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
