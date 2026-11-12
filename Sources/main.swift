// Tilt: rotate your Mac's screen from the menu bar, so you can use it lying down.
import AppKit
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Rotation (private MonitorPanel framework, the one System Settings uses)

struct Screen {
    let id: CGDirectDisplayID
    let name: String
    let builtIn: Bool
    let orientation: Int
    let canRotate: Bool
}

enum Rotator {
    private static let loaded: Bool = {
        dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel", RTLD_NOW) != nil
    }()

    private typealias SetFn = @convention(c) (AnyObject, Selector, Int32) -> Void

    /// A fresh MPDisplay for this CG display id (new manager each time, so state is never stale).
    private static func mpDisplay(_ id: CGDirectDisplayID) -> NSObject? {
        guard loaded, let cls = NSClassFromString("MPDisplayMgr") as? NSObject.Type else { return nil }
        let displays = cls.init().value(forKey: "displays") as? [NSObject] ?? []
        return displays.first { ($0.value(forKey: "displayID") as? NSNumber)?.uint32Value == id }
    }

    static func screens() -> [Screen] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids.prefix(Int(count)).compactMap { id in
            // Skip mirrored copies; rotating the mirror master is what matters.
            if CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay { return nil }
            let d = mpDisplay(id)
            let builtIn = CGDisplayIsBuiltin(id) != 0
            let name = (d?.value(forKey: "displayName") as? String)
                ?? NSScreen.screens.first { $0.displayID == id }?.localizedName
                ?? (builtIn ? "Built-in Display" : "Display \(id)")
            let orientation = Int(CGDisplayRotation(id).rounded()) % 360
            let canRotate = (d?.value(forKey: "canChangeOrientation") as? Bool) ?? false
            return Screen(id: id, name: name, builtIn: builtIn, orientation: orientation, canRotate: canRotate)
        }
    }

    @discardableResult
    static func rotate(_ id: CGDirectDisplayID, to degrees: Int) -> Bool {
        guard let d = mpDisplay(id) else { return false }
        let sel = NSSelectorFromString("setOrientation:")
        guard let m = class_getInstanceMethod(type(of: d), sel) else { return false }
        let f = unsafeBitCast(method_getImplementation(m), to: SetFn.self)
        f(d, sel, Int32(((degrees % 360) + 360) % 360))
        return true
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

// MARK: - Settings

enum Prefs {
    static let d = UserDefaults.standard
    static var resetOnQuit: Bool {
        get { d.object(forKey: "resetOnQuit") as? Bool ?? true }
        set { d.set(newValue, forKey: "resetOnQuit") }
    }
    /// Which display the hotkeys act on: 0 = the one under the mouse.
    static var hotkeyDisplay: CGDirectDisplayID {
        get { CGDirectDisplayID(d.integer(forKey: "hotkeyDisplay")) }
        set { d.set(Int(newValue), forKey: "hotkeyDisplay") }
    }
}

// MARK: - Global hotkeys (Carbon; needs no Accessibility permission)

final class Hotkeys {
    static var handler: ((UInt32) -> Void)?
    private var refs: [EventHotKeyRef?] = []

    // ⌃⌥⌘ + arrow. Arrow points where your head is.
    static let keys: [(code: Int, degrees: Int)] = [
        (kVK_UpArrow, 0), (kVK_LeftArrow, 90), (kVK_DownArrow, 180), (kVK_RightArrow, 270),
    ]

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            Hotkeys.handler?(hk.id)
            return noErr
        }, 1, &spec, nil, nil)
        let mods = UInt32(controlKey | optionKey | cmdKey)
        for (i, k) in Hotkeys.keys.enumerated() {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(k.code), mods, EventHotKeyID(signature: OSType(0x54494C54), id: UInt32(i)),
                                GetApplicationEventTarget(), 0, &ref)
            refs.append(ref)
        }
    }
}

// MARK: - App

let choices: [(degrees: Int, title: String, key: String)] = [
    (0, "Normal", "↑"),
    (90, "Lying on left side (90°)", "←"),
    (180, "Upside down (180°)", "↓"),
    (270, "Lying on right side (270°)", "→"),
]

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!
    var hotkeys: Hotkeys!

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        updateIcon()

        Hotkeys.handler = { [weak self] i in
            guard Int(i) < Hotkeys.keys.count else { return }
            self?.hotkey(Hotkeys.keys[Int(i)].degrees)
        }
        hotkeys = Hotkeys()

        CGDisplayRegisterReconfigurationCallback({ _, _, _ in
            DispatchQueue.main.async { (NSApp.delegate as? App)?.updateIcon() }
        }, nil)
    }

    func applicationWillTerminate(_ n: Notification) {
        guard Prefs.resetOnQuit else { return }
        for s in Rotator.screens() where s.orientation != 0 && s.canRotate { Rotator.rotate(s.id, to: 0) }
    }

    func updateIcon() {
        let rotated = Rotator.screens().contains { $0.orientation != 0 }
        let img = NSImage(systemSymbolName: rotated ? "rotate.right.fill" : "rotate.right",
                          accessibilityDescription: "Tilt")
        img?.isTemplate = true
        item.button?.image = img
        item.button?.toolTip = rotated ? "Tilt: screen rotated" : "Tilt"
    }

    /// Hotkeys act on the chosen display, or the one under the mouse.
    func hotkey(_ degrees: Int) {
        let screens = Rotator.screens().filter(\.canRotate)
        let pick = Prefs.hotkeyDisplay
        let mouse = NSEvent.mouseLocation
        let under = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }?.displayID
        let target = screens.first { $0.id == pick } ?? screens.first { $0.id == under } ?? screens.first
        guard let t = target else { return beep("No display here can be rotated.") }
        // Pressing the same direction twice goes back to normal.
        Rotator.rotate(t.id, to: t.orientation == degrees ? 0 : degrees)
    }

    func beep(_ msg: String) {
        NSSound.beep()
        let a = NSAlert(); a.messageText = msg; a.runModal()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let screens = Rotator.screens()
        let header = NSMenuItem(title: "Rotate screen", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for s in screens {
            if screens.count > 1 {
                menu.addItem(.separator())
                let t = NSMenuItem(title: s.name, action: nil, keyEquivalent: "")
                t.isEnabled = false
                menu.addItem(t)
            }
            for c in choices {
                let mi = NSMenuItem(title: c.title, action: s.canRotate ? #selector(pick(_:)) : nil, keyEquivalent: "")
                mi.target = self
                mi.state = s.orientation == c.degrees ? .on : .off
                mi.representedObject = [Int(s.id), c.degrees]
                mi.toolTip = "⌃⌥⌘\(c.key)"
                menu.addItem(mi)
            }
            if !s.canRotate {
                let n = NSMenuItem(title: "This display can't be rotated", action: nil, keyEquivalent: "")
                n.isEnabled = false
                menu.addItem(n)
            }
        }

        menu.addItem(.separator())
        let keys = NSMenuItem(title: "Shortcuts: ⌃⌥⌘ + arrow (points where your head is)", action: nil, keyEquivalent: "")
        keys.isEnabled = false
        menu.addItem(keys)

        if screens.count > 1 {
            let sub = NSMenu()
            let mouse = NSMenuItem(title: "Display under the mouse", action: #selector(setHotkeyDisplay(_:)), keyEquivalent: "")
            mouse.target = self; mouse.tag = 0; mouse.state = Prefs.hotkeyDisplay == 0 ? .on : .off
            sub.addItem(mouse)
            for s in screens {
                let mi = NSMenuItem(title: s.name, action: #selector(setHotkeyDisplay(_:)), keyEquivalent: "")
                mi.target = self; mi.tag = Int(s.id); mi.state = Prefs.hotkeyDisplay == s.id ? .on : .off
                sub.addItem(mi)
            }
            let hk = NSMenuItem(title: "Shortcuts rotate", action: nil, keyEquivalent: "")
            hk.submenu = sub
            menu.addItem(hk)
        }

        let reset = NSMenuItem(title: "Set back to normal when Tilt quits", action: #selector(toggleReset), keyEquivalent: "")
        reset.target = self; reset.state = Prefs.resetOnQuit ? .on : .off
        menu.addItem(reset)

        let login = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self; login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Tilt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func pick(_ sender: NSMenuItem) {
        guard let v = sender.representedObject as? [Int] else { return }
        Rotator.rotate(CGDirectDisplayID(v[0]), to: v[1])
    }

    @objc func setHotkeyDisplay(_ sender: NSMenuItem) { Prefs.hotkeyDisplay = CGDirectDisplayID(sender.tag) }
    @objc func toggleReset() { Prefs.resetOnQuit.toggle() }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            beep("Couldn't change Open at login: \(error.localizedDescription)\nMove Tilt to /Applications and try again.")
        }
    }
}

// MARK: - CLI (for scripts and testing): Tilt --list | --rotate <deg> [displayID]

let args = CommandLine.arguments
if args.count > 1 {
    switch args[1] {
    case "--list":
        for s in Rotator.screens() {
            print("\(s.id)\t\(s.orientation)°\t\(s.canRotate ? "rotatable" : "fixed")\t\(s.name)")
        }
        exit(0)
    case "--rotate" where args.count > 2:
        let deg = Int(args[2]) ?? 0
        let id = args.count > 3 ? CGDirectDisplayID(args[3]) ?? CGMainDisplayID() : CGMainDisplayID()
        exit(Rotator.rotate(id, to: deg) ? 0 : 1)
    default:
        break
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
