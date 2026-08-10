# @olishiz/connection-monitor

This GitHub Package is the **published package entry** for the native macOS app.

It is **not** an npm runtime library. Use the repository / release to run the app.

## Install the Mac app

### From source (recommended)

```bash
git clone https://github.com/olishiz/connection-monitor.git
cd connection-monitor
open ConnectionMonitor.xcodeproj
# Press ⌘R in Xcode
```

### CLI build

```bash
xcodebuild -scheme ConnectionMonitor -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

open build/Build/Products/Release/ConnectionMonitor.app
```

## Releases

https://github.com/olishiz/connection-monitor/releases

## What it does

- Lives in the macOS menu bar
- Continuously pings a host (default `google.com`)
- Shows live RTT, stats, latency chart, and recent replies
