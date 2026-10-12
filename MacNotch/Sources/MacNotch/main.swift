import AppKit

// Must run before anything reads UserDefaults.
AppSettings.migrateFromOldName()
AppSettings.removeLegacyGIF()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
