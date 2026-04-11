import Cocoa
import InputMethodKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let server: IMKServer
    var candidatePanel: IMKCandidates?

    init(server: IMKServer) {
        self.server = server
        super.init()
        candidatePanel = IMKCandidates(
            server: server,
            panelType: kIMKSingleColumnScrollingCandidatePanel
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Rong IME started")

        // Warm the dictionary off the main thread so the first keystroke
        // doesn't pay the cost of parsing ~125k bundled-dict lines.
        DispatchQueue.global(qos: .userInitiated).async {
            _ = PinyinDictionary.shared
        }

        // Preload LLM model in the background
        Task {
            await LLMEngine.shared.preload()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("Rong IME stopping")
    }
}
