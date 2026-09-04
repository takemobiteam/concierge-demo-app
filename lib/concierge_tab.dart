import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

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
      break;
    case 'OPEN_PAGE':
      final page = data['page'];
      if (page is String) onOpenPage(page);
      break;
    case 'OPEN_EXTERNAL_URL':
      await openExternalUrl(
        data['url'],
        launcher: externalUrlLauncher,
        logger: log,
      );
      break;
    default:
      log('[Bridge] unhandled type: $type');
  }
}

/// Hosts the AI Concierge WebView and the MobiBridge JS bridge — a two-way
/// `postMessage` channel between this app and the concierge page:
///
///  - App → page (`_postToPage`, delivered via `window.postMessage`):
///    CHANGE_LOCALE, OPEN_CHIPS, OPEN_PROMPT.
///  - Page → app (`MobiBridge.postMessage`, handled by `_onBridgeMessage`):
///    AUTH_REQUEST, OPEN_PAGE, OPEN_EXTERNAL_URL.
///
/// See `assets/concierge_demo.html` for a stand-in implementation of the
/// page side of this protocol.
class ConciergeTab extends StatefulWidget {
  final ValueChanged<String> onOpenPage;

  const ConciergeTab({super.key, required this.onOpenPage});

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

  // The page requests an auth code; show it as an in-app alert, then post
  // AUTH_CODE back once the user acknowledges.
  Future<void> _handleAuthRequest() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text(
          'Auth code requested',
          style: TextStyle(color: Colors.white, fontFamily: 'Georgia'),
        ),
        content: const Text(
          'The concierge page requested an auth code.',
          style: TextStyle(color: kMutedText, fontFamily: 'Helvetica'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Send code',
              style: TextStyle(color: kAccentColor),
            ),
          ),
        ],
      ),
    );
    await _postToPage({'type': 'AUTH_CODE', 'code': '12345'});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WebViewWidget(controller: _controller);
  }
}
