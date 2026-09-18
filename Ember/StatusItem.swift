import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItem: NSObject {
    private let model: AppModel
    private let item: NSStatusItem
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    init(model: AppModel) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(toggle(_:))
        refreshChrome()
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshChrome() }
            .store(in: &cancellables)
    }

    private func refreshChrome() {
        let phase = model.isActive ? model.state.phase : nil
        item.button?.image = MenuBarMark.image(phase: phase)
        if !model.enabled {
            item.button?.toolTip = "Ember is off"
        } else if let name = model.colorAppName {
            item.button?.toolTip = "True color · \(name)"
        } else if model.isTimedPause {
            item.button?.toolTip = "Ember paused"
        } else {
            item.button?.toolTip = "\(model.state.phase.title) · \(Int(model.state.kelvin.rounded()))K"
        }
    }

    @objc func toggle(_ sender: Any?) {
        if panel?.isVisible == true {
            close()
            return
        }
        open()
    }

    private func open() {
        guard let button = item.button, let buttonWindow = button.window else { return }
        let host = NSHostingController(rootView: MenuBarView().environmentObject(model))
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor(srgbRed: 11 / 255, green: 11 / 255, blue: 11 / 255, alpha: 1).cgColor
        host.view.frame = NSRect(x: 0, y: 0, width: 360, height: 10)
        let height = max(host.view.fittingSize.height, 420)
        let size = NSSize(width: 360, height: height)
        host.view.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = true
        panel.backgroundColor = NSColor(srgbRed: 11 / 255, green: 11 / 255, blue: 11 / 255, alpha: 1)
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentViewController = host
        panel.setContentSize(size)

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        var origin = NSPoint(x: screenRect.midX - size.width / 2, y: screenRect.minY - size.height - 6)
        if let screen = buttonWindow.screen ?? NSScreen.main {
            origin.x = min(max(origin.x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - size.width - 8)
            if origin.y < screen.visibleFrame.minY {
                origin.y = screenRect.maxY + 6
            }
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}
