// Regression for the v2.1.x close crash: windowManager.destroy() (PostQuitMessage)
// left the engine alive after the message loop ended -> AV in flutter_windows.dll,
// ~20 s white window, 0xC000041D. Closing must go through setPreventClose(false) + close().
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/app_window_close.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  late List<String> log;

  setUp(() {
    log = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call.method == 'setPreventClose'
          ? 'setPreventClose(${(call.arguments as Map)['isPreventClose']})'
          : call.method);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('closeMainWindowSafely sends setPreventClose(false) then close, never destroy', () async {
    await closeMainWindowSafely(windowManager);

    expect(log, ['setPreventClose(false)', 'close']);
    expect(log, isNot(contains('destroy')));
  });

  test('runAppCloseSequence keeps backup -> shutdown -> kill order, then closes the window', () async {
    await runAppCloseSequence(windowManager, steps: [
      () async => log.add('backup'),
      () async => log.add('shutdown'),
      () async => log.add('killOwnBackend'),
    ]);

    expect(log, ['backup', 'shutdown', 'killOwnBackend', 'setPreventClose(false)', 'close']);
  });

  test('a failing or timed-out step never stops the window from closing', () async {
    await runAppCloseSequence(windowManager, steps: [
      () async => throw Exception('backend down'),
      () => Future<void>.delayed(const Duration(seconds: 1))
          .timeout(const Duration(milliseconds: 10)),
      () async => log.add('killOwnBackend'),
    ]);

    expect(log, ['killOwnBackend', 'setPreventClose(false)', 'close']);
    expect(log, isNot(contains('destroy')));
  });
}
