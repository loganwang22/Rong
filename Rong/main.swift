import Cocoa
import InputMethodKit

// Single source of truth: the connection name and controller class are read
// from Info.plist so main.swift, the plist, and AppDelegate cannot drift apart.
// If any of these keys is missing or the controller class cannot be resolved,
// we log the mismatch and exit early — IMKit would otherwise fail silently.

let infoPlist = Bundle.main.infoDictionary ?? [:]

guard let connectionName = infoPlist["InputMethodConnectionName"] as? String,
      !connectionName.isEmpty else {
    NSLog("Rong: Info.plist is missing InputMethodConnectionName — cannot start IMKServer")
    exit(1)
}

guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
    NSLog("Rong: Bundle has no identifier — cannot start IMKServer")
    exit(1)
}

guard let controllerClassName = infoPlist["InputMethodServerControllerClass"] as? String,
      !controllerClassName.isEmpty else {
    NSLog("Rong: Info.plist is missing InputMethodServerControllerClass")
    exit(1)
}

// IMKit looks up the controller via Objective-C runtime. If the @objc name in
// RongInputController.swift drifts from the Info.plist value, keystrokes will
// silently never reach us. Fail loudly on launch instead.
guard NSClassFromString(controllerClassName) != nil else {
    NSLog("Rong: InputMethodServerControllerClass '\(controllerClassName)' does not resolve — check the @objc(...) annotation on RongInputController")
    exit(1)
}

// IMKServer must be created before NSApplication.shared.run()
guard let server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier) else {
    NSLog("Rong: Failed to create IMKServer (name=\(connectionName))")
    exit(1)
}

NSLog("Rong: IMKServer started — connection=\(connectionName), controller=\(controllerClassName)")

// Keep server alive via AppDelegate
let delegate = AppDelegate(server: server)
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
