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

    /// Small uppercase section label above a group.
    func emberEyebrow() -> some View {
        self
            .font(Theme.display(12))
            .textCase(.uppercase)
            .tracking(0.3)
            .foregroundStyle(Theme.smoke)
    }

    /// Roboto Mono reading. Times, kelvin, percentages.
    func emberReading(_ size: CGFloat = 11) -> some View {
        self
            .font(Theme.mono(size))
            .tracking(-0.22)
            .textCase(.uppercase)
    }

    func emberBody(_ size: CGFloat = 15) -> some View {
        self
            .font(Theme.body(size))
            .foregroundStyle(Theme.ash)
            .fixedSize(horizontal: false, vertical: true)
    }

    func emberCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.charcoal)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

struct GhostPillStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .emberLabel(14)
            .foregroundStyle(emphasized ? Theme.ember : Theme.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .contentShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        (emphasized ? Theme.ember : Theme.ash).opacity(configuration.isPressed ? 0.5 : 1),
                        lineWidth: Theme.hairline
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Small round hairline button for steppers.
struct RoundGlyphStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .emberLabel(16)
            .foregroundStyle(Theme.white)
            .frame(width: 28, height: 28)
            .contentShape(Circle())
            .overlay(Circle().stroke(Theme.ash.opacity(configuration.isPressed ? 0.5 : 0.8), lineWidth: Theme.hairline))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Sunlitt-style utility toggle: label, quiet caption, ghost pill state.
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
            Button(isOn ? "On" : "Off") { isOn.toggle() }
                .buttonStyle(GhostPillStyle(emphasized: isOn))
                .accessibilityLabel("\(title) \(isOn ? "on" : "off")")
        }
        .padding(.vertical, 12)
    }
}

/// Ghost pills in a row; the chosen one carries the rust hairline.
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
                    .emberLabel(12)
                    .foregroundStyle(selected ? Theme.ember : Theme.ash)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Capsule())
                    .overlay(
                        Capsule().stroke(selected ? Theme.ember : Theme.steel, lineWidth: Theme.hairline)
                    )
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
