import Cocoa
import InputMethodKit

// IMKServer must be created before NSApplication.shared.run()
// The connection name must match Info.plist InputMethodConnectionName
let connectionName = "com.loganwang.inputmethod.Rong_Connection"
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.loganwang.inputmethod.Rong"

guard let server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier) else {
    NSLog("Rong: Failed to create IMKServer")
    exit(1)
}

// Keep server alive via AppDelegate
let delegate = AppDelegate(server: server)
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
