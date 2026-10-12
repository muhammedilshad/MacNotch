import Carbon.HIToolbox
import Foundation

/// System-wide shortcuts. Carbon hot keys need no Accessibility permission.
enum HotKey {
    static let displayString = "⌃⌥⌘N"
    static let ocrDisplayString = "⌃⌥⌘T"

    enum Shortcut: UInt32 {
        case toggleNotch = 1
        case screenText = 2

        var keyCode: Int {
            switch self {
            case .toggleNotch: return kVK_ANSI_N
            case .screenText: return kVK_ANSI_T
            }
        }
    }

    private static var hotKeyRefs: [EventHotKeyRef?] = []
    private static var handlerRef: EventHandlerRef?
    private static var actions: [UInt32: () -> Void] = [:]

    static func register(_ shortcut: Shortcut, action: @escaping () -> Void) {
        guard actions[shortcut.rawValue] == nil else { return }
        actions[shortcut.rawValue] = action
        installHandler()

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x444E_4F54), id: shortcut.rawValue) // "DNOT"
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode), UInt32(controlKey | optionKey | cmdKey),
                                         id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr { NSLog("MacNotch: could not register hot key \(shortcut) (status \(status))") }
        hotKeyRefs.append(ref)
    }

    private static func installHandler() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            DispatchQueue.main.async { HotKey.actions[id.id]?() }
            return noErr
        }, 1, &eventType, nil, &handlerRef)
    }
}
