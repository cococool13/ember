import AppKit
import Foundation

enum ColorApps {
    static let bundleIDs: Set<String> = [
        "com.apple.Photos",
        "com.apple.Preview",
        "com.apple.ColorSyncUtility",
        "com.apple.DigitalColorMeter",
        "com.apple.FinalCut",
        "com.apple.motionapp",
        "com.bohemiancoding.sketch3",
        "com.figma.Desktop",
        "com.adobe.Photoshop",
        "com.adobe.LightroomClassicCC7",
        "com.adobe.Lightroom",
        "com.adobe.illustrator",
        "com.blackmagic-design.DaVinciResolve",
        "com.pixelmatorteam.pixelmator.x",
        "com.pixelmatorteam.pixelmator",
        "com.seriflabs.affinityphoto2",
        "com.seriflabs.affinitydesigner2",
        "com.captureone.captureone"
    ]

    static func match(_ app: NSRunningApplication?) -> String? {
        guard let id = app?.bundleIdentifier, bundleIDs.contains(id) else { return nil }
        return app?.localizedName ?? id
    }
}
