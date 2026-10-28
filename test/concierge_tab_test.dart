import 'dart:async';

import 'package:concierge_demo_app/concierge_tab.dart';
import 'package:concierge_demo_app/native_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands out `code-1`, `code-2`, … like a single-use identity provider.
class _SequentialCodeSource implements AuthCodeSource {
  int _count = 0;

  @override
  Future<String> nextCode() async => 'code-${++_count}';
}

class _CompleterCodeSource implements AuthCodeSource {
  final completer = Completer<String>();

  @override
  Future<String> nextCode() => completer.future;
}

class _FailingCodeSource implements AuthCodeSource {
  @override
  Future<String> nextCode() async => throw Exception('provider unavailable');
}

void main() {
  group('AUTH_REQUEST', () {
    late List<Map<String, dynamic>> posted;
    late List<String> logs;

    setUp(() {
      posted = [];
      logs = [];
    });

    Future<void> dispatch(String message, NativeAuth auth) {
      return dispatchMobiBridgeMessage(
        message,
        onAuthRequest: () => answerAuthRequest(
          auth,
          postToPage: (payload) async => posted.add(payload),
          logger: logs.add,
        ),
        onOpenPage: (_) {},
        logger: logs.add,
      );
    }

    Future<void> sendAuthRequest(NativeAuth auth) =>
        dispatch('{"type":"AUTH_REQUEST"}', auth);

    test('replies immediately with AUTH_CODE, without user input', () async {
      final auth = NativeAuth(codeSource: _SequentialCodeSource());

      await sendAuthRequest(auth);

      expect(posted, [
        {'type': 'AUTH_CODE', 'code': 'code-1'},
      ]);
    });

    test('sends a fresh code with every reply', () async {
      final auth = NativeAuth(codeSource: _SequentialCodeSource());

      await sendAuthRequest(auth);
      await sendAuthRequest(auth);

      expect(posted.map((payload) => payload['code']), ['code-1', 'code-2']);
    });

    test('does not log the code', () async {
      final auth = NativeAuth(codeSource: _SequentialCodeSource());

      await sendAuthRequest(auth);

      expect(logs, contains('[Bridge] sent AUTH_CODE'));
      expect(logs.where((line) => line.contains('code-1')), isEmpty);
    });

    test('sends no AUTH_CODE for other messages', () async {
      final auth = NativeAuth(codeSource: _SequentialCodeSource());

      await dispatch('{"type":"OPEN_PAGE","page":"home"}', auth);
      await dispatch('{"type":"SOMETHING_NEW"}', auth);
      await dispatch('not json', auth);

      expect(posted, isEmpty);
    });

    test('stays quiet while signed out', () async {
      final auth = NativeAuth(codeSource: _SequentialCodeSource())..signOut();

      await sendAuthRequest(auth);

      expect(posted, isEmpty);
      expect(logs, contains('[Bridge] ignored AUTH_REQUEST: signed out'));
    });

    test('replies again after signing back in', () async {
      final auth = NativeAuth(codeSource: _SequentialCodeSource())..signOut();
      await sendAuthRequest(auth);

      auth.signIn();
      await sendAuthRequest(auth);

      expect(posted, [
        {'type': 'AUTH_CODE', 'code': 'code-1'},
      ]);
    });

    test('drops a code minted for a user who signed out meanwhile', () async {
      final source = _CompleterCodeSource();
      final auth = NativeAuth(codeSource: source);

      final reply = sendAuthRequest(auth);
      auth.signOut();
      source.completer.complete('code-1');
      await reply;

      expect(posted, isEmpty);
    });

    test('logs code source failures without replying or throwing', () async {
      final auth = NativeAuth(codeSource: _FailingCodeSource());

      await sendAuthRequest(auth);

      expect(posted, isEmpty);
      expect(logs, contains(contains('[Bridge] failed to get an auth code')));
    });

    test('the demo code source sends the configured mock user id', () async {
      final auth = NativeAuth();

      await sendAuthRequest(auth);

      expect(posted, [
        {'type': 'AUTH_CODE', 'code': kDemoAuthCode},
      ]);
    });
  });

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
