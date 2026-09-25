import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_process_control.dart' as native;
import 'launcher_log.dart';

/// Value of `system` in the backend's `/health` body. Anything else answering
/// on the port is a foreign program, not our backend.
const String kBackendSystemName = 'Sorour Logistics ERP';

enum BackendHealthState {
  /// Our backend answered (maintenance mode included).
  up,

  /// Nothing answered (connection refused / timeout / 5xx without our marker).
  down,

  /// Something answered on the port, but it isn't our backend.
  foreign,
}

/// Result of one `/health` probe. [statusCode] / [error] are for the log only.
@immutable
class BackendHealth {
  final BackendHealthState state;
  final bool maintenanceMode;
  final int? statusCode;
  final String? error;

  const BackendHealth.up({this.maintenanceMode = false, this.statusCode})
      : state = BackendHealthState.up,
        error = null;
  const BackendHealth.down({this.statusCode, this.error})
      : state = BackendHealthState.down,
        maintenanceMode = false;
  const BackendHealth.foreign({this.statusCode})
      : state = BackendHealthState.foreign,
        maintenanceMode = false,
        error = null;

  bool get isUp => state == BackendHealthState.up;
  bool get isForeign => state == BackendHealthState.foreign;

  /// Interprets a `/health` HTTP response ([statusCode] null = no response).
  ///
  /// Ours only when the body says `system == kBackendSystemName`; then 200 is
  /// up and a 503 carrying `maintenance_mode: true` is also up (the backend runs,
  /// it only rejects writes). A non-5xx reply without our marker is foreign.
  factory BackendHealth.fromResponse(int? statusCode, Object? data) {
    if (statusCode == null) return const BackendHealth.down(error: 'no response');
    final isOurs = data is Map && data['system'] == kBackendSystemName;
    if (!isOurs) {
      // A 5xx without our marker is inconclusive (ours erroring, or a proxy):
      // keep polling; only a clean non-5xx reply proves a foreign program.
      if (statusCode >= 500) return BackendHealth.down(statusCode: statusCode);
      return BackendHealth.foreign(statusCode: statusCode);
    }
    final maintenance = data['maintenance_mode'] == true;
    if (statusCode == 200) {
      return BackendHealth.up(maintenanceMode: maintenance, statusCode: 200);
    }
    if (statusCode == 503 && maintenance) {
      return const BackendHealth.up(maintenanceMode: true, statusCode: 503);
    }
    return BackendHealth.down(statusCode: statusCode);
  }

  /// One-line description for the launcher log.
  String describe() {
    final code = statusCode == null ? '' : ' $statusCode';
    switch (state) {
      case BackendHealthState.up:
        return 'up$code maintenance=$maintenanceMode';
      case BackendHealthState.foreign:
        return 'foreign$code';
      case BackendHealthState.down:
        return 'down$code${error == null ? '' : ' ($error)'}';
    }
  }
}

/// A running process: id + full image path.
typedef BackendProcessInfo = (int pid, String path);

/// Probes `/health` once. Should not throw (a throw counts as down).
typedef BackendHealthChecker = Future<BackendHealth> Function();

/// Starts the backend executable detached (no console, not tied to this
/// process) in [workingDirectory]; returns its pid when known. Throws on failure.
typedef BackendProcessStarter = Future<int?> Function(
    String executablePath, String workingDirectory);

/// Lists running processes with their full image paths.
typedef BackendProcessLister = Future<List<BackendProcessInfo>> Function();

/// Terminates a process by id; true on success.
typedef BackendProcessKiller = Future<bool> Function(int pid);

/// Time source + delays, injectable so tests don't wait for real.
abstract class LauncherClock {
  DateTime now();
  Future<void> delay(Duration duration);
}

class SystemLauncherClock implements LauncherClock {
  const SystemLauncherClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Future<void> delay(Duration duration) => Future<void>.delayed(duration);
}

/// Normalises a Windows path for comparison: `\\?\` prefix, slashes, case.
String normalizeWindowsPath(String path) {
  var p = path.trim().replaceAll('/', r'\');
  if (p.startsWith(r'\\?\')) p = p.substring(4);
  while (p.contains(r'\\')) {
    p = p.replaceAll(r'\\', r'\');
  }
  if (p.endsWith(r'\')) p = p.substring(0, p.length - 1);
  return p.toLowerCase();
}

/// True when [processPath] is exactly [executablePath] (Windows semantics).
bool isSameExecutablePath(String processPath, String executablePath) =>
    normalizeWindowsPath(processPath) == normalizeWindowsPath(executablePath);

/// Processes in [processes] whose image is exactly [executablePath].
/// PyInstaller onefile runs two (bootloader + child), both with this path.
List<BackendProcessInfo> matchBackendProcesses(
  Iterable<BackendProcessInfo> processes,
  String executablePath,
) =>
    processes.where((p) => isSameExecutablePath(p.$2, executablePath)).toList();

/// Directory part of a Windows (or POSIX) path.
String parentDirectoryOf(String path) {
  final i = path.lastIndexOf(RegExp(r'[\\/]'));
  return i <= 0 ? path : path.substring(0, i);
}

enum BackendLaunchPhase {
  /// First `/health` probe in progress.
  checking,

  /// Backend is down: it was started (or is starting) and we are polling.
  starting,

  /// `/health` answered (maintenance mode included).
  ready,

  /// Gave up; see [BackendLaunchStatus.failure].
  failed,
}

enum BackendLaunchFailure {
  /// The deadline passed without a healthy answer.
  timeout,

  /// Another program answers on the backend port.
  portInUse,
}

@immutable
class BackendLaunchStatus {
  final BackendLaunchPhase phase;

  /// True when this launcher spawned backend.exe during the current attempt.
  final bool startedProcess;
  final bool maintenanceMode;
  final BackendLaunchFailure? failure;

  const BackendLaunchStatus({
    required this.phase,
    this.startedProcess = false,
    this.maintenanceMode = false,
    this.failure,
  });

  static const BackendLaunchStatus initialChecking =
      BackendLaunchStatus(phase: BackendLaunchPhase.checking);
  static const BackendLaunchStatus alreadyReady =
      BackendLaunchStatus(phase: BackendLaunchPhase.ready);

  bool get isReady => phase == BackendLaunchPhase.ready;
  bool get isFailed => phase == BackendLaunchPhase.failed;
}

/// Makes sure the local backend is running before the app talks to it.
///
/// Flow: probe `/health`; if it's down and [backendExecutablePath] exists and no
/// process runs from exactly that path, start it; then poll `/health` every
/// [pollInterval] until our backend answers or the deadline passes. While
/// polling, a backend.exe we started that has already exited (crash / lost the
/// single-instance mutex) is started again, at most [maxStartsPerAttempt] times.
/// Concurrent calls to [ensureRunning] share one attempt, so backend.exe is never
/// started twice at once. `ensureRunning(restartIfStuck: true)` (the user's Retry
/// after a failure) terminates our backend.exe if it is alive but not answering,
/// then starts it again. Every decision goes to [log].
class BackendLauncher {
  BackendLauncher({
    required BackendHealthChecker healthCheck,
    BackendProcessStarter? startProcess,
    BackendProcessLister? listProcesses,
    BackendProcessKiller? killProcess,
    this.backendExecutablePath,
    bool Function(String path)? fileExists,
    LauncherClock clock = const SystemLauncherClock(),
    LauncherLog log = const NullLauncherLog(),
    this.startupDeadline = const Duration(seconds: 90),
    this.connectOnlyDeadline = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 500),
    this.killSettleDelay = const Duration(milliseconds: 800),
    this.aliveCheckInterval = const Duration(seconds: 5),
    this.maxStartsPerAttempt = 3,
  })  : _healthCheck = healthCheck,
        _startProcess = startProcess,
        _listProcesses = listProcesses,
        _killProcess = killProcess,
        _fileExists = fileExists ?? ((p) => File(p).existsSync()),
        _clock = clock,
        _log = log,
        _disabled = false,
        status = ValueNotifier(BackendLaunchStatus.initialChecking);

  /// A launcher that never starts anything and is ready immediately
  /// (web, non-Windows, tests).
  BackendLauncher.disabled()
      : _healthCheck = (() async => const BackendHealth.up()),
        _startProcess = null,
        _listProcesses = null,
        _killProcess = null,
        _fileExists = ((_) => false),
        _clock = const SystemLauncherClock(),
        _log = const NullLauncherLog(),
        backendExecutablePath = null,
        startupDeadline = Duration.zero,
        connectOnlyDeadline = Duration.zero,
        pollInterval = Duration.zero,
        killSettleDelay = Duration.zero,
        aliveCheckInterval = Duration.zero,
        maxStartsPerAttempt = 0,
        _disabled = true,
        status = ValueNotifier(BackendLaunchStatus.alreadyReady);

  final BackendHealthChecker _healthCheck;
  final BackendProcessStarter? _startProcess;
  final BackendProcessLister? _listProcesses;
  final BackendProcessKiller? _killProcess;
  final bool Function(String path) _fileExists;
  final LauncherClock _clock;
  final LauncherLog _log;
  final bool _disabled;

  /// Local backend.exe to start, or null when this client must not start one
  /// (no bundled backend, or the server URL points to another machine).
  final String? backendExecutablePath;

  /// How long to wait for a local backend (the first start after an update
  /// unpacks, backs up and migrates, so this is generous).
  final Duration startupDeadline;

  /// How long to wait when nothing can be started here (remote/dev backend).
  final Duration connectOnlyDeadline;
  final Duration pollInterval;

  /// Pause after terminating a stuck backend so it releases the port/mutex.
  final Duration killSettleDelay;

  /// How often, while polling, to check that a backend we started is alive.
  final Duration aliveCheckInterval;

  /// Upper bound of starts (first start + early-exit restarts) per attempt.
  final int maxStartsPerAttempt;

  final ValueNotifier<BackendLaunchStatus> status;

  Future<BackendLaunchStatus>? _inFlight;
  DateTime? _lastStartAt;
  int _startCount = 0;
  int _killCount = 0;
  int _attempt = 0;

  /// Number of times backend.exe was started by this launcher.
  int get startCount => _startCount;

  /// Number of stuck backend processes terminated by this launcher.
  int get killCount => _killCount;

  Future<BackendLaunchStatus> ensureRunning({bool restartIfStuck = false}) {
    if (_disabled) return Future.value(status.value);
    return _inFlight ??=
        _run(restartIfStuck: restartIfStuck).whenComplete(() => _inFlight = null);
  }

  void _emit(BackendLaunchStatus next) => status.value = next;

  void _w(String message) {
    try {
      _log.write('[launcher#$_attempt] $message');
    } catch (_) {}
  }

  Future<BackendLaunchStatus> _run({required bool restartIfStuck}) async {
    _attempt++;
    final t0 = _clock.now();
    final exe = backendExecutablePath;
    final exists = exe != null && _fileExists(exe);
    final canStart = _canStartLocally();
    _w('attempt start restartIfStuck=$restartIfStuck '
        'backendExecutablePath=${exe ?? '<none: remote server or not resolved>'} '
        'fileExists=$exists canStartLocally=$canStart '
        'deadline=${(canStart ? startupDeadline : connectOnlyDeadline).inSeconds}s');
    if (!status.value.isReady) _emit(BackendLaunchStatus.initialChecking);

    var probeNo = 0;
    Future<BackendHealth> probe() async {
      final h = await _probe();
      probeNo++;
      _w('probe $probeNo: ${h.describe()}');
      return h;
    }

    final first = await probe();
    if (first.isUp) return _ready(first, startedProcess: false, t0: t0);
    if (first.isForeign) {
      return _fail(BackendLaunchFailure.portInUse, startedProcess: false, t0: t0);
    }

    var starts = 0;
    var started = false;
    if (await _startIfNeeded(restartIfStuck: restartIfStuck)) {
      started = true;
      starts = 1;
    }
    _emit(BackendLaunchStatus(
      phase: BackendLaunchPhase.starting,
      startedProcess: started,
    ));

    final deadline = t0.add(canStart ? startupDeadline : connectOnlyDeadline);
    var nextAliveCheck = _clock.now().add(aliveCheckInterval);
    while (true) {
      await _clock.delay(pollInterval);
      final health = await probe();
      if (health.isUp) return _ready(health, startedProcess: started, t0: t0);
      if (health.isForeign) {
        return _fail(BackendLaunchFailure.portInUse, startedProcess: started, t0: t0);
      }
      if (!_clock.now().isBefore(deadline)) {
        return _fail(BackendLaunchFailure.timeout, startedProcess: started, t0: t0);
      }
      if (started && !_clock.now().isBefore(nextAliveCheck)) {
        nextAliveCheck = _clock.now().add(aliveCheckInterval);
        final ours = await _ourProcesses();
        if (ours != null && ours.isEmpty) {
          if (starts < maxStartsPerAttempt) {
            _w('started backend.exe is no longer running (exited early); '
                'restarting ($starts/$maxStartsPerAttempt starts used)');
            if (await _start()) starts++;
          } else if (starts == maxStartsPerAttempt) {
            _w('started backend.exe exited again; start limit '
                '$maxStartsPerAttempt reached, waiting for the deadline');
            starts++; // log once
          }
        }
      }
    }
  }

  BackendLaunchStatus _ready(BackendHealth health,
      {required bool startedProcess, required DateTime t0}) {
    final ready = BackendLaunchStatus(
      phase: BackendLaunchPhase.ready,
      startedProcess: startedProcess,
      maintenanceMode: health.maintenanceMode,
    );
    _w('READY after ${_clock.now().difference(t0).inMilliseconds} ms '
        'startedProcess=$startedProcess maintenance=${health.maintenanceMode}');
    _emit(ready);
    return ready;
  }

  BackendLaunchStatus _fail(BackendLaunchFailure failure,
      {required bool startedProcess, required DateTime t0}) {
    final failed = BackendLaunchStatus(
      phase: BackendLaunchPhase.failed,
      startedProcess: startedProcess,
      failure: failure,
    );
    _w('FAILED reason=${failure.name} after '
        '${_clock.now().difference(t0).inMilliseconds} ms startedProcess=$startedProcess');
    _emit(failed);
    return failed;
  }

  Future<BackendHealth> _probe() async {
    try {
      return await _healthCheck();
    } catch (e) {
      return BackendHealth.down(error: 'health check threw: $e');
    }
  }

  bool _canStartLocally() {
    final path = backendExecutablePath;
    return path != null && _startProcess != null && _fileExists(path);
  }

  /// Our backend.exe processes (matched by full path), or null if the process
  /// list can't be read.
  Future<List<BackendProcessInfo>?> _ourProcesses() async {
    final lister = _listProcesses;
    if (lister == null) {
      _w('process list: not available on this platform');
      return null;
    }
    try {
      final all = await lister();
      final ours = matchBackendProcesses(all, backendExecutablePath!);
      _w('process list: ${all.length} processes, matched '
          '${ours.isEmpty ? 'none' : ours.map((p) => '${p.$1} ${p.$2}').join('; ')}');
      return ours;
    } catch (e) {
      _w('process list ERROR: $e');
      return null;
    }
  }

  /// Starts backend.exe unless it can't be started here or our backend.exe is
  /// already alive (slow first start). With [restartIfStuck], an alive but
  /// unhealthy backend.exe is terminated first and a fresh one is started.
  Future<bool> _startIfNeeded({required bool restartIfStuck}) async {
    if (!_canStartLocally()) {
      _w('not starting: canStartLocally=false (waiting for an external backend)');
      return false;
    }

    final ours = await _ourProcesses();
    if (ours == null) {
      // Process list unavailable: fall back to "not twice within the window".
      final last = _lastStartAt;
      if (last != null && _clock.now().difference(last) < startupDeadline) {
        _w('not starting: no process list and the last start was '
            '${_clock.now().difference(last).inSeconds}s ago');
        return false;
      }
    } else if (ours.isNotEmpty) {
      if (!restartIfStuck || _killProcess == null) {
        _w('not starting: our backend.exe is already running, waiting for it');
        return false;
      }
      for (final p in ours) {
        try {
          final ok = await _killProcess(p.$1);
          if (ok) _killCount++;
          _w('kill pid=${p.$1} path=${p.$2} ok=$ok');
        } catch (e) {
          _w('kill pid=${p.$1} path=${p.$2} ERROR: $e');
        }
      }
      await _clock.delay(killSettleDelay);
    }
    return _start();
  }

  Future<bool> _start() async {
    final exe = backendExecutablePath!;
    final wd = parentDirectoryOf(exe);
    _w('start: path=$exe workingDirectory=$wd');
    try {
      _lastStartAt = _clock.now();
      final pid = await _startProcess!(exe, wd);
      _startCount++;
      _w('start OK pid=${pid ?? 'unknown'}');
      return true;
    } catch (e) {
      _w('start FAILED: ${e.runtimeType}: $e');
      return false;
    }
  }
}

/// Default Windows helpers (not used on web).
class WindowsBackendProcess {
  WindowsBackendProcess._();

  /// `ProcessStartMode.detached`: the child gets no stdio handles and no console
  /// (Dart passes DETACHED_PROCESS), and outlives this process (its own watchdog
  /// handles shutdown). Not `detachedWithStdio`: nobody would drain those pipes,
  /// so a chatty backend could block on a full stdout pipe. Throws on failure
  /// (the launcher logs it).
  static Future<int?> start(String executablePath, String workingDirectory) async {
    final process = await Process.start(
      executablePath,
      const <String>[],
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
    );
    return process.pid;
  }

  /// Win32 process snapshot (no tasklist child process, so no console flash).
  static Future<List<BackendProcessInfo>> list() async => native.listProcessImagePaths();

  static Future<bool> kill(int pid) async => native.terminateProcessById(pid);
}

/// True when [serverUrl] points to this machine, so a local backend.exe serves it.
bool isLoopbackServerUrl(String serverUrl) {
  final host = Uri.tryParse(serverUrl)?.host.toLowerCase() ?? '';
  return host == 'localhost' || host == '127.0.0.1' || host == '::1' || host == '[::1]';
}

/// Overridden in main.dart on Windows desktop; disabled (ready) elsewhere.
final backendLauncherProvider = Provider<BackendLauncher>((ref) {
  return BackendLauncher.disabled();
});

/// Self-heal hook for the shared Dio clients: a connection-level failure after
/// the backend was ready (e.g. it died or its watchdog stopped it) re-runs the
/// launcher. Concurrent failures share one attempt.
void recoverBackendOnConnectionError(BackendLauncher launcher, DioException error) {
  const connectionTypes = {
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
  };
  if (!connectionTypes.contains(error.type)) return;
  if (!launcher.status.value.isReady) return; // startup / failed UI already owns it
  launcher._w('connection error after ready (${error.type.name}); re-checking backend');
  unawaited(launcher.ensureRunning());
}

class BackendStartupNotifier extends StateNotifier<BackendLaunchStatus> {
  BackendStartupNotifier(this._launcher) : super(_launcher.status.value) {
    _launcher.status.addListener(_sync);
    _launcher.ensureRunning();
  }

  final BackendLauncher _launcher;

  void _sync() {
    if (mounted) state = _launcher.status.value;
  }

  /// User-initiated retry: a stuck (alive but unhealthy) backend is restarted.
  Future<void> retry() => _launcher.ensureRunning(restartIfStuck: state.isFailed);

  @override
  void dispose() {
    _launcher.status.removeListener(_sync);
    super.dispose();
  }
}

final backendStartupProvider =
    StateNotifierProvider<BackendStartupNotifier, BackendLaunchStatus>((ref) {
  return BackendStartupNotifier(ref.watch(backendLauncherProvider));
});
