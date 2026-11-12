# Tilt

Rotate your Mac's screen from the menu bar, so you can watch or read while lying down.

It uses real system rotation (the same thing System Settings does for external monitors), so the trackpad and mouse follow the rotated screen. It also works on a MacBook's built-in display, which System Settings doesn't let you rotate.

## Use

Click the Tilt icon in the menu bar and pick a direction, or use the shortcuts. The arrow points where your head is:

| Shortcut | Rotation |
| --- | --- |
| ⌃⌥⌘ ↑ | Normal |
| ⌃⌥⌘ ← | Lying on left side (90°) |
| ⌃⌥⌘ → | Lying on right side (270°) |
| ⌃⌥⌘ ↓ | Upside down (180°) |

Pressing the same shortcut again goes back to normal. With more than one display, shortcuts act on the display under the mouse (you can change that in the menu). By default the screen goes back to normal when Tilt quits.

From the command line:

```bash
/Applications/Tilt.app/Contents/MacOS/Tilt --list
/Applications/Tilt.app/Contents/MacOS/Tilt --rotate 90
```

## Build

Needs macOS 13+ and the Xcode command line tools.

```bash
./build.sh            # build/Tilt.app
./build.sh install    # copy to /Applications and open
./build.sh dmg        # build/Tilt.dmg
```

`Sources/main.swift` is the whole app. `tools/make-icon.swift` draws the icon. Rotation goes through Apple's private MonitorPanel framework, so a future macOS update could break it.

Made by **Virat Reddy Kaukuntla** ([@learningnihongo934-byte](https://github.com/learningnihongo934-byte))
