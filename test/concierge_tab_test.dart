import 'package:concierge_demo_app/concierge_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('OPEN_EXTERNAL_URL', () {
    for (final url in <String>[
      'https://example.com/terms',
      'http://example.com/terms',
    ]) {
      test('launches $url in an external application', () async {
        Uri? launchedUri;
        LaunchMode? launchedMode;

        await dispatchMobiBridgeMessage(
          '{"type":"OPEN_EXTERNAL_URL","url":"$url"}',
          onAuthRequest: () async {},
          onOpenPage: (_) {},
          externalUrlLauncher: (uri, {required mode}) async {
            launchedUri = uri;
            launchedMode = mode;
            return true;
          },
        );

        expect(launchedUri, Uri.parse(url));
        expect(launchedMode, LaunchMode.externalApplication);
      });
    }

    for (final url in <String>[
      'javascript:alert(1)',
      'data:text/html,hello',
      'file:///etc/passwd',
      'myapp://account',
    ]) {
      test('rejects ${Uri.parse(url).scheme} URLs', () async {
        var launchCount = 0;

        await dispatchMobiBridgeMessage(
          '{"type":"OPEN_EXTERNAL_URL","url":"$url"}',
          onAuthRequest: () async {},
          onOpenPage: (_) {},
          externalUrlLauncher: (uri, {required mode}) async {
            launchCount++;
            return true;
          },
        );

        expect(launchCount, 0);
      });
    }

    test('rejects a malformed URL without throwing', () async {
      var launchCount = 0;

      await dispatchMobiBridgeMessage(
        '{"type":"OPEN_EXTERNAL_URL","url":"not a URL"}',
        onAuthRequest: () async {},
        onOpenPage: (_) {},
        externalUrlLauncher: (uri, {required mode}) async {
          launchCount++;
          return true;
        },
      );

      expect(launchCount, 0);
    });

    test('logs launcher failures without throwing', () async {
      final logs = <String>[];

      await dispatchMobiBridgeMessage(
        '{"type":"OPEN_EXTERNAL_URL","url":"https://example.com"}',
        onAuthRequest: () async {},
        onOpenPage: (_) {},
        externalUrlLauncher: (uri, {required mode}) async {
          throw Exception('launcher unavailable');
        },
        logger: logs.add,
      );

      expect(
        logs,
        contains(
          contains('[Bridge] failed to open external URL: https://example.com'),
        ),
      );
    });

    test('logs when the platform declines to launch', () async {
      final logs = <String>[];

      await dispatchMobiBridgeMessage(
        '{"type":"OPEN_EXTERNAL_URL","url":"https://example.com"}',
        onAuthRequest: () async {},
        onOpenPage: (_) {},
        externalUrlLauncher: (uri, {required mode}) async => false,
        logger: logs.add,
      );

      expect(
        logs,
        contains('[Bridge] failed to open external URL: https://example.com'),
      );
    });
  });

  test('unknown message types remain logged as unhandled', () async {
    final logs = <String>[];

    await dispatchMobiBridgeMessage(
      '{"type":"SOMETHING_NEW"}',
      onAuthRequest: () async {},
      onOpenPage: (_) {},
      logger: logs.add,
    );

    expect(logs, contains('[Bridge] unhandled type: SOMETHING_NEW'));
  });
}
