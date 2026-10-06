import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItem: NSObject {
    private let model: AppModel
    private let item: NSStatusItem
    private var panel: NSPanel?
    private var installedMark = false
    private var markPhase: Phase?
    private let presence = PanelPresence()
    /// Bumped on every open and close, so a stale close never hides a panel
    /// that was reopened mid-animation.
    private var generation = 0
    /// The mouse event that started the current close. A second delivery of
    /// that same click must not open the panel again.
    private var closingStamp: TimeInterval?
    /// Set when a click on the icon already dismissed the panel, so the
    /// button action that follows does not reopen it.
    private var suppressToggle = false
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitors: [Any] = []

    init(model: AppModel) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(toggle(_:))
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        refreshChrome()
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshChrome() }
            .store(in: &cancellables)
        model.$quitting
            .filter { $0 }
            .sink { [weak self] _ in self?.close() }
            .store(in: &cancellables)
    }

    deinit {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func refreshChrome() {
        let phase = model.isActive ? model.state.phase : nil
        if !installedMark || phase != markPhase {
            item.button?.image = MenuBarMark.image(phase: phase)
            markPhase = phase
            installedMark = true
        }
        let tooltip: String
        if !model.enabled {
            tooltip = "Ember is off"
        } else if let name = model.colorAppName {
            tooltip = "True color · \(name)"
        } else if model.isTimedPause {
            tooltip = "Ember paused"
        } else {
            tooltip = "\(model.state.phase.title) · \(model.state.signalLabel)"
        }
        if item.button?.toolTip != tooltip { item.button?.toolTip = tooltip }
    }

    @objc func toggle(_ sender: Any?) {
        if suppressToggle {
            suppressToggle = false
            return
        }
        let sameEvent = NSApp.currentEvent?.timestamp == closingStamp
        switch StatusToggle.decide(
            panelOpen: panel != nil,
            leaving: presence.stage == .leaving,
            sameEvent: sameEvent
        ) {
        case .open, .reverse:
            open()
        case .close:
            close()
        case .ignore:
            break
        }
    }

    @discardableResult
    func open() -> Bool {
        model.refreshWhileVisible()
        generation += 1
        if let panel {
            // Reopened while closing: reverse from where it is.
            show(panel)
            return true
        }
        guard let button = item.button, let buttonWindow = button.window else { return false }
        let host = NSHostingController(rootView: PanelRoot(presence: presence).environmentObject(model))
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        let width = Theme.panelWidth
        host.view.frame = NSRect(x: 0, y: 0, width: width, height: 10)
        let height = max(host.view.fittingSize.height, 420)
        let size = NSSize(width: width, height: height)
        host.view.frame = NSRect(origin: .zero, size: size)

        let panel = EmberPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // The SwiftUI root paints the void and its rounded hairline edge; the
        // panel stays clear so the corners read against the desktop.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
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
        // Grow from the menu bar icon, not the panel's center.
        presence.anchor = UnitPoint(x: min(1, max(0, (screenRect.midX - origin.x) / size.width)), y: 0)
        presence.stage = .entering
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel
        show(panel)
        return true
    }

    private func show(_ panel: NSPanel) {
        panel.makeKeyAndOrderFront(nil)
        listenForDismiss()
        let motion = PanelMotion.open
        withAnimation(motion.swiftUI) { presence.stage = .shown }
        let generation = generation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = motion.seconds
            context.timingFunction = PanelMotion.easeOut
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                // The shadow was cut from the first, still-scaled frame.
                self.panel?.invalidateShadow()
            }
        }
    }

    private func close() {
        guard let panel, presence.stage != .leaving else { return }
        closingStamp = NSApp.currentEvent?.timestamp
        generation += 1
        model.endScrub()
        clearMonitors()
        let motion = PanelMotion.close
        withAnimation(motion.swiftUI) { presence.stage = .leaving }
        let generation = generation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = motion.seconds
            context.timingFunction = PanelMotion.easeOut
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.panel?.orderOut(nil)
                self.panel = nil
            }
        }
    }

    private func listenForDismiss() {
        clearMonitors()
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.close()
                    return nil
                }
                return event
            }
            if event.window == self.panel { return event }
            if self.clickHitsStatusItem(event) {
                self.noteStatusItemClick()
                return event
            }
            self.close()
            return event
        } {
            eventMonitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            if self.clickHitsStatusItem(event) {
                self.noteStatusItemClick()
                return
            }
            self.close()
        } {
            eventMonitors.append(global)
        }
    }

    /// A click on the menu bar icon while the panel is open dismisses it.
    /// The button action for that same click must not open it again.
    private func noteStatusItemClick() {
        if presence.stage != .leaving {
            close()
        }
        suppressToggle = true
        DispatchQueue.main.async { [weak self] in
            self?.suppressToggle = false
        }
    }

    private func clickHitsStatusItem(_ event: NSEvent) -> Bool {
        if event.window === item.button?.window { return true }
        guard let button = item.button, let window = button.window else { return false }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        return rect.insetBy(dx: -4, dy: -6).contains(NSEvent.mouseLocation)
    }

    private func clearMonitors() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
    }
}

/// What a click on the menu bar icon should do. Menu-bar apps dismiss on the
/// second click. The click that starts the close is often delivered twice
/// (outside-click monitor, then the button action); that second delivery
/// must not reopen. A later click during the close animation still reverses.
enum StatusToggle: Equatable {
    case open
    case close
    case reverse
    case ignore

    static func decide(panelOpen: Bool, leaving: Bool, sameEvent: Bool) -> StatusToggle {
        guard panelOpen else { return .open }
        if leaving { return sameEvent ? .ignore : .reverse }
        return .close
    }
}

/// Scale state for the panel. The window's alpha carries opacity (and fades
/// the shadow with it); SwiftUI carries the scale so it can grow from the icon.
@MainActor
final class PanelPresence: ObservableObject {
    enum Stage { case entering, shown, leaving }

    @Published var stage = Stage.entering
    var anchor = UnitPoint.top
    var shown: Bool { stage == .shown }
}

/// Opens in 200 ms and closes in 140 ms on one strong ease-out. Close is
/// quicker and moves less, so dismissing never feels like waiting.
private struct PanelMotion {
    var seconds: Double

    static let open = PanelMotion(seconds: 0.2)
    static let close = PanelMotion(seconds: 0.14)
    static let easeOut = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)

    var swiftUI: Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: seconds)
    }
}

private struct PanelRoot: View {
    @ObservedObject var presence: PanelPresence
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MenuBarView()
            .scaleEffect(reduceMotion ? 1 : scale, anchor: presence.anchor)
            .offset(y: reduceMotion ? 0 : offset)
    }

    /// Enter from 0.95 a few points up; leave to 0.98 in place. Reduce Motion
    /// keeps the fade only.
    private var scale: CGFloat {
        switch presence.stage {
        case .entering: return 0.95
        case .shown: return 1
        case .leaving: return 0.98
        }
    }

    private var offset: CGFloat {
        presence.stage == .entering ? -4 : 0
    }
}

/// A borderless nonactivating panel still needs key status for Tab and Escape.
/// It does not become the main window or replace the frontmost color-work app.
private final class EmberPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
