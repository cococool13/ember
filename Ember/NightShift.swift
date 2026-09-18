import Darwin
import Foundation

enum NightShift {
    static func disable() {
        load()
        guard let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type else { return }
        let client = cls.init()
        let sel = NSSelectorFromString("setEnabled:")
        guard client.responds(to: sel) else { return }
        let setter = unsafeBitCast(
            client.method(for: sel),
            to: (@convention(c) (Any, Selector, Bool) -> Void).self
        )
        setter(client, sel, false)
    }

    private static var loaded = false
    private static func load() {
        guard !loaded else { return }
        loaded = true
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY)
    }
}
