import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/backend_launcher.dart';
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
  }) : processes = processes ?? [];

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
        startProcess: (path) async => started.add(path),
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
        startProcess: (p) async => started.add(p),
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
        startProcess: (_) async {},
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
      // The started process never showed up in the process list (it died).
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
        startProcess: (p) async => started.add(p),
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
        startProcess: (_) async {},
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
        startProcess: (_) async {},
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
