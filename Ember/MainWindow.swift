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
            }
            .foregroundStyle(Theme.white)
            .navigationSplitViewColumnWidth(180)
        } detail: {
            Group {
                if selection == "schedule" {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sleep schedule").emberLabel(28)
                        SleepScheduleView()
                        Spacer()
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        MenuBarView(inMainWindow: true)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .foregroundStyle(Theme.white)
            .background { PanelMaterial() }
            .navigationTitle(selection == "schedule" ? "Sleep schedule" : "Your light")
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
        }
        .formStyle(.grouped)
        .preferredColorScheme(.dark)
        .onChange(of: showDockIcon) { _, visible in
            NSApp.setActivationPolicy(visible ? .regular : .accessory)
        }
    }
}
