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

  test('WindowsBackendProcess.start (detached) really starts the process and returns its pid', () async {
    final ping = '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\PING.EXE';
    // Same code path as backend.exe (no args: ping prints usage and exits), then a
    // long-running detached ping for the path-match + kill check.
    final shortPid = await WindowsBackendProcess.start(ping, parentDirectoryOf(ping));
    expect(shortPid, isNotNull);
    expect(shortPid, greaterThan(0));

    final long = await Process.start(ping, ['-n', '30', '127.0.0.1'],
        mode: ProcessStartMode.detached);
    final ours = matchBackendProcesses(await WindowsBackendProcess.list(), ping);
    expect(ours.map((p) => p.$1), contains(long.pid));
    expect(await WindowsBackendProcess.kill(long.pid), isTrue);
  });

  test('terminating a non-existent pid returns false', () {
    expect(terminateProcessById(0x7FFFFFF0), isFalse);
  });
}
