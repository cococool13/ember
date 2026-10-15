import AppKit
import SwiftUI
import XCTest
@testable import Ember

/// Opt-in repeatable AppKit benchmarks. No display writes, login changes or location requests.
final class PerformanceTests: XCTestCase {
    @MainActor
    func testScreenPerformance() throws {
        guard ProcessInfo.processInfo.environment["EMBER_BENCHMARK"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_EMBER_BENCHMARK=1 for performance measurements")
        }
        Fonts.register()
        let defaults = UserDefaults(suiteName: "EmberPerformanceTests")!
        defaults.set(true, forKey: "didShowSetup")
        defaults.set(false, forKey: "colorAppBypass")
        defer { defaults.removePersistentDomain(forName: "EmberPerformanceTests") }
        let model = AppModel(defaults: defaults)
        benchmark("model-init", count: 30) { _ = AppModel(defaults: defaults) }
        benchmark("status-init-and-first-open", count: 20) {
            let status = StatusItem(model: model)
            XCTAssertTrue(status.open())
            status.closeImmediately()
        }
        let status = StatusItem(model: model)
        XCTAssertTrue(status.open())
        status.closeImmediately()
        benchmark("panel-reopen", count: 30) {
            XCTAssertTrue(status.open())
            status.closeImmediately()
        }
        benchmark("main-first-open", count: 20) {
            let windows = EmberWindows(model: model)
            windows.showMain()
            for window in NSApp.windows where window.title == "Your light" || window.title == "Ember" {
                window.displayIfNeeded()
                window.close()
            }
        }
        benchmark("settings-first-open", count: 20) {
            let windows = EmberWindows(model: model)
            windows.showPreferences()
            for window in NSApp.windows where window.title == "Ember Settings" {
                window.displayIfNeeded()
                window.close()
            }
        }
        let windows = EmberWindows(model: model)
        windows.showMain()
        windows.showPreferences()
        benchmark("main-reopen", count: 30) { windows.showMain() }
        benchmark("settings-reopen", count: 30) { windows.showPreferences() }
        for window in NSApp.windows where window.title == "Ember Settings" || window.title == "Your light" || window.title == "Ember" {
            window.close()
        }
        benchmarkLayout("panel", model: model, view: MenuBarView(), size: NSSize(width: 360, height: 408))
        benchmarkLayout("main", model: model, view: MainWindowView(), size: NSSize(width: 660, height: 556))
        benchmarkLayout("settings", model: model, view: SettingsWindowView(), size: NSSize(width: 568, height: 400))
        benchmarkLayout("setup", model: model, view: SetupView(finish: {}), size: NSSize(width: 480, height: 520))
    }

    @MainActor
    private func benchmarkLayout<V: View>(_ name: String, model: AppModel, view: V, size: NSSize) {
        let host = NSHostingView(rootView: view.environmentObject(model))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.displayIfNeeded()
        var update = 0
        benchmark("\(name)-content-update", count: 30) {
            update += 1
            model.scrub(to: Double(update % 31) / 30)
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }
        model.endScrub()
        if let scroll = scrollView(in: host) {
            // Move existing content through the actual native clip view in both directions.
            let range = max(0, (scroll.documentView?.bounds.height ?? 0) - scroll.contentView.bounds.height)
            print("EMBER_PERF \(name)-scroll-range=\(range)")
            benchmark("\(name)-scroll-120-steps", count: 10) {
                for step in 0..<120 {
                    let fraction = Double(step < 60 ? step : 119 - step) / 59
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: range * fraction))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    window.displayIfNeeded()
                }
            }
        }
        window.close()
    }

    private func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { self.scrollView(in: $0) }.first
    }

    private func benchmark(_ name: String, count: Int, action: () -> Void) {
        print("EMBER_PERF_BEGIN \(name)")
        fflush(stdout)
        var samples: [Double] = []
        for _ in 0..<count {
            let start = ProcessInfo.processInfo.systemUptime
            autoreleasepool { action() }
            samples.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
        }
        let sorted = samples.sorted()
        print("EMBER_PERF \(name) n=\(count) first=\(samples[0]) median=\(sorted[count / 2]) p95=\(sorted[min(count - 1, Int(Double(count) * 0.95))]) ms")
    }
}
