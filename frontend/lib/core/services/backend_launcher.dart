import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

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
/// process) in [workingDirectory] with exactly [environment] (no inherited
/// variables); returns its pid when known. Throws on failure.
typedef BackendProcessStarter = Future<int?> Function(
    String executablePath, String workingDirectory, Map<String, String> environment);

/// Lists running processes named [imageName] (e.g. `backend.exe`) with their
/// full image paths.
typedef BackendProcessLister = Future<List<BackendProcessInfo>> Function(String imageName);

/// Terminates a process by id; true on success.
typedef BackendProcessKiller = Future<bool> Function(int pid);

/// Environment for a fresh PyInstaller onefile backend.exe.
@immutable
class BackendEnvironment {
  const BackendEnvironment(this.environment, this.removedKeys);

  final Map<String, String> environment;

  /// Names (never values) of the dropped variables, for the log.
  final List<String> removedKeys;
}

/// Copies [parent] without the PyInstaller bootloader state (`_PYI_*`,
/// `_MEIPASS*`, case-insensitive) and sets `PYINSTALLER_RESET_ENVIRONMENT=1`.
///
/// Why: after an in-app update Setup relaunches frontend.exe with the OLD
/// backend's environment; if the new backend.exe inherits `_PYI_*` it reuses the
/// old `_MEI` folder and runs the old bundled code (old Alembic files).
BackendEnvironment sanitizeBackendEnvironment(Map<String, String> parent) {
  const resetKey = 'PYINSTALLER_RESET_ENVIRONMENT';
  final env = <String, String>{};
  final removed = <String>[];
  for (final entry in parent.entries) {
    final upper = entry.key.toUpperCase();
    if (upper == resetKey) continue; // always overwritten below
    if (upper.startsWith('_PYI_') || upper.startsWith('_MEIPASS')) {
      removed.add(entry.key);
      continue;
    }
    env[entry.key] = entry.value;
  }
  env[resetKey] = '1';
  removed.sort();
  return BackendEnvironment(env, removed);
}

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
  var s = path.trim().replaceAll('/', r'\');
  if (s.startsWith(r'\\?\')) s = s.substring(4);
  while (s.contains(r'\\')) {
    s = s.replaceAll(r'\\', r'\');
  }
  if (s.endsWith(r'\')) s = s.substring(0, s.length - 1);
  return s.toLowerCase();
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

enum BackendLaunchPhase {
  /// Probing `/health`, starting backend.exe and waiting for it.
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
  final BackendLaunchFailure? failure;

  const BackendLaunchStatus._(this.phase, [this.failure]);

  static const BackendLaunchStatus starting = BackendLaunchStatus._(BackendLaunchPhase.starting);
  static const BackendLaunchStatus ready = BackendLaunchStatus._(BackendLaunchPhase.ready);
  const BackendLaunchStatus.failed(BackendLaunchFailure reason)
      : this._(BackendLaunchPhase.failed, reason);

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
    Map<String, String> Function()? parentEnvironment,
  })  : _healthCheck = healthCheck,
        _parentEnvironment = parentEnvironment ?? _platformEnvironment,
        _startProcess = startProcess,
        _listProcesses = listProcesses,
        _killProcess = killProcess,
        _fileExists = fileExists ?? ((path) => File(path).existsSync()),
        _clock = clock,
        _log = log,
        _disabled = false,
        status = ValueNotifier(BackendLaunchStatus.starting);

  /// A launcher that never starts anything and is ready immediately
  /// (web, non-Windows, tests).
  BackendLauncher.disabled()
      : _healthCheck = (() async => const BackendHealth.up()),
        _parentEnvironment = _platformEnvironment,
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
        status = ValueNotifier(BackendLaunchStatus.ready);

  static Map<String, String> _platformEnvironment() =>
      Map<String, String>.of(Platform.environment);

  final BackendHealthChecker _healthCheck;
  final Map<String, String> Function() _parentEnvironment;
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

  /// Number of backend processes terminated by this launcher.
  int get killCount => _killCount;

  Future<BackendLaunchStatus> ensureRunning({bool restartIfStuck = false}) {
    if (_disabled) return Future.value(status.value);
    return _inFlight ??=
        _run(restartIfStuck: restartIfStuck).whenComplete(() => _inFlight = null);
  }

  /// Terminates every running process whose image is exactly
  /// [backendExecutablePath] (never another install's backend.exe). Returns the
  /// number terminated. Used when the app window closes.
  Future<int> killOwnBackend() async {
    final killer = _killProcess;
    if (_disabled || backendExecutablePath == null || killer == null) return 0;
    final ours = await _ourProcesses() ?? const <BackendProcessInfo>[];
    var killed = 0;
    for (final proc in ours) {
      if (await _kill(killer, proc)) killed++;
    }
    _log.flush();
    return killed;
  }

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
    final canStart = exists && _startProcess != null;
    final deadline = t0.add(canStart ? startupDeadline : connectOnlyDeadline);
    _w('attempt start restartIfStuck=$restartIfStuck '
        'backendExecutablePath=${exe ?? '<none: remote server or not resolved>'} '
        'fileExists=$exists canStartLocally=$canStart '
        'deadline=${deadline.difference(t0).inSeconds}s');
    if (!status.value.isReady) status.value = BackendLaunchStatus.starting;

    var probeNo = 0;
    Future<BackendHealth> probe() async {
      final health = await _probe();
      probeNo++;
      _w('probe $probeNo: ${health.describe()}');
      return health;
    }

    var starts = 0;
    final first = await probe();
    if (first.isUp) return _ready(first, starts, t0);
    if (first.isForeign) return _fail(BackendLaunchFailure.portInUse, starts, t0);

    if (!canStart) {
      _w('not starting: canStartLocally=false (waiting for an external backend)');
    } else if (await _startIfNeeded(restartIfStuck: restartIfStuck)) {
      starts = 1;
    }

    var limitLogged = false;
    var nextAliveCheck = _clock.now().add(aliveCheckInterval);
    while (true) {
      await _clock.delay(pollInterval);
      final health = await probe();
      if (health.isUp) return _ready(health, starts, t0);
      if (health.isForeign) return _fail(BackendLaunchFailure.portInUse, starts, t0);
      if (!_clock.now().isBefore(deadline)) {
        return _fail(BackendLaunchFailure.timeout, starts, t0);
      }
      if (starts > 0 && !_clock.now().isBefore(nextAliveCheck)) {
        nextAliveCheck = _clock.now().add(aliveCheckInterval);
        final ours = await _ourProcesses();
        if (ours != null && ours.isEmpty) {
          if (starts < maxStartsPerAttempt) {
            _w('started backend.exe is no longer running (exited early); '
                'restarting ($starts/$maxStartsPerAttempt starts used)');
            if (await _start()) starts++;
          } else if (!limitLogged) {
            limitLogged = true;
            _w('started backend.exe exited again; start limit '
                '$maxStartsPerAttempt reached, waiting for the deadline');
          }
        }
      }
    }
  }

  BackendLaunchStatus _ready(BackendHealth health, int starts, DateTime t0) {
    _w('READY after ${_clock.now().difference(t0).inMilliseconds} ms '
        'starts=$starts maintenance=${health.maintenanceMode}');
    _log.flush();
    return status.value = BackendLaunchStatus.ready;
  }

  BackendLaunchStatus _fail(BackendLaunchFailure failure, int starts, DateTime t0) {
    _w('FAILED reason=${failure.name} after '
        '${_clock.now().difference(t0).inMilliseconds} ms starts=$starts');
    _log.flush();
    return status.value = BackendLaunchStatus.failed(failure);
  }

  Future<BackendHealth> _probe() async {
    try {
      return await _healthCheck();
    } catch (e) {
      return BackendHealth.down(error: 'health check threw: $e');
    }
  }

  /// Our backend.exe processes (matched by full path), or null if the process
  /// list can't be read.
  Future<List<BackendProcessInfo>?> _ourProcesses() async {
    final lister = _listProcesses;
    if (lister == null) {
      _w('process list: not available on this platform');
      return null;
    }
    final exe = backendExecutablePath!;
    final imageName = p.windows.basename(exe);
    try {
      final named = await lister(imageName);
      final ours = matchBackendProcesses(named, exe);
      _w('process list: ${named.length} $imageName processes, matched '
          '${ours.isEmpty ? 'none' : ours.map((proc) => '${proc.$1} ${proc.$2}').join('; ')}');
      return ours;
    } catch (e) {
      _w('process list ERROR: $e');
      return null;
    }
  }

  Future<bool> _kill(BackendProcessKiller killer, BackendProcessInfo proc) async {
    try {
      final ok = await killer(proc.$1);
      if (ok) _killCount++;
      _w('kill pid=${proc.$1} path=${proc.$2} ok=$ok');
      return ok;
    } catch (e) {
      _w('kill pid=${proc.$1} path=${proc.$2} ERROR: $e');
      return false;
    }
  }

  /// Starts backend.exe unless our backend.exe is already alive (slow first
  /// start). With [restartIfStuck], an alive but unhealthy backend.exe is
  /// terminated first and a fresh one is started. Caller checked it can start.
  Future<bool> _startIfNeeded({required bool restartIfStuck}) async {
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
      final killer = _killProcess;
      if (!restartIfStuck || killer == null) {
        _w('not starting: our backend.exe is already running, waiting for it');
        return false;
      }
      for (final proc in ours) {
        await _kill(killer, proc);
      }
      await _clock.delay(killSettleDelay);
    }
    return _start();
  }

  Future<bool> _start() async {
    final exe = backendExecutablePath!;
    final wd = p.windows.dirname(exe);
    _w('start: path=$exe workingDirectory=$wd');
    try {
      final env = sanitizeBackendEnvironment(_parentEnvironment());
      _w('start env: ${env.environment.length} vars, PYINSTALLER_RESET_ENVIRONMENT=1, removed '
          '${env.removedKeys.isEmpty ? 'none' : env.removedKeys.join(', ')}');
      _lastStartAt = _clock.now();
      final pid = await _startProcess!(exe, wd, env.environment);
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
  /// (the launcher logs it). [environment] is the complete environment
  /// (see [sanitizeBackendEnvironment]); nothing is inherited implicitly.
  static Future<int?> start(
    String executablePath,
    String workingDirectory,
    Map<String, String> environment,
  ) async {
    final process = await Process.start(
      executablePath,
      const <String>[],
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: false,
      mode: ProcessStartMode.detached,
    );
    return process.pid;
  }

  /// Toolhelp32 snapshot filtered by image name (no tasklist child process, so
  /// no console flash).
  static Future<List<BackendProcessInfo>> list(String imageName) async =>
      native.listProcessImagePaths(imageName);

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

/// Self-heal: a connection-level failure after the backend was ready (it died,
/// or its watchdog stopped it) re-runs the launcher. Concurrent failures share
/// one attempt.
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

/// Shared by the Dio clients: runs [recoverBackendOnConnectionError] and passes
/// the error on unchanged.
class BackendRecoveryInterceptor extends Interceptor {
  BackendRecoveryInterceptor(this._launcher);

  final BackendLauncher Function() _launcher;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    BackendLauncher? launcher;
    try {
      launcher = _launcher();
    } catch (e) {
      assert(false, 'backendLauncherProvider could not be read: $e');
    }
    if (launcher != null) recoverBackendOnConnectionError(launcher, err);
    handler.next(err);
  }
}

/// The single owner that starts the launcher (on first watch) and retries it.
class BackendStartupNotifier extends StateNotifier<BackendLaunchStatus> {
  BackendStartupNotifier(this._launcher) : super(_launcher.status.value) {
    _launcher.status.addListener(_sync);
    _launcher.ensureRunning();
  }

  final BackendLauncher _launcher;

  void _sync() {
    if (mounted) state = _launcher.status.value;
  }

  /// Re-check (and start) the backend. After a failure this is the user's
  /// Retry, so a stuck (alive but unhealthy) backend.exe is restarted.
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
