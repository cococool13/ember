import AppKit
import SwiftUI

/// Presentation only: every surface shares the same schedule and display model.
@MainActor
final class EmberWindows: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var main: NSWindow?
    private var preferences: NSWindow?

    init(model: AppModel) {
        self.model = model; super.init()
    }

    func showMain() {
        if main == nil {
            main = window(title: "Ember", size: NSSize(width: 660, height: 556),
                          toolbar: true, view: MainWindowView().environmentObject(model))
            main?.minSize = NSSize(width: 660, height: 556)
        }
        show(main)
    }

    func showPreferences() {
        model.refreshWhileVisible()
        if preferences == nil {
            preferences = window(title: "Ember Settings", size: NSSize(width: 568, height: 640),
                                 view: SettingsWindowView().environmentObject(model))
            preferences?.minSize = NSSize(width: 568, height: 580)
        }
        show(preferences)
    }

    private func window<V: View>(title: String, size: NSSize, toolbar: Bool = false, view: V) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.delegate = self
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = title
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        if toolbar {
            window.toolbar = NSToolbar(identifier: title)
            window.toolbarStyle = .unified
        }
        window.contentView = NSHostingView(rootView: view)
        window.center()
        return window
    }

    func windowWillClose(_: Notification) {
        model.endScrub()
    }

    private func show(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection = "light"

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Your light", systemImage: "sun.max").tag("light")
                    .listItemTint(Theme.ember)
                Label("Sleep schedule", systemImage: "moon").tag("schedule")
                    .listItemTint(Theme.ember)
                Label("About", systemImage: "info.circle").tag("about")
                    .listItemTint(Theme.ember)
            }
            .foregroundStyle(Theme.white)
            .navigationSplitViewColumnWidth(180)
        } detail: {
            Group {
                if selection == "about" {
                    AboutPane()
                } else if selection == "schedule" {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sleep schedule").emberLabel(28)
                        SleepScheduleView()
                        Spacer()
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        MenuBarView(inMainWindow: true)
                            .environment(\.panelClockRunning, true)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .foregroundStyle(Theme.white)
            .background { PanelMaterial() }
            .navigationTitle(selection == "schedule" ? "Sleep schedule" : selection == "about" ? "About" : "Your light")
            .toolbar {
                Button { model.showPreferences?() } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings (⌘,)")
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { model.endScrub() }
    }
}

struct SettingsWindowView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("showDockIcon") private var showDockIcon = false
    @State private var shareAnalytics = Analytics.isEnabled()
    @ObservedObject private var updates = Updates.shared

    var body: some View {
        Form {
            Section("Sleep schedule") {
                HStack(spacing: 16) {
                    ClockField(title: "Wake", symbol: "sunrise", time: $model.wake)
                    ClockField(title: "Bedtime", symbol: "moon", time: $model.bed)
                }
                Picker("Night light", selection: $model.strength) {
                    ForEach(NightStrength.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            Section("Display & location") {
                PreferencesView()
            }
            Section {
                Toggle("Show Ember in the Dock", isOn: $showDockIcon)
            } header: {
                Text("Appearance")
            } footer: {
                Text("When hidden, Ember stays available in the menu bar. Closing a window keeps your light running.")
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $updates.automaticallyChecks)
                Button("Check for Updates…") { updates.check() }
                    .disabled(!updates.canCheck)
            }
            Section {
                Toggle("Share anonymous usage and crash reports", isOn: $shareAnalytics)
            } footer: {
                Text("Anonymous events and crash reports help fix bugs. No personal data.")
            }
        }
        .formStyle(.grouped)
        .preferredColorScheme(.dark)
        .onChange(of: showDockIcon) { _, visible in
            NSApp.setActivationPolicy(visible ? .regular : .accessory)
        }
        .onChange(of: shareAnalytics) { _, enabled in Analytics.setEnabled(enabled) }
    }
}

/// A heavy word set edge to edge, the way the site's hero sets its rows.
struct PosterWord: View {
    var word: String
    var maxSize: CGFloat = 160

    var body: some View {
        GeometryReader { proxy in
            // Letter by letter where Core Text puts them, as on the setup poster,
            // so the word ends exactly at the trailing edge.
            let layout = PosterLayout.make(rows: [word], width: proxy.size.width,
                                           maxHeight: min(maxSize, proxy.size.height) / PosterLayout.lead)
            ZStack(alignment: .topLeading) {
                ForEach(Array(layout.letters.enumerated()), id: \.offset) { _, letter in
                    Text(letter.character)
                        .font(Theme.poster(layout.fontSize))
                        .fixedSize()
                        .frame(width: letter.width, height: layout.rowHeight)
                        .position(x: letter.x + letter.width / 2, y: proxy.size.height - layout.rowHeight / 2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word.capitalized)
        .accessibilityAddTraits(.isHeader)
    }
}

struct AboutPane: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            EmberMark(lit: true).frame(width: 44, height: 44)
            PosterWord(word: "EMBER")
                .frame(height: 112)
                .foregroundStyle(Theme.ashInk)
            Text("Version \(version). $9 one time. macOS 14 or later, Apple silicon and Intel.")
                .font(Theme.body(13)).foregroundStyle(Theme.ember)
            Text("Ember warms and dims your display after sunset on a circadian curve. It lives in the menu bar and keeps running when you close its windows.")
                .font(Theme.body(14)).foregroundStyle(Theme.ash2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 380, alignment: .leading)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}
