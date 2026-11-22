// VoiceOver-eye view of the running panel: opens Ember's menu bar item through the
// Accessibility API and prints every element VoiceOver can land on, flagging unnamed controls.
// Usage: swift scripts/ax-audit.swift <pid>   (the calling app needs Accessibility permission)
import ApplicationServices
import Foundation

func attr(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func string(_ element: AXUIElement, _ name: String) -> String {
    (attr(element, name) as? String) ?? ""
}

guard CommandLine.arguments.count > 1, let pid = pid_t(CommandLine.arguments[1]) else {
    print("usage: ax-audit.swift <pid>"); exit(2)
}

let app = AXUIElementCreateApplication(pid)
guard let extras = attr(app, "AXExtrasMenuBar") else { print("no menu bar extra"); exit(1) }
let items = (attr(extras as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement]) ?? []
guard let item = items.first else { print("no status item"); exit(1) }
print("status item: role=\(string(item, kAXRoleAttribute)) title=\(string(item, kAXTitleAttribute)) desc=\(string(item, kAXDescriptionAttribute)) value=\(string(item, kAXValueAttribute))")
AXUIElementPerformAction(item, kAXPressAction as CFString)
Thread.sleep(forTimeInterval: 0.8)

let interactive: Set<String> = ["AXButton", "AXCheckBox", "AXSlider", "AXPopUpButton", "AXMenuButton", "AXRadioButton", "AXIncrementor", "AXSwitch"]
var unnamed = 0
var controls = 0
func walk(_ element: AXUIElement, _ depth: Int) {
    let role = string(element, kAXRoleAttribute)
    let name = [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, "AXLabel"]
        .map { string(element, $0) }.first { !$0.isEmpty } ?? ""
    let help = string(element, kAXHelpAttribute)
    var actions: CFArray?
    AXUIElementCopyActionNames(element, &actions)
    let acts = (actions as? [String])?.filter { $0 != "AXShowMenu" && $0 != "AXScrollToVisible" } ?? []
    if interactive.contains(role) {
        controls += 1
        if name.isEmpty {
            unnamed += 1
        }
    }
    if role != "AXGroup" || !name.isEmpty {
        let flag = interactive.contains(role) && name.isEmpty ? "  <-- NO NAME" : ""
        print("\(String(repeating: "  ", count: depth))\(role) \"\(name)\"\(help.isEmpty ? "" : " help=\"\(help)\"") \(acts)\(flag)")
    }
    for child in (attr(element, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
        walk(child, depth + 1)
    }
}

for window in (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? [] {
    print("window: \(string(window, kAXTitleAttribute))")
    walk(window, 1)
}

print("controls=\(controls) unnamed=\(unnamed)")
AXUIElementPerformAction(item, kAXPressAction as CFString)
