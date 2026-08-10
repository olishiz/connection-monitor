# Connection Monitor

Native **macOS menu bar** app for continuous live connection monitoring — like `ping google.com` in Terminal, always in your menu bar.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)
![License](https://img.shields.io/badge/license-MIT-green)

Minimal Apple-style UI · live RTT · stats · latency chart · recent replies.

## Install

### Homebrew (recommended)

```bash
brew tap olishiz/tap
brew trust olishiz/tap          # required by modern Homebrew for third-party taps
brew install --cask connection-monitor
```

### Download

Grab the latest **`.dmg`** from [Releases](https://github.com/olishiz/connection-monitor/releases):

1. Open `ConnectionMonitor-x.y.z.dmg`
2. Drag **Connection Monitor** → **Applications**
3. Open the app (first launch may need **right-click → Open** if unsigned)
4. Check the menu bar for the status dot + latency

### Build from source

```bash
git clone https://github.com/olishiz/connection-monitor.git
cd connection-monitor
open ConnectionMonitor.xcodeproj
# Press ⌘R
```

CLI:

```bash
xcodebuild -scheme ConnectionMonitor -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

open build/Build/Products/Release/ConnectionMonitor.app
```

## Features

| | |
|--|--|
| **Menu bar** | Soft status dot + live RTT (e.g. `7 ms`) |
| **Popover** | Large latency, avg/min/max/loss, thin chart, recent list |
| **Engine** | Continuous `/sbin/ping` (real ICMP) |
| **Host** | Change anytime (`google.com`, `1.1.1.1`, …) |

Status colors: **green** &lt; 50 ms · **orange** ≥ 50 ms · **red** offline.

## How it works

```
/sbin/ping -i 1  ──►  PingEngine  ──►  menu bar + popover UI
```

`LSUIElement` agent: no Dock icon. Quit from the popover or **⌘Q**.

## Project layout

```
connection-monitor/
├── ConnectionMonitor.xcodeproj
├── ConnectionMonitor/          # SwiftUI sources
├── LICENSE
└── README.md
```

## Notes

- Sandbox is off so the app can run system `ping` (personal utility).
- For distribution beyond your Mac, sign & notarize with an Apple Developer ID.
- This is a **native app**, distributed via **Releases** and **Homebrew** — not npm.

## License

[MIT](LICENSE) © 2026 Oliver Sim
