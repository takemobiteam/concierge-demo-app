import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'benefits_tab.dart';
import 'concierge_tab.dart';
import 'more_tab.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Concierge Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBgColor,
        colorScheme: const ColorScheme.dark(
          surface: kBgColor,
          primary: kAccentColor,
        ),
        fontFamily: 'Georgia',
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const int _conciergeIndex = 3;

  static const _tabs = <_TabSpec>[
    _TabSpec('Home', Icons.home_outlined),
    _TabSpec('Benefits', Icons.search),
    _TabSpec('Membership', Icons.web_asset_outlined),
    _TabSpec('Concierge', Icons.chat_bubble_outline),
    _TabSpec('More', Icons.more_horiz),
  ];

  // The AI Concierge can ask the app to switch tabs via the MobiBridge
  // OPEN_PAGE message (see concierge_tab.dart) — this maps its page names
  // to the tab indices above. Keep in sync with _tabs.
  static const Map<String, int> _pageToTabIndex = {
    'home': 0,
    'benefits': 1,
    'membership': 2,
    // profile/cards/notifications/language don't have dedicated tabs yet —
    // route them to More until they do.
    'profile': 4,
    'cards': 4,
    'notifications': 4,
    'language': 4,
  };

  int _index = 0;
  String _locale = kLanguageOptions.first.code;
  final GlobalKey<ConciergeTabState> _conciergeKey =
      GlobalKey<ConciergeTabState>();

  Future<void> _clearCookiesAndReload() async {
    await WebViewCookieManager().clearCookies();
    await _conciergeKey.currentState?.reload();
  }

  // Triggered from the Language screen (More tab): just sends CHANGE_LOCALE
  // and updates the on-screen indicator — doesn't jump to the Concierge tab.
  Future<void> _changeLocale(String locale) async {
    setState(() => _locale = locale);
    await _conciergeKey.currentState?.changeLocale(locale);
  }

  Future<void> _openChips(String category) async {
    setState(() => _index = _conciergeIndex);
    await _conciergeKey.currentState?.openChips(category);
  }

  Future<void> _openPrompt(String prompt) async {
    setState(() => _index = _conciergeIndex);
    await _conciergeKey.currentState?.openPrompt(prompt);
  }

  void _openPage(String page) {
    final index = _pageToTabIndex[page];
    if (index == null) {
      debugPrint('[Bridge] OPEN_PAGE: unknown page "$page"');
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const PlaceholderTab(label: 'Home'),
      BenefitsTab(
        onOpenChips: _openChips,
        onOpenPrompt: _openPrompt,
      ),
      const PlaceholderTab(label: 'Membership'),
      ConciergeTab(key: _conciergeKey, onOpenPage: _openPage),
      MoreTab(
        onClearCookies: _clearCookiesAndReload,
        currentLocale: _locale,
        onChangeLocale: _changeLocale,
      ),
    ];

    return Scaffold(
      backgroundColor: kBgColor,
      // On the concierge tab, let WKWebView handle the keyboard natively.
      // If Flutter also resizes the body, the two fight and the webview
      // content flashes down then scrolls back up.
      resizeToAvoidBottomInset: _index != _conciergeIndex,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            for (int i = 0; i < pages.length; i++)
              Offstage(offstage: _index != i, child: pages[i]),
            Positioned(
              top: 8,
              right: 16,
              child: LocaleBadge(locale: _locale),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        tabs: _tabs,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  const _TabSpec(this.label, this.icon);
}

class _BottomNav extends StatelessWidget {
  final int index;
  final List<_TabSpec> tabs;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.index,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kBgColor,
        border: Border(top: BorderSide(color: Color(0xFF1C1C20))),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) {
          final selected = i == index;
          final color = selected ? kAccentColor : Colors.white;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tabs[i].icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  tabs[i].label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontFamily: 'Helvetica',
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
