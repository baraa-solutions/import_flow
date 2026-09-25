import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/backend_launcher.dart';
import 'package:frontend/core/services/launcher_log.dart';
import 'package:frontend/core/widgets/backend_startup_gate.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:path/path.dart' as p;

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

/// In-memory log (test double; not shipped in lib/).
class _MemoryLog implements LauncherLog {
  final List<String> lines = [];
  int flushes = 0;

  @override
  void write(String message) => lines.add(message);

  @override
  void flush() => flushes++;

  bool any(Pattern pattern) => lines.any((l) => l.contains(pattern));
}

Map<String, Object> _ours({bool maintenance = false}) =>
    {'status': 'OK', 'system': kBackendSystemName, 'maintenance_mode': maintenance};

/// Fake OS around one launcher: /health, process table, start and kill.
class _Harness {
  _Harness({
    this.upAfterProbes,
    this.maintenance = false,
    this.exeExists = true,
    List<BackendProcessInfo>? processes,
    this.listThrows = false,
    this.startsThatDie = 0,
    this.startThrows = false,
    this.healthCheck,
  }) : processes = processes ?? [];

  /// Probe index (1-based) from which /health answers; null = never.
  final int? upAfterProbes;
  final bool maintenance;
  final bool exeExists;
  List<BackendProcessInfo> processes;
  bool listThrows;

  /// The first N started processes exit immediately (crash / lost the mutex).
  int startsThatDie;
  bool startThrows;

  /// Replaces the [upAfterProbes] health model.
  final BackendHealthChecker? healthCheck;

  int probes = 0;
  final List<String> started = [];
  final List<String> workingDirs = [];
  final List<Map<String, String>> envs = [];
  final List<String> listedNames = [];
  final List<int> killed = [];
  final clock = _FakeClock();
  final log = _MemoryLog();
  Map<String, String> parentEnv = const {'PATH': r'C:\Windows', 'SystemRoot': r'C:\Windows'};

  Future<BackendHealth> _health() async {
    probes++;
    final up = upAfterProbes != null && probes >= upAfterProbes!;
    return up ? BackendHealth.up(maintenanceMode: maintenance) : const BackendHealth.down();
  }

  BackendLauncher build({String? exe = _exe}) => BackendLauncher(
        healthCheck: healthCheck ?? _health,
        startProcess: (path, wd, env) async {
          envs.add(env);
          if (startThrows) throw const ProcessException('backend.exe', [], 'Access is denied.', 5);
          started.add(path);
          workingDirs.add(wd);
          final pid = 1000 + started.length;
          if (started.length > startsThatDie) processes = [...processes, (pid, path)];
          return pid;
        },
        listProcesses: (imageName) async {
          listedNames.add(imageName);
          if (listThrows) throw StateError('snapshot failed');
          // Like the Toolhelp snapshot: filtered by image name only.
          return processes
              .where((proc) => p.windows.basename(proc.$2).toLowerCase() == imageName.toLowerCase())
              .toList();
        },
        killProcess: (pid) async {
          killed.add(pid);
          processes = processes.where((proc) => proc.$1 != pid).toList();
          return true;
        },
        backendExecutablePath: exe,
        fileExists: (_) => exeExists,
        clock: clock,
        log: log,
        parentEnvironment: () => parentEnv,
      );
}

DioException _dioError(DioExceptionType type) =>
    DioException(requestOptions: RequestOptions(path: '/x'), type: type);

class _ConnectionRefusedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      throw DioException.connectionError(requestOptions: options, reason: 'refused');

  @override
  void close({bool force = false}) {}
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
    test('describe() carries status code / error text for the log', () {
      const h = BackendHealth.down(error: 'connectionError: SocketException: refused');
      expect(h.describe(), 'down (connectionError: SocketException: refused)');
      expect(BackendHealth.fromResponse(503, const {'detail': 'x'}).describe(), 'down 503');
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
      expect(matchBackendProcesses(procs, _exe).map((proc) => proc.$1), [10, 11]);
    });
  });

  group('BackendLauncher', () {
    test('backend already up: no start, ready after one probe', () async {
      final h = _Harness(upAfterProbes: 1);
      final launcher = h.build();
      final result = await launcher.ensureRunning();
      expect(result.phase, BackendLaunchPhase.ready);
      expect(h.started, isEmpty);
      expect(h.probes, 1);
    });

    test('backend down: starts once and polls until up', () async {
      final h = _Harness(upAfterProbes: 6);
      final launcher = h.build();
      final result = await launcher.ensureRunning();
      expect(result.isReady, isTrue);
      expect(h.started, [_exe]);
      expect(launcher.startCount, 1);
      expect(h.probes, 6);
      expect(h.listedNames.first, 'backend.exe', reason: 'the snapshot is filtered by image name');
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
      expect(h.started, isEmpty);
      expect(h.log.any('maintenance=true'), isTrue);
    });

    test('foreign program on the port: portInUse failure, nothing started', () async {
      final h = _Harness(healthCheck: () async => const BackendHealth.foreign(statusCode: 404));
      final result = await h.build().ensureRunning();
      expect(result.failure, BackendLaunchFailure.portInUse);
      expect(h.started, isEmpty);
      expect(h.log.any('probe 1: foreign 404'), isTrue);
    });

    test('foreign program appearing while polling: portInUse failure', () async {
      var n = 0;
      final h = _Harness(
        healthCheck: () async => ++n < 3 ? const BackendHealth.down() : const BackendHealth.foreign(),
      );
      expect((await h.build().ensureRunning()).failure, BackendLaunchFailure.portInUse);
    });

    test('missing backend.exe: never starts, fails after the shorter connect deadline', () async {
      final h = _Harness(upAfterProbes: null, exeExists: false);
      final launcher = h.build();
      final t0 = h.clock.now();
      final result = await launcher.ensureRunning();
      expect(result.isFailed, isTrue);
      expect(h.started, isEmpty);
      expect(h.clock.now().difference(t0), lessThan(const Duration(seconds: 16)));
      expect(h.log.lines.first, contains('fileExists=false'));
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
      expect(h.started, isEmpty);
      expect(h.killed, isEmpty);
    });

    test('backend.exe from another folder does not block our start', () async {
      final h = _Harness(upAfterProbes: 3, processes: [(7, r'D:\Dev\dist\backend.exe')]);
      await h.build().ensureRunning();
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
      await launcher.ensureRunning();
      expect(h.started, hasLength(1));
      await launcher.ensureRunning(); // 90 s have passed since that start
      expect(h.started, hasLength(2));
    });

    test('recent-start guard: within the startup window no second start without a process list', () async {
      var n = 0;
      // Down on the first probe of each of the two runs (probes 1 and 3), up otherwise.
      final h = _Harness(
        listThrows: true,
        healthCheck: () async =>
            const [1, 3].contains(++n) ? const BackendHealth.down() : const BackendHealth.up(),
      );
      final launcher = h.build();
      await launcher.ensureRunning(); // starts, up after one poll (~0.5 s)
      expect(h.started, hasLength(1));
      await launcher.ensureRunning(); // down again 0.5 s later -> guarded
      expect(h.started, hasLength(1));
      expect(h.log.any('no process list and the last start was'), isTrue);
    });

    test('health checker that throws is treated as down', () async {
      var n = 0;
      final h = _Harness(healthCheck: () async {
        if (++n < 3) throw StateError('socket');
        return const BackendHealth.up();
      });
      expect((await h.build().ensureRunning()).isReady, isTrue);
      expect(h.started, hasLength(1));
      expect(h.log.any('health check threw: Bad state: socket'), isTrue);
    });

    test('disabled launcher is ready immediately and kills nothing', () async {
      final launcher = BackendLauncher.disabled();
      expect(launcher.status.value.isReady, isTrue);
      expect((await launcher.ensureRunning()).isReady, isTrue);
      expect(await launcher.killOwnBackend(), 0);
    });
  });

  group('killOwnBackend (window close)', () {
    test('terminates only processes running exactly our backend.exe', () async {
      final h = _Harness(processes: [
        (42, _exe),
        (43, r'c:\importflow\backend.exe'),
        (7, r'D:\OtherInstall\backend.exe'),
      ]);
      final launcher = h.build();
      expect(await launcher.killOwnBackend(), 2);
      expect(h.killed, [42, 43]);
      expect(h.processes.map((proc) => proc.$1), [7]);
      expect(h.log.any('kill pid=42 path=$_exe ok=true'), isTrue);
      expect(h.log.flushes, greaterThan(0));
    });

    test('remote server (no local path): kills nothing', () async {
      final h = _Harness(processes: [(42, _exe)]);
      expect(await h.build(exe: null).killOwnBackend(), 0);
      expect(h.killed, isEmpty);
    });
  });

  group('early exit, start failures and the diagnostic log', () {
    test('started backend.exe that keeps exiting is restarted, bounded to 3 starts', () async {
      final h = _Harness(upAfterProbes: null, startsThatDie: 99);
      final result = await h.build().ensureRunning();
      expect(result.failure, BackendLaunchFailure.timeout);
      expect(h.started, hasLength(3));
      expect(h.log.lines.where((l) => l.contains('exited early')), hasLength(2));
      expect(h.log.lines.where((l) => l.contains('start limit 3 reached')), hasLength(1),
          reason: 'the limit is logged once');
    });

    test('backend that exits once and then stays alive gets exactly one restart', () async {
      final h = _Harness(upAfterProbes: 20, startsThatDie: 1);
      final result = await h.build().ensureRunning();
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

    test('log covers config, every probe, process list, start, ready; flushes on the outcome', () async {
      final h = _Harness(upAfterProbes: 3);
      await h.build().ensureRunning();
      final lines = h.log.lines;
      expect(lines.first, contains('backendExecutablePath=$_exe'));
      expect(lines.first, contains('fileExists=true'));
      expect(lines.where((l) => l.contains('probe ')), hasLength(3));
      expect(h.log.any('probe 1: down'), isTrue);
      expect(h.log.any('probe 3: up'), isTrue);
      expect(h.log.any('process list: 0 backend.exe processes, matched none'), isTrue);
      expect(h.log.any('start OK pid=1001'), isTrue);
      expect(h.log.any(RegExp(r'READY after \d+ ms starts=1')), isTrue);
      expect(h.log.flushes, 1);
    });

    test('log covers kills, list errors and the failure reason; flushes on FAILED', () async {
      final k = _Harness(upAfterProbes: null, processes: [(42, _exe)]);
      final launcher = k.build();
      await launcher.ensureRunning();
      expect(k.log.any('FAILED reason=timeout'), isTrue);
      expect(k.log.flushes, 1);
      expect(k.log.any('already running, waiting'), isTrue);
      await launcher.ensureRunning(restartIfStuck: true);
      expect(k.log.any('kill pid=42 path=$_exe ok=true'), isTrue);

      final e = _Harness(upAfterProbes: 2, listThrows: true);
      await e.build().ensureRunning();
      expect(e.log.any('process list ERROR: Bad state: snapshot failed'), isTrue);
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
      'pyinstaller_reset_environment': '0',
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

    test('forces exactly one PYINSTALLER_RESET_ENVIRONMENT=1 (any inherited casing is replaced)', () {
      final env = sanitizeBackendEnvironment(inherited).environment;
      expect(env.keys.where((k) => k.toUpperCase() == 'PYINSTALLER_RESET_ENVIRONMENT'),
          ['PYINSTALLER_RESET_ENVIRONMENT']);
      expect(env['PYINSTALLER_RESET_ENVIRONMENT'], '1');
      expect(sanitizeBackendEnvironment(const {}).environment, {'PYINSTALLER_RESET_ENVIRONMENT': '1'});
    });

    test('reports removed key NAMES only, sorted (the reset key is not "removed")', () {
      final r = sanitizeBackendEnvironment(inherited);
      expect(r.removedKeys, [
        '_MEIPASS2',
        '_PYI_APPLICATION_HOME_DIR',
        '_PYI_ARCHIVE_FILE',
        '_PYI_PARENT_PROCESS_LEVEL',
        '_meipass',
        '_pyi_splash_ipc',
      ]);
    });

    test('does not mutate the parent map', () {
      final parent = Map<String, String>.of(inherited);
      sanitizeBackendEnvironment(parent);
      expect(parent, inherited);
    });

    test('the launcher starts backend.exe with the sanitized environment and logs names only', () async {
      final h = _Harness(upAfterProbes: 2)..parentEnv = inherited;
      await h.build().ensureRunning();
      final env = h.envs.single;
      expect(env.containsKey('_PYI_ARCHIVE_FILE'), isFalse);
      expect(env['PYINSTALLER_RESET_ENVIRONMENT'], '1');
      expect(env['PATH'], r'C:\Windows\System32');
      final line = h.log.lines.firstWhere((l) => l.contains('start env:'));
      expect(line, contains('_PYI_APPLICATION_HOME_DIR'));
      expect(line, isNot(contains('_MEI1234')), reason: 'values are never logged');
      expect(line, isNot(contains('Program Files')));
    });

    test('a clean environment logs "removed none"', () async {
      final h = _Harness(upAfterProbes: 2);
      await h.build().ensureRunning();
      expect(h.log.any('removed none'), isTrue);
    });
  });

  group('FileLauncherLog', () {
    late Directory tmp;
    final logs = <FileLauncherLog>[];
    setUp(() => tmp = Directory.systemTemp.createTempSync('launcher_log_test'));
    tearDown(() {
      for (final log in logs) {
        log.close(); // Windows can't delete open files
      }
      logs.clear();
      tmp.deleteSync(recursive: true);
    });

    FileLauncherLog open(String path, {int maxBytes = 200 * 1024, DateTime Function()? now}) {
      final log = FileLauncherLog(path, maxBytes: maxBytes, now: now);
      logs.add(log);
      return log;
    }

    test('creates missing folders and appends timestamped lines', () {
      final path = p.join(tmp.path, 'a', 'b', 'launcher.log');
      final log = open(path, now: () => DateTime(2026, 9, 25, 10, 30));
      log.write('hello');
      log.write('world');
      log.flush();
      final text = File(path).readAsStringSync();
      expect(text, contains('2026-09-25T10:30:00.000 [pid $pid] hello'));
      expect(text.trim().split('\n'), hasLength(2));
    });

    test('keeps appending to an existing file across instances', () {
      final path = p.join(tmp.path, 'launcher.log');
      open(path)
        ..write('first')
        ..close();
      open(path).write('second');
      logs.last.close();
      expect(File(path).readAsStringSync(), allOf(contains('first'), contains('second')));
    });

    test('rotates once to .1 past maxBytes (size tracked in memory) and keeps only one backup', () {
      final path = p.join(tmp.path, 'launcher.log');
      final log = open(path, maxBytes: 1000);
      for (var i = 0; i < 200; i++) {
        log.write('line $i ${'x' * 40}');
      }
      log.close();
      expect(File('$path.1').existsSync(), isTrue);
      expect(File('$path.2').existsSync(), isFalse);
      expect(File(path).lengthSync(), lessThan(1200));
      expect(File(path).readAsStringSync(), contains('line 199'));
    });

    test('an oversized existing file is rotated on the first write', () {
      final path = p.join(tmp.path, 'launcher.log');
      File(path).writeAsStringSync('y' * 2000);
      open(path, maxBytes: 1000).write('fresh');
      logs.last.close();
      expect(File('$path.1').lengthSync(), 2000);
      expect(File(path).readAsStringSync(), contains('fresh'));
    });

    test('never throws on an unwritable path', () {
      final log = open(p.join(tmp.path, 'bad\u0000name'));
      expect(() => log.write('x'), returnsNormally);
      expect(log.flush, returnsNormally);
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

  test('main.dart builds the backend path with an escaped backslash', () {
    // A single backslash before "backend.exe" is a backspace (\b) escape in Dart.
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains(r"'$exeDir\\backend.exe'"));
    expect(src, isNot(contains(r"'$exeDir\backend.exe'")));
  });

  test('isLoopbackServerUrl', () {
    expect(isLoopbackServerUrl('http://127.0.0.1:8000'), isTrue);
    expect(isLoopbackServerUrl('http://localhost:8000'), isTrue);
    expect(isLoopbackServerUrl('http://192.168.1.20:8000'), isFalse);
  });

  group('self-heal after ready', () {
    test('recoverBackendOnConnectionError re-runs the launcher on connection errors only', () async {
      final h = _Harness(upAfterProbes: 1);
      final launcher = h.build();
      recoverBackendOnConnectionError(launcher, _dioError(DioExceptionType.connectionError));
      expect(h.probes, 0, reason: 'not ready yet: the startup flow owns it');

      await launcher.ensureRunning();
      recoverBackendOnConnectionError(launcher, _dioError(DioExceptionType.badResponse));
      await Future<void>.delayed(Duration.zero);
      expect(h.probes, 1);

      recoverBackendOnConnectionError(launcher, _dioError(DioExceptionType.connectionTimeout));
      await Future<void>.delayed(Duration.zero);
      expect(h.probes, 2);
      expect(h.log.any('connection error after ready (connectionTimeout)'), isTrue);
    });

    test('BackendRecoveryInterceptor on a Dio client heals and still surfaces the error', () async {
      final h = _Harness(upAfterProbes: 1);
      final launcher = h.build();
      await launcher.ensureRunning();

      final dio = Dio()
        ..httpClientAdapter = _ConnectionRefusedAdapter()
        ..interceptors.add(BackendRecoveryInterceptor(() => launcher));
      await expectLater(
        dio.get<void>('http://127.0.0.1:28080/api/v1/x'),
        throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.connectionError)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(h.probes, 2);
    });

    test('BackendRecoveryInterceptor asserts (debug) when the launcher cannot be read', () {
      final interceptor = BackendRecoveryInterceptor(() => throw StateError('no override'));
      expect(
        () => interceptor.onError(_dioError(DioExceptionType.connectionError), ErrorInterceptorHandler()),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('BackendStartupNotifier', () {
    test('is the single owner: first read starts one attempt; retry after failure restarts a stuck backend', () async {
      final h = _Harness(upAfterProbes: null, processes: [(42, _exe)]);
      final launcher = h.build();
      final container = ProviderContainer(
        overrides: [backendLauncherProvider.overrideWithValue(launcher)],
      );
      addTearDown(container.dispose);

      container.read(backendStartupProvider);
      await pumpEventQueue();
      expect(container.read(backendStartupProvider).isFailed, isTrue);
      expect(h.log.lines.where((l) => l.contains('attempt start')), hasLength(1));

      await container.read(backendStartupProvider.notifier).retry();
      expect(h.killed, [42], reason: 'Retry after a failure restarts a stuck backend');
      expect(h.started, [_exe]);
    });
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
      final first = Completer<BackendHealth>();
      var n = 0;
      final h = _Harness(
        healthCheck: () => ++n == 1 ? first.future : Future.value(const BackendHealth.up()),
      );
      await tester.pumpWidget(app(h.build()));
      await tester.pump();
      expect(find.text('Starting the system…'), findsOneWidget);
      expect(find.text('AUTH-GATE'), findsNothing);

      first.complete(const BackendHealth.up());
      await tester.pump();
      await tester.pump();
      expect(find.text('AUTH-GATE'), findsOneWidget);
    });

    testWidgets('timeout shows localized error and Retry recovers (ar)', (tester) async {
      var up = false;
      final h = _Harness(
        healthCheck: () async => up ? const BackendHealth.up() : const BackendHealth.down(),
      );
      await tester.pumpWidget(app(h.build(), locale: const Locale('ar')));
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
      final h = _Harness(healthCheck: () async => const BackendHealth.foreign());
      await tester.pumpWidget(app(h.build()));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Another program is using port'), findsOneWidget);
    });

    testWidgets('recovery after ready overlays the app without unmounting it', (tester) async {
      var up = true;
      final h = _Harness(
        healthCheck: () async => up ? const BackendHealth.up() : const BackendHealth.down(),
      );
      final launcher = h.build(exe: null);
      await tester.pumpWidget(app(launcher, child: const _Counter()));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('inc')));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);

      up = false;
      recoverBackendOnConnectionError(launcher, _dioError(DioExceptionType.connectionError));
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
