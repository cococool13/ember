import SwiftUI

/// Coal (docs/design/DIRECTION.md): one ground, one ink, one ember.
/// Ember is the crescent and the one accent per screen; everything else is
/// Coal and Ash.
enum Theme {
    /// Ground. `#1A1512`.
    static let coal = Color(red: 26 / 255, green: 21 / 255, blue: 18 / 255)
    /// Raised surface on Coal.
    static let coalRaised = Color(red: 36 / 255, green: 30 / 255, blue: 26 / 255)
    /// Ink. `#EFE4D6`, 14.6:1 on Coal.
    static let ashInk = Color(red: 239 / 255, green: 228 / 255, blue: 214 / 255)
    /// Secondary text on Coal. `#B3A694`, 7.6:1.
    static let ash2 = Color(red: 179 / 255, green: 166 / 255, blue: 148 / 255)
    /// `#CC6437`, 4.7:1 on Coal.
    static let ember = Color(red: 204 / 255, green: 100 / 255, blue: 55 / 255)
    /// The chrome's shadow: a burnt tint of Coal, never grey.
    static let burnt = Color(red: 9 / 255, green: 4 / 255, blue: 2 / 255)

    // Older role names, now on the Coal palette.
    static let void = coal
    static let charcoal = coalRaised
    static let graphite = Color(red: 46 / 255, green: 38 / 255, blue: 33 / 255)
    static let ash = ashInk
    static let smoke = ash2
    /// Hairlines and dividers only. Too dark for text.
    static let steel = Color(red: 62 / 255, green: 52 / 255, blue: 45 / 255)
    static let white = ashInk
    static let pillBorder = Color(red: 94 / 255, green: 82 / 255, blue: 73 / 255)
    static let pillMuted = ash2
    static let switchOff = Color(red: 94 / 255, green: 82 / 255, blue: 73 / 255)
    static let knob = ashInk

    static let cardRadius: CGFloat = 12
    static let panelRadius: CGFloat = 14
    static let hairline: CGFloat = 1
    static let panelWidth: CGFloat = 340
    static let panelHeight: CGFloat = 365

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    /// Kron's display voice, in the system face: heavy capitals, pulled tight.
    static func poster(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static let posterTracking = -0.052

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular)
    }
}

extension View {
    /// Section labels in the system face.
    func emberLabel(_ size: CGFloat = 14) -> some View {
        font(Theme.display(size))
            .textCase(.uppercase)
            .tracking(size >= 14 ? -0.02 * size : -0.01 * size)
    }

    /// Monospaced readings. Times, kelvin, percentages.
    func emberReading(_ size: CGFloat = 11) -> some View {
        font(Theme.mono(size))
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
    @Environment(\.isEnabled) private var enabled

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
            .opacity(!enabled ? 0.4 : isPressed ? 0.7 : 1)
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
            .frame(minWidth: 32, minHeight: 32)
            .contentShape(Rectangle())
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
                    .font(Theme.body(13))
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
                    .foregroundStyle(selected ? Theme.white : Theme.pillMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
                    .background(Capsule().fill(selected ? Theme.graphite : .clear))
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

/// Quiet toolbar hit targets, with the Mac focus ring supplied by Button.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(Theme.ash)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 7).fill(configuration.isPressed ? Theme.graphite : .clear))
            .contentShape(Rectangle())
    }
}

/// A real AppKit material, with a solid surface when transparency is reduced.
struct PanelMaterial: View {
    var surface = Theme.void
    var opacity = 0.65
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            surface
        } else {
            VisualEffectSurface()
                .overlay(surface.opacity(opacity))
        }
    }
}

private struct VisualEffectSurface: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
