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
        "com.adobe.PremierePro",
        "com.adobe.AfterEffects",
        "com.blackmagic-design.DaVinciResolve",
        "com.pixelmatorteam.pixelmator.x",
        "com.pixelmatorteam.pixelmator",
        "com.seriflabs.affinityphoto2",
        "com.seriflabs.affinitydesigner2",
        "com.seriflabs.affinitypublisher2",
        "com.captureone.captureone",
        "com.cohen.lumen"
    ]

    /// Capture One keeps a new bundle id each year (`captureone16`, `captureone23`, …).
    static let bundlePrefixes = ["com.captureone.captureone"]

    static func matches(bundleID: String) -> Bool {
        if bundleIDs.contains(bundleID) { return true }
        return bundlePrefixes.contains { bundleID.hasPrefix($0) }
    }

    static func match(_ app: NSRunningApplication?) -> String? {
        guard let id = app?.bundleIdentifier, matches(bundleID: id) else { return nil }
        return app?.localizedName ?? id
    }
}
