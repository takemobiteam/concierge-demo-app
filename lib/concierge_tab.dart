import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'native_auth.dart';
import 'theme.dart';

const String kConciergeUrl = String.fromEnvironment(
  'CONCIERGE_URL',
  defaultValue: 'https://example.com/concierge/',
);

// Dev toggle: 'remote' loads kConciergeUrl, 'local' loads the bundled
// assets/concierge_demo.html to exercise the MobiBridge message passing
// without depending on a live concierge deployment. Defaults to 'local' so
// the app runs out of the box without any config.
const String kConciergeSource = String.fromEnvironment(
  'CONCIERGE_SOURCE',
  defaultValue: 'local',
);
const String kLocalConciergeAsset = 'assets/concierge_demo.html';

typedef ExternalUrlLauncher =
    Future<bool> Function(Uri url, {required LaunchMode mode});
typedef BridgeLogger = void Function(String message);

Future<bool> _launchUrl(Uri url, {required LaunchMode mode}) {
  return launchUrl(url, mode: mode);
}

/// Opens an HTTP(S) URL outside the app, rejecting all other schemes before
/// handing the URL to the platform launcher.
@visibleForTesting
Future<void> openExternalUrl(
  dynamic rawUrl, {
  ExternalUrlLauncher? launcher,
  BridgeLogger? logger,
}) async {
  final log = logger ?? debugPrint;
  final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
  final isAllowed =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.hasAuthority &&
      uri.host.isNotEmpty;

  if (!isAllowed) {
    log('[Bridge] rejected external URL: $rawUrl');
    return;
  }

  try {
    final didLaunch = await (launcher ?? _launchUrl)(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch) {
      log('[Bridge] failed to open external URL: $uri');
    }
  } catch (error) {
    log('[Bridge] failed to open external URL: $uri ($error)');
  }
}

/// Answers one `AUTH_REQUEST` right away with a fresh `AUTH_CODE`, or stays
/// quiet while the shell is signed out. Never waits on user input: the page
/// gives up after 3 seconds.
@visibleForTesting
Future<void> answerAuthRequest(
  NativeAuth auth, {
  required Future<void> Function(Map<String, dynamic> payload) postToPage,
  BridgeLogger? logger,
}) async {
  final log = logger ?? debugPrint;
  final String? code;
  try {
    code = await auth.codeForAuthRequest();
  } catch (error) {
    log('[Bridge] failed to get an auth code: $error');
    return;
  }
  if (code == null) {
    log('[Bridge] ignored AUTH_REQUEST: signed out');
    return;
  }
  await postToPage({'type': 'AUTH_CODE', 'code': code});
  // The code is a credential in real deployments, so it isn't logged.
  log('[Bridge] sent AUTH_CODE');
}

/// Parses and dispatches one page-to-app MobiBridge message.
@visibleForTesting
Future<void> dispatchMobiBridgeMessage(
  String message, {
  required Future<void> Function() onAuthRequest,
  required ValueChanged<String> onOpenPage,
  ExternalUrlLauncher? externalUrlLauncher,
  BridgeLogger? logger,
}) async {
  final log = logger ?? debugPrint;
  log('[Bridge] raw message: $message');
  dynamic data;
  try {
    data = jsonDecode(message);
  } catch (error) {
    log('[Bridge] JSON decode failed: $error');
    return;
  }
  if (data is! Map) return;

  final type = data['type'];
  log('[Bridge] received type=$type');

  switch (type) {
    case 'AUTH_REQUEST':
      await onAuthRequest();
    case 'OPEN_PAGE':
      final page = data['page'];
      if (page is String) onOpenPage(page);
    case 'OPEN_EXTERNAL_URL':
      await openExternalUrl(
        data['url'],
        launcher: externalUrlLauncher,
        logger: log,
      );
    default:
      log('[Bridge] unhandled type: $type');
  }
}

/// Hosts the AI Concierge WebView and the MobiBridge JS bridge — a two-way
/// `postMessage` channel between this app and the concierge page:
///
///  - App → page (`_postToPage`, delivered via `window.postMessage`):
///    CHANGE_LOCALE, OPEN_CHIPS, OPEN_PROMPT, LOGOUT, AUTH_CODE.
///  - Page → app (`MobiBridge.postMessage`, handled by `_onBridgeMessage`):
///    AUTH_REQUEST, OPEN_PAGE, OPEN_EXTERNAL_URL.
///
/// Sign-in: a signed-out concierge page loads `/request-auth`, which sends
/// AUTH_REQUEST and waits 3 seconds for AUTH_CODE before showing a "reload
/// the app" warning; it then exchanges the code for session cookies. The page
/// doesn't guard against duplicate or unsolicited codes, so the shell keeps
/// three promises:
///
///  1. Reply only when asked, with a fresh code. AUTH_CODE goes out only in
///     reply to AUTH_REQUEST — never on launch, resume or any other event —
///     and each reply carries a code never sent before. Codes are single-use,
///     so a resent code fails the exchange. (The demo code source repeats one
///     mock user id, which only a MOCK_AUTH deployment accepts; see
///     `native_auth.dart`.)
///  2. Reply within 3 seconds, without waiting on user input. A later reply
///     still signs the user in while the page is open.
///  3. Stay quiet while signed out, then reload. LOGOUT goes out only after
///     the native sign-out finishes, AUTH_REQUEST is ignored until a native
///     user signs in, and signing in reloads the WebView so the page asks for
///     a code again.
///
/// See `assets/concierge_demo.html` for a stand-in implementation of the
/// page side of this protocol.
class ConciergeTab extends StatefulWidget {
  final NativeAuth auth;
  final ValueChanged<String> onOpenPage;

  const ConciergeTab({super.key, required this.auth, required this.onOpenPage});

  @override
  State<ConciergeTab> createState() => ConciergeTabState();
}

class ConciergeTabState extends State<ConciergeTab>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;

  @override
  bool get wantKeepAlive => true;

  Future<void> reload() async {
    await _loadConcierge();
  }

  // Session lifecycle (new session on locale/chips/prompt) is handled by the
  // real app — this demo just posts the message into the page and logs it.
  Future<void> changeLocale(String locale) async {
    await _postToPage({'type': 'CHANGE_LOCALE', 'locale': locale});
  }

  // Call only after the native sign-out has finished (promise 3), so the page
  // can't request a code again and get one.
  Future<void> logout() async {
    await _postToPage({'type': 'LOGOUT'});
  }

  Future<void> openChips(String category) async {
    await _postToPage({'type': 'OPEN_CHIPS', 'category': category});
  }

  Future<void> openPrompt(String prompt) async {
    await _postToPage({'type': 'OPEN_PROMPT', 'prompt': prompt});
  }

  Future<void> _postToPage(Map<String, dynamic> payload) async {
    final json = jsonEncode(payload);
    await _controller.runJavaScript('window.postMessage($json, "*");');
  }

  Future<void> _loadConcierge() async {
    if (kConciergeSource == 'local') {
      await _controller.loadFlutterAsset(kLocalConciergeAsset);
    } else {
      await _controller.loadRequest(Uri.parse(kConciergeUrl));
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    final platform = _controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setInspectable(true);
      // iOS: addJavaScriptChannel registers a WKScriptMessageHandler which
      // exposes window.webkit.messageHandlers.MobiBridge. The plugin also
      // injects a user-script that aliases it as window.MobiBridge so the
      // web app can use the same call on both platforms.
    }
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kBgColor)
      // Disable iOS rubber-band overscroll (and Android overscroll glow).
      ..setOverScrollMode(WebViewOverScrollMode.never)
      // iOS  → window.webkit.messageHandlers.MobiBridge  (+ window.MobiBridge alias)
      // Android → window.MobiBridge  (JavascriptInterface)
      ..addJavaScriptChannel('MobiBridge', onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => debugPrint('[WebView] onPageStarted: $url'),
          onPageFinished: (url) => debugPrint('[WebView] onPageFinished: $url'),
          onWebResourceError: (e) => debugPrint(
            '[WebView] error: ${e.errorCode} ${e.description} url=${e.url}',
          ),
          onHttpError: (e) => debugPrint(
            '[WebView] http error: ${e.response?.statusCode} url=${e.request?.uri}',
          ),
        ),
      );
    _loadConcierge();
  }

  void _onBridgeMessage(JavaScriptMessage msg) {
    unawaited(
      dispatchMobiBridgeMessage(
        msg.message,
        onAuthRequest: _handleAuthRequest,
        onOpenPage: widget.onOpenPage,
      ),
    );
  }

  // Answer immediately with no dialog: the page stops waiting after 3s.
  Future<void> _handleAuthRequest() async {
    await answerAuthRequest(widget.auth, postToPage: _postToPage);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WebViewWidget(controller: _controller);
  }
}
