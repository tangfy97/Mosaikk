import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: icns-generator <iconset-directory> <output-file>")
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let entries = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]

func integerData(_ value: Int) -> Data {
    var encoded = UInt32(value).bigEndian
    return withUnsafeBytes(of: &encoded) { Data($0) }
}

var chunks = Data()
for (type, fileName) in entries {
    let imageData = try Data(contentsOf: iconset.appendingPathComponent(fileName))
    chunks.append(type.data(using: .ascii)!)
    chunks.append(integerData(imageData.count + 8))
    chunks.append(imageData)
}

var icns = Data("icns".utf8)
icns.append(integerData(chunks.count + 8))
icns.append(chunks)
try icns.write(to: output, options: .atomic)
