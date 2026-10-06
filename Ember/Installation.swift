import AppKit

/// Launching from a download or disk image is easy to mistake for installing.
enum Installation {
    static func isInApplications(_ app: URL = Bundle.main.bundleURL) -> Bool {
        let parent = app.deletingLastPathComponent().standardizedFileURL
        let system = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let user = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        return [system, user].contains {
            parent.path == $0.path || parent.path.hasPrefix($0.path + "/")
        }
    }

    static func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }
}
