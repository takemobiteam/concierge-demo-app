# concierge-demo-app

A Flutter demo app showing how a native app shell can embed a web-based AI
concierge in a WebView and exchange structured messages with it over a JS
bridge (`MobiBridge`) — locale switching, opening suggestion chips or a
pre-filled prompt, requesting an auth code, and letting the web content
navigate the native app's tabs. `assets/concierge_demo.html` stands in for
a real concierge site so the whole flow works out of the box with no
backend required.

## Getting started

1. Install dependencies:
   ```sh
   flutter pub get
   ```
2. Open the iOS Simulator:
   ```sh
   open -a Simulator
   ```
3. Confirm the simulator is detected:
   ```sh
   flutter devices
   ```
4. Copy the example env files and fill in your own values:
   ```sh
   cp .env.json.example .env.json
   cp .env.local.json.example .env.local.json
   ```
5. Run the app against the bundled local demo page (`.env.local.json`, exercises
   the MobiBridge message passing without a live concierge deployment):
   ```sh
   flutter run --dart-define-from-file=.env.local.json
   ```
   Or against the remote concierge (`.env.json`) — set `CONCIERGE_URL` in that
   file to a real remote concierge URL first:
   ```sh
   flutter run --dart-define-from-file=.env.json
   ```
   Matching VS Code launch configs ("Flutter (dev)" and "Flutter (dev, local
   concierge demo)") are available in `.vscode/launch.json` if you'd rather
   launch from the debugger.

## Connect to a locally-running [Virtual Concierge](https://github.com/takemobiteam/vercel-ai-demo)

### Android emulator

The android emulator only exposes the localhost of its host machine as 10.0.2.2, thus auth cookies will not save because they are restricted to [secure contexts](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Secure_Contexts). The following adb command allows you to connect directly to localhost:3000 instead of 10.0.2.2:3000.

```
adb reverse tcp:3000 tcp:3000
```
