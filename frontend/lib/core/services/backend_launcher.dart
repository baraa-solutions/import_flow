import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_process_control.dart' as native;

/// Value of `system` in the backend's `/health` body. Anything else answering
/// on the port is a foreign program, not our backend.
const String kBackendSystemName = 'Sorour Logistics ERP';

enum BackendHealthState {
  /// Our backend answered (maintenance mode included).
  up,

  /// Nothing answered (connection refused / timeout / 5xx without body).
  down,

  /// Something answered on the port, but it isn't our backend.
  foreign,
}

/// Result of one `/health` probe.
@immutable
class BackendHealth {
  final BackendHealthState state;
  final bool maintenanceMode;

  const BackendHealth.up({this.maintenanceMode = false}) : state = BackendHealthState.up;
  const BackendHealth.down()
      : state = BackendHealthState.down,
        maintenanceMode = false;
  const BackendHealth.foreign()
      : state = BackendHealthState.foreign,
        maintenanceMode = false;

  bool get isUp => state == BackendHealthState.up;
  bool get isForeign => state == BackendHealthState.foreign;

  /// Interprets a `/health` HTTP response ([statusCode] null = no response).
  ///
  /// Ours only when the body says `system == kBackendSystemName`; then 200 is
  /// up and a 503 carrying `maintenance_mode: true` is also up (the backend runs,
  /// it only rejects writes). A non-5xx reply without our marker is foreign.
  factory BackendHealth.fromResponse(int? statusCode, Object? data) {
    if (statusCode == null) return const BackendHealth.down();
    final isOurs = data is Map && data['system'] == kBackendSystemName;
    if (!isOurs) {
      // A 5xx without our marker is inconclusive (ours erroring, or a proxy):
      // keep polling; only a clean non-5xx reply proves a foreign program.
      if (statusCode >= 500) return const BackendHealth.down();
      return const BackendHealth.foreign();
    }
    final maintenance = data['maintenance_mode'] == true;
    if (statusCode == 200) return BackendHealth.up(maintenanceMode: maintenance);
    if (statusCode == 503 && maintenance) {
      return const BackendHealth.up(maintenanceMode: true);
    }
    return const BackendHealth.down();
  }
}

/// A running process: id + full image path.
typedef BackendProcessInfo = (int pid, String path);

/// Probes `/health` once. Should not throw (a throw counts as down).
typedef BackendHealthChecker = Future<BackendHealth> Function();

/// Starts the backend executable detached (no console, not tied to this process).
typedef BackendProcessStarter = Future<void> Function(String executablePath);

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
/// [pollInterval] until our backend answers or the deadline passes. Concurrent
/// calls to [ensureRunning] share one attempt, so backend.exe is never started
/// twice. `ensureRunning(restartIfStuck: true)` (the user's Retry after a failure)
/// terminates our backend.exe if it is alive but not answering, then starts it again.
class BackendLauncher {
  BackendLauncher({
    required BackendHealthChecker healthCheck,
    BackendProcessStarter? startProcess,
    BackendProcessLister? listProcesses,
    BackendProcessKiller? killProcess,
    this.backendExecutablePath,
    bool Function(String path)? fileExists,
    LauncherClock clock = const SystemLauncherClock(),
    this.startupDeadline = const Duration(seconds: 90),
    this.connectOnlyDeadline = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 500),
    this.killSettleDelay = const Duration(milliseconds: 800),
  })  : _healthCheck = healthCheck,
        _startProcess = startProcess,
        _listProcesses = listProcesses,
        _killProcess = killProcess,
        _fileExists = fileExists ?? ((p) => File(p).existsSync()),
        _clock = clock,
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
        backendExecutablePath = null,
        startupDeadline = Duration.zero,
        connectOnlyDeadline = Duration.zero,
        pollInterval = Duration.zero,
        killSettleDelay = Duration.zero,
        _disabled = true,
        status = ValueNotifier(BackendLaunchStatus.alreadyReady);

  final BackendHealthChecker _healthCheck;
  final BackendProcessStarter? _startProcess;
  final BackendProcessLister? _listProcesses;
  final BackendProcessKiller? _killProcess;
  final bool Function(String path) _fileExists;
  final LauncherClock _clock;
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

  final ValueNotifier<BackendLaunchStatus> status;

  Future<BackendLaunchStatus>? _inFlight;
  DateTime? _lastStartAt;
  int _startCount = 0;
  int _killCount = 0;

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

  Future<BackendLaunchStatus> _run({required bool restartIfStuck}) async {
    if (!status.value.isReady) _emit(BackendLaunchStatus.initialChecking);

    final first = await _probe();
    if (first.isUp) return _ready(first, startedProcess: false);
    if (first.isForeign) return _fail(BackendLaunchFailure.portInUse, startedProcess: false);

    final started = await _startIfNeeded(restartIfStuck: restartIfStuck);
    _emit(BackendLaunchStatus(
      phase: BackendLaunchPhase.starting,
      startedProcess: started,
    ));

    final deadline =
        _clock.now().add(_canStartLocally() ? startupDeadline : connectOnlyDeadline);
    while (true) {
      await _clock.delay(pollInterval);
      final health = await _probe();
      if (health.isUp) return _ready(health, startedProcess: started);
      if (health.isForeign) {
        return _fail(BackendLaunchFailure.portInUse, startedProcess: started);
      }
      if (!_clock.now().isBefore(deadline)) {
        return _fail(BackendLaunchFailure.timeout, startedProcess: started);
      }
    }
  }

  BackendLaunchStatus _ready(BackendHealth health, {required bool startedProcess}) {
    final ready = BackendLaunchStatus(
      phase: BackendLaunchPhase.ready,
      startedProcess: startedProcess,
      maintenanceMode: health.maintenanceMode,
    );
    _emit(ready);
    return ready;
  }

  BackendLaunchStatus _fail(BackendLaunchFailure failure, {required bool startedProcess}) {
    final failed = BackendLaunchStatus(
      phase: BackendLaunchPhase.failed,
      startedProcess: startedProcess,
      failure: failure,
    );
    _emit(failed);
    return failed;
  }

  Future<BackendHealth> _probe() async {
    try {
      return await _healthCheck();
    } catch (_) {
      return const BackendHealth.down();
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
    if (lister == null) return null;
    try {
      return matchBackendProcesses(await lister(), backendExecutablePath!);
    } catch (_) {
      return null;
    }
  }

  /// Starts backend.exe unless it can't be started here or our backend.exe is
  /// already alive (slow first start). With [restartIfStuck], an alive but
  /// unhealthy backend.exe is terminated first and a fresh one is started.
  Future<bool> _startIfNeeded({required bool restartIfStuck}) async {
    if (!_canStartLocally()) return false;

    final ours = await _ourProcesses();
    if (ours == null) {
      // Process list unavailable: fall back to "not twice within the window".
      final last = _lastStartAt;
      if (last != null && _clock.now().difference(last) < startupDeadline) {
        return false;
      }
    } else if (ours.isNotEmpty) {
      if (!restartIfStuck || _killProcess == null) return false; // let it finish
      for (final p in ours) {
        try {
          if (await _killProcess(p.$1)) _killCount++;
        } catch (_) {}
      }
      await _clock.delay(killSettleDelay);
    }

    try {
      _lastStartAt = _clock.now();
      await _startProcess!(backendExecutablePath!);
      _startCount++;
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Default Windows helpers (not used on web).
class WindowsBackendProcess {
  WindowsBackendProcess._();

  /// Detached start: DETACHED_PROCESS, so no console window is created and the
  /// backend outlives a crash of this process (its own watchdog handles that).
  static Future<void> start(String executablePath) async {
    await Process.start(
      executablePath,
      const <String>[],
      workingDirectory: File(executablePath).parent.path,
      mode: ProcessStartMode.detached,
    );
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
