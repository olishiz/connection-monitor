# Connection Monitor

**Native macOS menu bar app** for continuous live connection monitoring — like running `ping google.com` in Terminal, but always visible in your menu bar.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)
![License](https://img.shields.io/badge/license-MIT-green)
[![GitHub Package](https://img.shields.io/badge/package-%40olishiz%2Fconnection--monitor-blue)](https://github.com/olishiz?tab=packages&repo_name=connection-monitor)

> **Package:** [`@olishiz/connection-monitor`](https://github.com/olishiz/connection-monitor/pkgs/npm/connection-monitor) on [GitHub Packages](https://github.com/olishiz?tab=packages)  
> Native SwiftUI app (not a Node dependency). Use this repo / releases to build and run.

## Features

| Element | Behavior |
|--------|----------|
| **Menu bar** | Always-on status: green / orange / red + current RTT (e.g. `8ms`) |
| **Popover** | Host + resolved IP, Current / Avg / Min / Max / Loss, latency chart, live ping log |
| **Ping engine** | Runs `/sbin/ping` continuously (real ICMP, same as Terminal) |
| **Host** | Change anytime (e.g. `1.1.1.1`, `cloudflare.com`) and hit Apply |

### Status thresholds

- **Online (green):** RTT &lt; 50 ms  
- **Degraded (orange):** RTT ≥ 50 ms  
- **Offline (red):** timeout / unreachable  

## Requirements

- macOS 14 or later  
- Xcode 16+ (to build from source)

## Quick start

### Open in Xcode

```bash
git clone https://github.com/olishiz/connection-monitor.git
cd connection-monitor
open ConnectionMonitor.xcodeproj
```

Then press **⌘R** to run. Look at the **menu bar** (top-right) for the wifi + latency label. Click it for the live panel.

### Build from CLI

```bash
xcodebuild -scheme ConnectionMonitor -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

open build/Build/Products/Debug/ConnectionMonitor.app
```

## How it works

```
┌─────────────────┐     stdout stream      ┌──────────────────┐
│  /sbin/ping -i 1│ ───────────────────► │  PingEngine      │
│  google.com     │   parse icmp_seq,     │  (Observable)    │
└─────────────────┘   time=ms, ttl        └────────┬─────────┘
                                                   │
                    ┌──────────────────────────────┼──────────────┐
                    ▼                              ▼              ▼
             Menu bar label                  Live log        Stats/chart
             (8ms / Down)                 (terminal style)   (min/avg/max)
```

The app is an **LSUIElement** agent: no Dock icon, only the menu bar. Quit from the popover (**Quit**) or press **⌘Q** while the popover is focused.

Default target: **`google.com`**.

## Project layout

```
connection-monitor/
├── ConnectionMonitor.xcodeproj
├── ConnectionMonitor/
│   ├── ConnectionMonitorApp.swift   # MenuBarExtra entry
│   ├── PingEngine.swift             # Continuous ping + parse
│   ├── PingModels.swift             # Sample, stats, status
│   ├── MenuBarView.swift            # Label + popover UI
│   ├── Info.plist                   # LSUIElement (menu-bar only)
│   └── ConnectionMonitor.entitlements
├── LICENSE
└── README.md
```

## Notes

- App sandbox is **off** so the app can invoke system `ping` (real ICMP RTT). Intended as a personal / developer utility.
- First launch may prompt for network-related permissions depending on macOS version; allow them.
- If you have an Apple Developer team, set **Signing & Capabilities → Team** in Xcode for a smoother experience.

## Roadmap ideas

- [ ] Launch at login  
- [ ] Notifications when connection drops  
- [ ] Multiple hosts at once  
- [ ] Optional floating desktop widget  

## License

[MIT](LICENSE) © 2026 Oliver Sim
