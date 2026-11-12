import CoreGraphics
// Prints the window numbers of an app's on-screen windows, for screencapture -l.
let owner = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Mosaikk"
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in list where window[kCGWindowOwnerName as String] as? String == owner && window[kCGWindowLayer as String] as? Int == 0 {
    print(window[kCGWindowNumber as String]!)
}
