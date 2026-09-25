import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/backend_launcher.dart';
import 'package:frontend/core/services/launcher_log.dart';
import 'package:frontend/core/widgets/backend_startup_gate.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';

const _exe = r'C:\ImportFlow\backend.exe';

/// Virtual clock: delays return immediately and advance `now`.
class _FakeClock implements LauncherClock {
  DateTime _now = DateTime(2026, 9, 25, 8);

  @override
  DateTime now() => _now;

  @override
  Future<void> delay(Duration duration) async {
    _now = _now.add(duration);
  }
}

Map<String, Object> _ours({bool maintenance = false}) =>
    {'status': 'OK', 'system': kBackendSystemName, 'maintenance_mode': maintenance};

class _Harness {
  _Harness({
    this.upAfterProbes,
    this.maintenance = false,
    this.exeExists = true,
    List<BackendProcessInfo>? processes,
    this.listThrows = false,
    this.startedStaysAlive = true,
    this.startThrows = false,
  }) : processes = processes ?? [];

  /// Whether a started backend.exe shows up in the process list (false = it
  /// exits right away, e.g. crash / lost the single-instance mutex).
  bool startedStaysAlive;
  bool startThrows;
  final log = MemoryLauncherLog();
  final List<String> workingDirs = [];
  final List<Map<String, String>> envs = [];
  Map<String, String> parentEnv = const {'PATH': r'C:\Windows', 'SystemRoot': r'C:\Windows'};

  /// Probe index (1-based) from which /health answers; null = never.
  final int? upAfterProbes;
  final bool maintenance;
  final bool exeExists;
  List<BackendProcessInfo> processes;
  bool listThrows;

  int probes = 0;
  final List<String> started = [];
  final List<int> killed = [];
  final clock = _FakeClock();

  BackendLauncher build({String? exe = _exe}) => BackendLauncher(
        healthCheck: () async {
          probes++;
          final up = upAfterProbes != null && probes >= upAfterProbes!;
          return up ? BackendHealth.up(maintenanceMode: maintenance) : const BackendHealth.down();
        },
        startProcess: (path, wd, env) async {
          envs.add(env);
          if (startThrows) throw const ProcessException('backend.exe', [], 'Access is denied.', 5);
          started.add(path);
          workingDirs.add(wd);
          final pid = 1000 + started.length;
          if (startedStaysAlive) processes = [...processes, (pid, path)];
          return pid;
        },
        listProcesses: () async {
          if (listThrows) throw StateError('EnumProcesses failed');
          return processes;
        },
        killProcess: (pid) async {
          killed.add(pid);
          processes = processes.where((p) => p.$1 != pid).toList();
          return true;
        },
        backendExecutablePath: exe,
        fileExists: (_) => exeExists,
        clock: clock,
        log: log,
        parentEnvironment: () => parentEnv,
      );
}

void main() {
  group('BackendHealth.fromResponse', () {
    test('200 from our backend is up', () {
      final h = BackendHealth.fromResponse(200, _ours());
      expect(h.isUp, isTrue);
      expect(h.maintenanceMode, isFalse);
    });
    test('200 with maintenance_mode is up and flagged', () {
      final h = BackendHealth.fromResponse(200, _ours(maintenance: true));
      expect(h.isUp, isTrue);
      expect(h.maintenanceMode, isTrue);
    });
    test('503 with our marker + maintenance_mode is up', () {
      expect(BackendHealth.fromResponse(503, _ours(maintenance: true)).isUp, isTrue);
    });
    test('a 200 from another program is foreign, not up', () {
      final h = BackendHealth.fromResponse(200, const {'status': 'ok', 'system': 'Some Dev Server'});
      expect(h.isUp, isFalse);
      expect(h.isForeign, isTrue);
      expect(BackendHealth.fromResponse(404, '<html>Not Found</html>').isForeign, isTrue);
      expect(BackendHealth.fromResponse(200, null).isForeign, isTrue);
    });
    test('5xx without our marker, or no response, is down', () {
      expect(BackendHealth.fromResponse(503, const {'detail': 'x'}).state, BackendHealthState.down);
      expect(BackendHealth.fromResponse(500, null).state, BackendHealthState.down);
      expect(BackendHealth.fromResponse(null, null).state, BackendHealthState.down);
    });
  });

  group('path matching', () {
    test('isSameExecutablePath ignores case, slashes and the \\\\?\\ prefix', () {
      expect(isSameExecutablePath(r'c:\importflow\BACKEND.EXE', _exe), isTrue);
      expect(isSameExecutablePath('C:/ImportFlow/backend.exe', _exe), isTrue);
      expect(isSameExecutablePath(r'\\?\C:\ImportFlow\backend.exe', _exe), isTrue);
      expect(isSameExecutablePath(r'C:\Other\backend.exe', _exe), isFalse);
      expect(isSameExecutablePath(r'C:\ImportFlow\backend.exe.old', _exe), isFalse);
    });
    test('matchBackendProcesses keeps only our exact path (both onefile processes)', () {
      final procs = <BackendProcessInfo>[
        (10, r'C:\ImportFlow\backend.exe'),
        (11, r'c:\importflow\backend.exe'),
        (12, r'D:\Dev\dist\backend.exe'),
        (13, r'C:\Windows\explorer.exe'),
      ];
      expect(matchBackendProcesses(procs, _exe).map((p) => p.$1), [10, 11]);
    });
  });

  group('BackendLauncher', () {
    test('backend already up: no start, ready after one probe', () async {
      final h = _Harness(upAfterProbes: 1);
      final launcher = h.build();
      final result = await launcher.ensureRunning();
      expect(result.phase, BackendLaunchPhase.ready);
      expect(result.startedProcess, isFalse);
      expect(h.started, isEmpty);
      expect(h.probes, 1);
    });

    test('backend down: starts once and polls until up', () async {
      final h = _Harness(upAfterProbes: 6);
      final launcher = h.build();
      final phases = <BackendLaunchPhase>[];
      launcher.status.addListener(() => phases.add(launcher.status.value.phase));

      final result = await launcher.ensureRunning();

      expect(result.phase, BackendLaunchPhase.ready);
      expect(result.startedProcess, isTrue);
      expect(h.started, [_exe]);
      expect(launcher.startCount, 1);
      expect(h.probes, 6);
      expect(phases, contains(BackendLaunchPhase.starting));
      expect(phases.last, BackendLaunchPhase.ready);
    });

    test('never up: timeout failure after the startup deadline, started once', () async {
      final h = _Harness(upAfterProbes: null);
      final launcher = h.build();
      final t0 = h.clock.now();

      final result = await launcher.ensureRunning();

      expect(result.phase, BackendLaunchPhase.failed);
      expect(result.failure, BackendLaunchFailure.timeout);
      expect(h.started, hasLength(1));
      expect(h.clock.now().difference(t0), greaterThanOrEqualTo(const Duration(seconds: 90)));
      expect(h.clock.now().difference(t0), lessThan(const Duration(seconds: 91)));
    });

    test('double call: one shared attempt, backend started once', () async {
      final h = _Harness(upAfterProbes: 4);
      final launcher = h.build();

      final a = launcher.ensureRunning();
      final b = launcher.ensureRunning();
      expect(identical(a, b), isTrue);
      final results = await Future.wait([a, b]);

      expect(results.every((r) => r.isReady), isTrue);
      expect(h.started, hasLength(1));
    });

    test('maintenance_mode counts as up: no start', () async {
      final h = _Harness(upAfterProbes: 1, maintenance: true);
      final result = await h.build().ensureRunning();
      expect(result.isReady, isTrue);
      expect(result.maintenanceMode, isTrue);
      expect(h.started, isEmpty);
    });

    test('foreign program on the port: portInUse failure, nothing started', () async {
      var probes = 0;
      final started = <String>[];
      final launcher = BackendLauncher(
        healthCheck: () async {
          probes++;
          return const BackendHealth.foreign();
        },
        startProcess: (p, _, __) async {
          started.add(p);
          return 1;
        },
        listProcesses: () async => const [],
        backendExecutablePath: _exe,
        fileExists: (_) => true,
        clock: _FakeClock(),
      );
      final result = await launcher.ensureRunning();
      expect(result.isFailed, isTrue);
      expect(result.failure, BackendLaunchFailure.portInUse);
      expect(started, isEmpty);
      expect(probes, 1);
    });

    test('foreign program appearing while polling: portInUse failure', () async {
      var probes = 0;
      final launcher = BackendLauncher(
        healthCheck: () async =>
            ++probes < 3 ? const BackendHealth.down() : const BackendHealth.foreign(),
        startProcess: (_, __, ___) async => 1,
        listProcesses: () async => const [],
        backendExecutablePath: _exe,
        fileExists: (_) => true,
        clock: _FakeClock(),
      );
      expect((await launcher.ensureRunning()).failure, BackendLaunchFailure.portInUse);
    });

    test('missing backend.exe: never starts, fails after the shorter connect deadline', () async {
      final h = _Harness(upAfterProbes: null, exeExists: false);
      final launcher = h.build();
      final t0 = h.clock.now();
      final result = await launcher.ensureRunning();
      expect(result.isFailed, isTrue);
      expect(h.started, isEmpty);
      expect(h.clock.now().difference(t0), lessThan(const Duration(seconds: 16)));
    });

    test('no local path (remote server URL): never starts', () async {
      final h = _Harness(upAfterProbes: 3);
      final result = await h.build(exe: null).ensureRunning();
      expect(result.isReady, isTrue);
      expect(h.started, isEmpty);
    });

    test('our backend.exe already alive (slow first start): waits, no second start, no kill', () async {
      final h = _Harness(upAfterProbes: 10, processes: [(42, _exe)]);
      final result = await h.build().ensureRunning();
      expect(result.isReady, isTrue);
      expect(result.startedProcess, isFalse);
      expect(h.started, isEmpty);
      expect(h.killed, isEmpty);
    });

    test('backend.exe from another folder does not block our start', () async {
      final h = _Harness(upAfterProbes: 3, processes: [(7, r'D:\Dev\dist\backend.exe')]);
      final result = await h.build().ensureRunning();
      expect(result.startedProcess, isTrue);
      expect(h.started, [_exe]);
      expect(h.killed, isEmpty);
    });

    test('plain re-run after a timeout: dead backend is started again', () async {
      final h = _Harness(upAfterProbes: null);
      final launcher = h.build();
      await launcher.ensureRunning();
      expect(h.started, hasLength(1));
      h.processes = []; // it died after the attempt
      await launcher.ensureRunning();
      expect(h.started, hasLength(2));
      expect(h.killed, isEmpty);
    });

    test('plain re-run while our backend.exe is alive but stuck: no kill, no start', () async {
      final h = _Harness(upAfterProbes: null, processes: [(42, _exe)]);
      final launcher = h.build();
      await launcher.ensureRunning();
      await launcher.ensureRunning();
      expect(h.killed, isEmpty);
      expect(h.started, isEmpty);
    });

    test('Retry (restartIfStuck) terminates the stuck backend.exe by pid and starts fresh', () async {
      final h = _Harness(
        upAfterProbes: null,
        processes: [(42, _exe), (43, r'\\?\C:\ImportFlow\backend.exe'), (7, r'D:\Dev\backend.exe')],
      );
      final launcher = h.build();
      expect((await launcher.ensureRunning()).isFailed, isTrue);
      expect(h.started, isEmpty);

      await launcher.ensureRunning(restartIfStuck: true);
      expect(h.killed, [42, 43], reason: 'only our exact path is terminated');
      expect(launcher.killCount, 2);
      expect(h.started, [_exe]);
    });

    test('process list throws: starts once; a new start is allowed only after the startup window', () async {
      final h = _Harness(upAfterProbes: null, listThrows: true);
      final launcher = h.build();

      final first = await launcher.ensureRunning();
      expect(first.startedProcess, isTrue);
      expect(h.started, hasLength(1));

      // Deadline (90 s) has elapsed since that start -> a new start is allowed.
      await launcher.ensureRunning();
      expect(h.started, hasLength(2));
    });

    test('recent-start guard: within the startup window no second start without a process list', () async {
      var calls = 0;
      final started = <String>[];
      final clock = _FakeClock();
      final launcher = BackendLauncher(
        // Down on probe 1 of each run (runs 1 and 2), up otherwise.
        healthCheck: () async => const [1, 3].contains(++calls)
            ? const BackendHealth.down()
            : const BackendHealth.up(),
        startProcess: (p, _, __) async {
          started.add(p);
          return 1;
        },
        listProcesses: () async => throw StateError('no snapshot'),
        backendExecutablePath: _exe,
        fileExists: (_) => true,
        clock: clock,
      );
      await launcher.ensureRunning(); // starts, up after one poll (~0.5 s)
      expect(started, hasLength(1));
      await launcher.ensureRunning(); // down again 0.5 s later -> guarded
      expect(started, hasLength(1));
    });

    test('health checker that throws is treated as down', () async {
      var calls = 0;
      final launcher = BackendLauncher(
        healthCheck: () async {
          calls++;
          if (calls < 3) throw StateError('socket');
          return const BackendHealth.up();
        },
        startProcess: (_, __, ___) async => 1,
        backendExecutablePath: _exe,
        fileExists: (_) => true,
        clock: _FakeClock(),
      );
      expect((await launcher.ensureRunning()).isReady, isTrue);
      expect(launcher.startCount, 1);
    });

    test('disabled launcher is ready immediately', () async {
      final launcher = BackendLauncher.disabled();
      expect(launcher.status.value.isReady, isTrue);
      expect((await launcher.ensureRunning()).isReady, isTrue);
    });
  });

  group('early exit, start failures and the diagnostic log', () {
    test('started backend.exe that exits early is restarted, bounded to 3 starts', () async {
      final h = _Harness(upAfterProbes: null, startedStaysAlive: false);
      final launcher = h.build();
      final result = await launcher.ensureRunning();
      expect(result.failure, BackendLaunchFailure.timeout);
      expect(h.started, hasLength(3));
      expect(h.log.any('exited early'), isTrue);
      expect(h.log.any('start limit 3 reached'), isTrue);
    });

    test('backend that exits once and then stays alive gets exactly one restart', () async {
      final h = _Harness(upAfterProbes: 20, startedStaysAlive: false);
      final launcher = h.build();
      var sawStarting = false;
      launcher.status.addListener(() {
        if (!sawStarting && launcher.status.value.phase == BackendLaunchPhase.starting) {
          sawStarting = true;
          h.startedStaysAlive = true; // the restart will stay up
        }
      });
      final result = await launcher.ensureRunning();
      expect(result.isReady, isTrue);
      expect(h.started, hasLength(2));
    });

    test('Process.start failure is logged with the exception, not swallowed', () async {
      final h = _Harness(upAfterProbes: null, startThrows: true);
      final launcher = h.build();
      final result = await launcher.ensureRunning();
      expect(result.isFailed, isTrue);
      expect(launcher.startCount, 0);
      expect(h.log.any('start: path=$_exe workingDirectory=C:\\ImportFlow'), isTrue);
      expect(h.log.any(RegExp(r'start FAILED: ProcessException: .*Access is denied')), isTrue);
    });

    test('start passes the backend folder as working directory', () async {
      final h = _Harness(upAfterProbes: 2);
      await h.build().ensureRunning();
      expect(h.workingDirs, [r'C:\ImportFlow']);
    });

    test('log covers config, every probe, process list, start, ready', () async {
      final h = _Harness(upAfterProbes: 3);
      await h.build().ensureRunning();
      final lines = h.log.lines;
      expect(lines.first, contains('backendExecutablePath=$_exe'));
      expect(lines.first, contains('fileExists=true'));
      expect(lines.where((l) => l.contains('probe ')), hasLength(3));
      expect(h.log.any('probe 1: down'), isTrue);
      expect(h.log.any('probe 3: up'), isTrue);
      expect(h.log.any('process list: 0 processes, matched none'), isTrue);
      expect(h.log.any('start OK pid=1001'), isTrue);
      expect(h.log.any(RegExp(r'READY after \d+ ms startedProcess=true')), isTrue);
    });

    test('log covers foreign, maintenance, kills, list errors and failure reason', () async {
      final foreignLog = MemoryLauncherLog();
      await BackendLauncher(
        healthCheck: () async => const BackendHealth.foreign(statusCode: 404),
        clock: _FakeClock(),
        log: foreignLog,
      ).ensureRunning();
      expect(foreignLog.any('probe 1: foreign 404'), isTrue);
      expect(foreignLog.any('FAILED reason=portInUse'), isTrue);

      final m = _Harness(upAfterProbes: 1, maintenance: true);
      await m.build().ensureRunning();
      expect(m.log.any('maintenance=true'), isTrue);

      final k = _Harness(upAfterProbes: null, processes: [(42, _exe)]);
      final launcher = k.build();
      await launcher.ensureRunning();
      expect(k.log.any('FAILED reason=timeout'), isTrue);
      expect(k.log.any('already running, waiting'), isTrue);
      await launcher.ensureRunning(restartIfStuck: true);
      expect(k.log.any('kill pid=42 path=$_exe ok=true'), isTrue);

      final e = _Harness(upAfterProbes: 2, listThrows: true);
      await e.build().ensureRunning();
      expect(e.log.any('process list ERROR: Bad state: EnumProcesses failed'), isTrue);
    });

    test('down probe carries the connection error text into the log', () {
      const h = BackendHealth.down(error: 'connectionError: SocketException: refused');
      expect(h.describe(), 'down (connectionError: SocketException: refused)');
      expect(BackendHealth.fromResponse(503, const {'detail': 'x'}).describe(), 'down 503');
    });
  });

  group('sanitizeBackendEnvironment (PyInstaller onefile)', () {
    const inherited = <String, String>{
      'PATH': r'C:\Windows\System32',
      'SystemRoot': r'C:\Windows',
      'LOCALAPPDATA': r'C:\Users\u\AppData\Local',
      '_PYI_APPLICATION_HOME_DIR': r'C:\Users\u\AppData\Local\Temp\_MEI1234',
      '_PYI_ARCHIVE_FILE': r'C:\Program Files\Sorour\backend.exe',
      '_PYI_PARENT_PROCESS_LEVEL': '1',
      '_pyi_splash_ipc': 'x',
      '_MEIPASS2': r'C:\Temp\_MEI1234',
      '_meipass': 'y',
      'PYINSTALLER_RESET_ENVIRONMENT': '0',
      'MY_PYI_SETTING': 'kept', // only the prefix counts
      '_MEIX': 'kept',
    };

    test('drops every _PYI_* / _MEIPASS* key case-insensitively and keeps the rest', () {
      final r = sanitizeBackendEnvironment(inherited);
      expect(r.environment.keys.where((k) => k.toUpperCase().startsWith('_PYI_')), isEmpty);
      expect(r.environment.keys.where((k) => k.toUpperCase().startsWith('_MEIPASS')), isEmpty);
      expect(r.environment['PATH'], r'C:\Windows\System32');
      expect(r.environment['SystemRoot'], r'C:\Windows');
      expect(r.environment['LOCALAPPDATA'], r'C:\Users\u\AppData\Local');
      expect(r.environment['MY_PYI_SETTING'], 'kept');
      expect(r.environment['_MEIX'], 'kept');
    });

    test('forces PYINSTALLER_RESET_ENVIRONMENT=1', () {
      expect(sanitizeBackendEnvironment(inherited).environment['PYINSTALLER_RESET_ENVIRONMENT'], '1');
      expect(sanitizeBackendEnvironment(const {}).environment, {'PYINSTALLER_RESET_ENVIRONMENT': '1'});
    });

    test('reports removed key NAMES only, sorted', () {
      final r = sanitizeBackendEnvironment(inherited);
      expect(r.removedKeys, [
        '_MEIPASS2',
        '_PYI_APPLICATION_HOME_DIR',
        '_PYI_ARCHIVE_FILE',
        '_PYI_PARENT_PROCESS_LEVEL',
        '_meipass',
        '_pyi_splash_ipc',
      ]);
      expect(r.removedKeys.join(' '), isNot(contains('_MEI1234')));
    });

    test('does not mutate the parent map', () {
      final parent = Map<String, String>.of(inherited);
      sanitizeBackendEnvironment(parent);
      expect(parent, inherited);
    });

    test('the launcher starts backend.exe with the sanitized environment and logs names only', () async {
      final h = _Harness(upAfterProbes: 2)..parentEnv = inherited;
      await h.build().ensureRunning();
      expect(h.envs, hasLength(1));
      final env = h.envs.single;
      expect(env.containsKey('_PYI_ARCHIVE_FILE'), isFalse);
      expect(env['PYINSTALLER_RESET_ENVIRONMENT'], '1');
      expect(env['PATH'], r'C:\Windows\System32');
      final line = h.log.lines.firstWhere((l) => l.contains('start env:'));
      expect(line, contains('_PYI_APPLICATION_HOME_DIR'));
      expect(line, contains('PYINSTALLER_RESET_ENVIRONMENT=1'));
      expect(line, isNot(contains('_MEI1234')), reason: 'values are never logged');
      expect(line, isNot(contains(r'Program Files')));
    });

    test('a clean environment logs "removed none"', () async {
      final h = _Harness(upAfterProbes: 2);
      await h.build().ensureRunning();
      expect(h.log.any('removed none'), isTrue);
    });
  });

  group('FileLauncherLog', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('launcher_log_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String join(List<String> parts) => parts.join(Platform.pathSeparator);

    test('creates missing folders and appends timestamped lines', () {
      final path = join([tmp.path, 'a', 'b', 'launcher.log']);
      final log = FileLauncherLog(path, now: () => DateTime(2026, 9, 25, 10, 30));
      log.write('hello');
      log.write('world');
      final text = File(path).readAsStringSync();
      expect(text, contains('2026-09-25T10:30:00.000 [pid $pid] hello'));
      expect(text.trim().split('\n'), hasLength(2));
    });

    test('rotates once to .1 past maxBytes and keeps only one backup', () {
      final path = join([tmp.path, 'launcher.log']);
      final log = FileLauncherLog(path, maxBytes: 1000);
      for (var i = 0; i < 200; i++) {
        log.write('line $i ${'x' * 40}');
      }
      expect(File('$path.1').existsSync(), isTrue);
      expect(File('$path.2').existsSync(), isFalse);
      expect(File(path).lengthSync(), lessThan(1200));
      expect(File(path).readAsStringSync(), contains('line 199'));
    });

    test('never throws on an unwritable path', () {
      final log = FileLauncherLog(join([tmp.path, 'bad\u0000name']));
      expect(() => log.write('x'), returnsNormally);
    });

    test('defaultPath uses LOCALAPPDATA', () {
      expect(FileLauncherLog.defaultPath(const {'LOCALAPPDATA': r'C:\Users\u\AppData\Local'}),
          r'C:\Users\u\AppData\Local\SorourLogistics\logs\launcher.log');
      expect(FileLauncherLog.defaultPath(const {}), isNull);
    });
  });

  test('redactUrl drops credentials and query strings', () {
    expect(redactUrl('http://user:secret@127.0.0.1:28080/health?token=abc'),
        'http://127.0.0.1:28080/health');
    expect(redactUrl('http://127.0.0.1:28080'), 'http://127.0.0.1:28080');
  });

  test('parentDirectoryOf', () {
    expect(parentDirectoryOf(r'C:\ImportFlow\backend.exe'), r'C:\ImportFlow');
    expect(parentDirectoryOf('/opt/app/backend'), '/opt/app');
  });

  test('main.dart builds the backend path with an escaped backslash', () {
    // A single backslash before "backend.exe" is a backspace (\b) escape in Dart.
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains(r"'$exeDir\\backend.exe'"));
    expect(src, isNot(contains(r"'$exeDir\backend.exe'")));
  });

  group('recoverBackendOnConnectionError', () {
    DioException err(DioExceptionType type) =>
        DioException(requestOptions: RequestOptions(path: '/x'), type: type);

    test('connection error after ready re-runs the launcher once', () async {
      final h = _Harness(upAfterProbes: 1);
      final launcher = h.build();
      await launcher.ensureRunning();
      expect(h.probes, 1);

      recoverBackendOnConnectionError(launcher, err(DioExceptionType.connectionError));
      recoverBackendOnConnectionError(launcher, err(DioExceptionType.connectionTimeout));
      await Future<void>.delayed(Duration.zero);
      await launcher.ensureRunning();
      expect(h.probes, lessThanOrEqualTo(3));
      expect(h.probes, greaterThan(1));
    });

    test('bad responses and pre-ready states are ignored', () async {
      final h = _Harness(upAfterProbes: 1);
      final launcher = h.build();
      recoverBackendOnConnectionError(launcher, err(DioExceptionType.connectionError));
      expect(h.probes, 0, reason: 'not ready yet: startup flow owns it');
      await launcher.ensureRunning();
      recoverBackendOnConnectionError(launcher, err(DioExceptionType.badResponse));
      await Future<void>.delayed(Duration.zero);
      expect(h.probes, 1);
    });
  });

  test('isLoopbackServerUrl', () {
    expect(isLoopbackServerUrl('http://127.0.0.1:8000'), isTrue);
    expect(isLoopbackServerUrl('http://localhost:8000'), isTrue);
    expect(isLoopbackServerUrl('http://192.168.1.20:8000'), isFalse);
  });

  group('BackendStartupGate', () {
    Widget app(BackendLauncher launcher, {Locale locale = const Locale('en'), Widget? child}) =>
        ProviderScope(
          overrides: [backendLauncherProvider.overrideWithValue(launcher)],
          child: AppLocalizationsProvider(
            locale: locale,
            child: MaterialApp(
              home: BackendStartupGate(child: child ?? const Text('AUTH-GATE')),
            ),
          ),
        );

    testWidgets('shows child when the backend is ready', (tester) async {
      await tester.pumpWidget(app(BackendLauncher.disabled()));
      await tester.pump();
      expect(find.text('AUTH-GATE'), findsOneWidget);
    });

    testWidgets('shows starting state, then the child once /health answers', (tester) async {
      final gate = Completer<BackendHealth>();
      var calls = 0;
      final launcher = BackendLauncher(
        healthCheck: () {
          calls++;
          return calls == 1 ? gate.future : Future.value(const BackendHealth.up());
        },
        clock: _FakeClock(),
      );
      await tester.pumpWidget(app(launcher));
      await tester.pump();
      expect(find.text('Starting the system…'), findsOneWidget);
      expect(find.text('AUTH-GATE'), findsNothing);

      gate.complete(const BackendHealth.up());
      await tester.pump();
      await tester.pump();
      expect(find.text('AUTH-GATE'), findsOneWidget);
    });

    testWidgets('timeout shows localized error and Retry recovers (ar)', (tester) async {
      var up = false;
      final launcher = BackendLauncher(
        healthCheck: () async => up ? const BackendHealth.up() : const BackendHealth.down(),
        startProcess: (_, __, ___) async => 1,
        listProcesses: () async => const [],
        backendExecutablePath: _exe,
        fileExists: (_) => true,
        clock: _FakeClock(),
      );
      await tester.pumpWidget(app(launcher, locale: const Locale('ar')));
      await tester.pump();
      await tester.pump();
      expect(find.text('لم يتم تشغيل النظام'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'إعادة المحاولة'), findsOneWidget);

      up = true;
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.pump();
      expect(find.text('AUTH-GATE'), findsOneWidget);
    });

    testWidgets('foreign program shows the port-in-use message (en)', (tester) async {
      final launcher = BackendLauncher(
        healthCheck: () async => const BackendHealth.foreign(),
        clock: _FakeClock(),
      );
      await tester.pumpWidget(app(launcher));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Another program is using port'), findsOneWidget);
    });

    testWidgets('recovery after ready overlays the app without unmounting it', (tester) async {
      var up = true;
      final launcher = BackendLauncher(
        healthCheck: () async => up ? const BackendHealth.up() : const BackendHealth.down(),
        clock: _FakeClock(),
      );
      await tester.pumpWidget(app(launcher, child: const _Counter()));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('inc')));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);

      up = false;
      recoverBackendOnConnectionError(
        launcher,
        DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget, reason: 'child state kept under the overlay');
      expect(find.byType(ModalBarrier), findsWidgets);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Text('count $_n'),
          TextButton(key: const ValueKey('inc'), onPressed: () => setState(() => _n++), child: const Text('+')),
        ]),
      );
}
