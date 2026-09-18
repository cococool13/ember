import SwiftUI

enum Theme {
    static let void = Color(red: 11 / 255, green: 11 / 255, blue: 11 / 255)
    static let charcoal = Color(red: 39 / 255, green: 42 / 255, blue: 42 / 255)
    static let ember = Color(red: 204 / 255, green: 100 / 255, blue: 55 / 255)
    static let ash = Color(red: 206 / 255, green: 206 / 255, blue: 206 / 255)
    static let steel = Color(red: 72 / 255, green: 72 / 255, blue: 72 / 255)
    static let white = Color.white

    static let cardRadius: CGFloat = 10
    static let hairline: CGFloat = 1

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
    func emberLabel(_ size: CGFloat = 14) -> some View {
        self
            .font(Theme.display(size))
            .textCase(.uppercase)
            .tracking(size >= 14 ? -0.02 * size : -0.01 * size)
            .fontWeight(.regular)
    }

    func emberBody() -> some View {
        self
            .font(Theme.body(15))
            .foregroundStyle(Theme.ash)
            .fixedSize(horizontal: false, vertical: true)
    }
}
