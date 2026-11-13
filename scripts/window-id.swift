import CoreGraphics
// Prints the window numbers of an app's on-screen windows, for screencapture -l.
// usage: swift scripts/window-id.swift <app name> [process id]
let owner = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Mosaikk"
let pid = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) : nil
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in list where window[kCGWindowOwnerName as String] as? String == owner && window[kCGWindowLayer as String] as? Int == 0 {
    if let pid, window[kCGWindowOwnerPID as String] as? Int != pid { continue }
    print(window[kCGWindowNumber as String]!)
}
