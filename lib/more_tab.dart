import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

class LanguageOption {
  final String name;
  final String code;
  const LanguageOption(this.name, this.code);
}

const List<LanguageOption> kLanguageOptions = [
  LanguageOption('English', 'en-US'),
  LanguageOption('French', 'fr-CA'),
  LanguageOption('Spanish', 'es-LA'),
  LanguageOption('German', 'de-DE'),
  LanguageOption('Arabic', 'ar-QA'),
];

class MoreTab extends StatelessWidget {
  final Future<void> Function() onClearCookies;
  final String currentLocale;
  final ValueChanged<String> onChangeLocale;
  final Future<void> Function() onLogout;

  const MoreTab({
    super.key,
    required this.onClearCookies,
    required this.currentLocale,
    required this.onChangeLocale,
    required this.onLogout,
  });

  Future<void> _clearWebViewData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await onClearCookies();
      messenger.showSnackBar(
        const SnackBar(content: Text('WebView cookies cleared & reloaded')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  String _currentLanguageName() {
    return kLanguageOptions
        .firstWhere(
          (option) => option.code == currentLocale,
          orElse: () => kLanguageOptions.first,
        )
        .name;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text('More', style: kScreenTitleStyle),
          const SizedBox(height: 24),
          MoreRow(
            icon: Icons.language,
            label: 'Language',
            subtitle: _currentLanguageName(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LanguageScreen(
                  currentLocale: currentLocale,
                  onSelect: onChangeLocale,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          MoreRow(
            icon: Icons.cookie_outlined,
            label: 'Clear WebView cookies',
            subtitle: 'Sign out of the concierge session',
            onTap: () => _clearWebViewData(context),
          ),
          const SizedBox(height: 10),
          MoreRow(
            icon: Icons.logout_outlined,
            label: 'Log out',
            subtitle: 'Log out',
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class LanguageScreen extends StatelessWidget {
  final String currentLocale;
  final ValueChanged<String> onSelect;

  const LanguageScreen({
    super.key,
    required this.currentLocale,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        foregroundColor: Colors.white,
        title: const Text('Language', style: TextStyle(fontFamily: 'Georgia')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: kLanguageOptions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final option = kLanguageOptions[i];
          final selected = option.code == currentLocale;
          return InkWell(
            onTap: () {
              onSelect(option.code);
              Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? kAccentColor : const Color(0xFF24242A),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(option.name, style: kRowTitleStyle)),
                  Text(option.code, style: kRowSubtitleStyle),
                  if (selected) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.check_circle, color: kAccentColor),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
