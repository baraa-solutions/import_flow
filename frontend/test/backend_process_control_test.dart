@TestOn('windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/backend_launcher.dart';
import 'package:frontend/core/services/backend_process_control.dart';

/// Smoke tests for the real Win32 process helpers (no tasklist child process).
void main() {
  test('lists the current process with its full image path', () {
    final procs = listProcessImagePaths();
    expect(procs, isNotEmpty);
    final me = procs.where((p) => p.$1 == pid).toList();
    expect(me, hasLength(1));
    expect(isSameExecutablePath(me.single.$2, Platform.resolvedExecutable), isTrue);
  });

  test('terminates a process by pid', () async {
    final child = await Process.start('ping', ['-n', '30', '127.0.0.1']);
    final path = listProcessImagePaths().firstWhere((p) => p.$1 == child.pid).$2;
    expect(path.toLowerCase(), endsWith('ping.exe'));

    expect(terminateProcessById(child.pid), isTrue);
    expect(await child.exitCode.timeout(const Duration(seconds: 10)), 1);
  });

  test('terminating a non-existent pid returns false', () {
    expect(terminateProcessById(0x7FFFFFF0), isFalse);
  });
}
