# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Flutter demo app (`concierge_demo_app`) demonstrating a JS bridge (`MobiBridge`) pattern for message passing between a native app shell and a web-based AI concierge embedded in a WebView. Only iOS/Android/web platform targets exist (macOS/Linux/Windows were removed since this app doesn't target desktop).

## Commands

```sh
flutter pub get              # install dependencies
flutter analyze              # lint/typecheck — run after any change to lib/
open -a Simulator            # boot the iOS Simulator (flutter run targets it once running)
flutter run --dart-define-from-file=.env.json        # run against the remote concierge (CONCIERGE_SOURCE=remote)
flutter run --dart-define-from-file=.env.local.json  # run against the bundled local demo page (CONCIERGE_SOURCE=local)
```

There are no automated tests in this repo (`test/` is the default Flutter counter-test stub). Two matching VS Code launch configs exist (`.vscode/launch.json`) — "Flutter (dev)" and "Flutter (dev, local concierge demo)" — for the same two `--dart-define-from-file` variants above.

## Architecture

`lib/` is split by concern, not by feature-folder convention — each file is small and single-purpose:

- **`main.dart`** — app entry + `RootShell`, the app's only screen. Owns a 5-tab bottom nav (Home, Benefits, Membership, Concierge, More) via `Offstage`-based tab switching (not `IndexedStack`/`Navigator`), the app-wide `_locale` state, and a `GlobalKey<ConciergeTabState>` used to call into the Concierge tab from sibling tabs (Benefits, More). `_pageToTabIndex` maps bridge `OPEN_PAGE` names to tab indices and must stay in sync with `_tabs`.
- **`concierge_tab.dart`** — the actual point of this demo: wraps a `webview_flutter` `WebViewController` loading either the real concierge URL (`kConciergeUrl`, remote) or the bundled demo page (`assets/concierge_demo.html`, local), selected by the `CONCIERGE_SOURCE` dart-define (`local` default, so the app runs with no config; or `remote`). Registers a JS channel named `MobiBridge`; see below.
- **`benefits_tab.dart`**, **`more_tab.dart`** — the tabs that trigger bridge actions (chips/prompt, locale switching) via callbacks passed down from `RootShell`; `ConciergeTab` never reaches up for these — it takes an `onOpenPage` callback instead of walking the widget tree.
- **`theme.dart`**, **`widgets.dart`** — shared colors/text styles and small reusable widgets (`MoreRow`, `PlaceholderTab`, `LocaleBadge`) used across tabs.

### The MobiBridge protocol

Two directions, both JSON `{type, ...}` messages, implemented in `concierge_tab.dart`:

- **App → page** (`_postToPage` → `window.postMessage`): `CHANGE_LOCALE {locale}`, `OPEN_CHIPS {category}`, `OPEN_PROMPT {prompt}`. These are all just posted and logged in this demo — the real app owns session lifecycle (e.g. starting a new concierge session), not this demo.
- **Page → app** (`MobiBridge.postMessage` → `_onBridgeMessage`): `AUTH_REQUEST` (the page asks for an auth code; the app shows an in-app `AlertDialog` and replies with `AUTH_CODE {code}` once acknowledged), `OPEN_PAGE {page}` (calls `widget.onOpenPage`, which `RootShell` wires to `_openPage`/`_pageToTabIndex`; pages without a dedicated tab — profile/cards/notifications/language — route to More), and `OPEN_EXTERNAL_URL {url}` (opens validated HTTP(S) URLs in the system browser).

When changing bridge behavior, update both sides: the Dart handler in `ConciergeTabState` (`concierge_tab.dart`) and the JS in `assets/concierge_demo.html` (which stands in for the real concierge site and should mirror what a real integration would do, so it's useful for manually exercising both message directions).

### Locale

`kLanguageOptions` (in `more_tab.dart`) is the source of truth for supported locales — currently English (`en-US`), French (`fr-CA`), Spanish (`es-LA`), German (`de-DE`), Arabic (`ar-QA`), using hyphenated BCP-47-style codes (not underscore). Locale is switched from the More tab → Language screen, sends `CHANGE_LOCALE` into the WebView, and is mirrored in two separate on-screen indicators that must be kept in sync manually if the format changes: the Flutter-side `LocaleBadge` pill (top-right overlay, all tabs, in `widgets.dart`) and the HTML page's own `#locale-badge` span in its `<h1>`.

### Env / config

Dart-define files (`.env.json`, `.env.local.json`) supply `CONCIERGE_URL` and `CONCIERGE_SOURCE` at build/run time and are gitignored, since values here may be personal (e.g. a dev's own ngrok URL). `.env.json.example` and `.env.local.json.example` are checked in with placeholder values — copy and rename to get started (see README).
