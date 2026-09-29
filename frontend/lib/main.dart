import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/api_constants.dart';
import 'core/localization/app_locales.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'core/network/dio_client.dart';
import 'core/performance/navigation_perf_tracker.dart';
import 'core/providers/workspace_tabs_provider.dart';
import 'core/services/backend_launcher.dart';
import 'core/services/launcher_log.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/density_provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/backend_startup_gate.dart';
import 'core/widgets/unsaved_changes_dialog.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/home_screen.dart';

final appReloadKeyProvider = StateProvider<int>((ref) => 0);
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pre-auth liveness probe on the public /health route (allow-listed in
/// test/no_bare_dio_test.dart). Short per-try timeouts; the launcher polls.
final Dio _healthDio = Dio(BaseOptions(
  connectTimeout: const Duration(milliseconds: 800),
  receiveTimeout: const Duration(seconds: 2),
  sendTimeout: const Duration(seconds: 2),
  validateStatus: (_) => true,
));

Future<BackendHealth> _probeBackendHealth() async {
  try {
    final res = await _healthDio.get('${ApiConstants.serverUrl}/health');
    return BackendHealth.fromResponse(res.statusCode, res.data);
  } on DioException catch (e) {
    // Type + low-level cause only (no headers; /health carries no token anyway).
    return BackendHealth.down(
        error: e.error == null ? e.type.name : '${e.type.name}: ${e.error}');
  } catch (e) {
    return BackendHealth.down(error: '$e');
  }
}

/// Windows desktop: starts `<exeDir>\backend.exe` (only for a local server URL)
/// and waits for /health. Elsewhere: a disabled launcher that is ready at once.
/// Decisions are logged to %LOCALAPPDATA%\SorourLogistics\logs\launcher.log.
BackendLauncher _createBackendLauncher() {
  if (kIsWeb || !Platform.isWindows) return BackendLauncher.disabled();
  final logPath = FileLauncherLog.defaultPath();
  final LauncherLog log =
      logPath == null ? const NullLauncherLog() : FileLauncherLog(logPath);
  String? backendPath;
  var exe = '<unknown>';
  final serverUrl = ApiConstants.serverUrl;
  final loopback = isLoopbackServerUrl(serverUrl);
  try {
    exe = Platform.resolvedExecutable;
    final exeDir = File(exe).parent.path;
    if (loopback) backendPath = '$exeDir\\backend.exe';
  } catch (e) {
    log.write('[config] could not resolve the executable: $e');
  }
  log.write('[config] frontend v${ApiConstants.clientVersion} exe=$exe '
      'serverUrl=${redactUrl(serverUrl)} loopback=$loopback '
      'backendExecutablePath=${backendPath ?? '<none>'}');
  return BackendLauncher(
    healthCheck: _probeBackendHealth,
    startProcess: WindowsBackendProcess.start,
    listProcesses: WindowsBackendProcess.list,
    killProcess: WindowsBackendProcess.kill,
    backendExecutablePath: backendPath,
    log: log,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load custom server URL for LAN multi-user mode
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedServerUrl = prefs.getString('custom_server_url');
    if (savedServerUrl != null && savedServerUrl.trim().isNotEmpty) {
      ApiConstants.setCustomServerUrl(savedServerUrl.trim());
    }
  } catch (_) {}

  if (!kIsWeb && Platform.isWindows) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1366, 768),
        minimumSize: Size(1024, 600),
        center: true,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {}
  }

  // Started (without blocking runApp) by backendStartupProvider when the
  // BackendStartupGate first builds; it holds the login flow until ready.
  final backendLauncher = _createBackendLauncher();

  // Custom friendly error widget — prevents red screen of death
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final errStr = details.exceptionAsString();
    final isNetwork = errStr.toLowerCase().contains('connection') ||
        errStr.toLowerCase().contains('socket') ||
        errStr.toLowerCase().contains('dio') ||
        errStr.toLowerCase().contains('http');

    return Material(
      color: Colors.grey.shade100,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNetwork ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
                size: 54,
                color: isNetwork ? AppTheme.crimson : AppTheme.cobalt,
              ),
              const SizedBox(height: 14),
              Text(
                isNetwork ? 'Server Connection Notice' : 'Application Interface Notice',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isNetwork
                    ? 'Make sure the backend server is running on ${ApiConstants.serverUrl} then press Reload.'
                    : 'Press Reload to refresh the interface.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: SelectableText(
                  'Details:\n$errStr',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.crimson,
                      fontFamily: 'monospace'),
                  textAlign: TextAlign.start,
                ),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      await ref.read(backendStartupProvider.notifier).retry();
                      ref.read(appReloadKeyProvider.notifier).state++;
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Reload Application',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(
    ProviderScope(
      overrides: [
        backendLauncherProvider.overrideWithValue(backendLauncher),
      ],
      child: const SorourLogisticsApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom scroll behavior: enables mouse drag scrolling on desktop
// ─────────────────────────────────────────────────────────────────────────────

class AppCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Disable horizontal scrollbars system-wide across all screens and components
    if (details.direction == AxisDirection.left ||
        details.direction == AxisDirection.right) {
      return child;
    }
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      trackVisibility: true,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root application widget
// ─────────────────────────────────────────────────────────────────────────────

class SorourLogisticsApp extends ConsumerStatefulWidget {
  const SorourLogisticsApp({super.key});

  @override
  ConsumerState<SorourLogisticsApp> createState() => _SorourLogisticsAppState();
}

class _SorourLogisticsAppState extends ConsumerState<SorourLogisticsApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isWindows) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!kIsWeb && Platform.isWindows) {
      // Check if any workspace tab has unsaved changes
      try {
        final tabsState = ref.read(workspaceTabsProvider);
        if (tabsState.tabs.any((t) => t.isDirty)) {
          await windowManager.focus();
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            final confirmed = await UnsavedChangesDialog.show(
              ctx,
              customMessage: 'توجد علامات تبويب بها تعديلات غير محفوظة. هل تريد إغلاق النظام وإهمال التغييرات؟',
            );
            if (!confirmed) {
              return; // Abort window destruction
            }
          }
        }
      } catch (_) {}

      // 1. Auto-backup dev DB on every close (5s timeout, silent)
      try {
        final dio = ref.read(dioProvider);
        await dio
            .post(
              '${ApiConstants.productionSync}/backup',
              queryParameters: {'target': 'dev'},
            )
            .timeout(const Duration(seconds: 5))
            .catchError(
                (_) => Response(requestOptions: RequestOptions(path: '')));
      } catch (_) {}

      // 2. Graceful backend shutdown
      try {
        final dio = ref.read(dioProvider);
        await dio
            .post('${ApiConstants.serverUrl}/shutdown')
            .timeout(const Duration(milliseconds: 400))
            .catchError(
                (_) => Response(requestOptions: RequestOptions(path: '')));
      } catch (_) {}

      // 3. Terminate OUR backend.exe (matched by full path; never another
      //    install's backend, no console child process).
      try {
        await ref
            .read(backendLauncherProvider)
            .killOwnBackend()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}

      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reloadKey = ref.watch(appReloadKeyProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final density = ref.watch(displayDensityProvider);

    return KeyedSubtree(
      key: ValueKey(
          '${reloadKey}_${locale.languageCode}_${density.name}'),
      child: AppLocalizationsProvider(
        locale: locale,
        // No outer Directionality: MaterialApp's Localizations sets RTL for
        // `ar` itself now that `ar` is a supported locale.
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Sorour Logistics ERP (v${ApiConstants.clientVersion})',
          theme: AppTheme.lightTheme.copyWith(visualDensity: density.visualDensity),
          darkTheme: AppTheme.darkTheme.copyWith(visualDensity: density.visualDensity),
          themeMode: themeMode,
          scrollBehavior: AppCustomScrollBehavior(),
          locale: locale,
          supportedLocales: AppLocales.supportedLocales,
          localizationsDelegates: AppLocales.localizationsDelegates,
          navigatorObservers: [NavigationPerfTracker.instance],
          builder: (context, child) => child ?? const SizedBox.shrink(),
          home: const BackendStartupGate(child: AuthGate()),
        ),
      ),
    );
  }
}

/// Reactive gate that smoothly switches between HomeScreen and LoginScreen
/// based on authProvider authentication state without Navigator history traps.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    if (authState.isAuthenticated) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}

/// Backward compatibility alias
typedef ImportFlowApp = SorourLogisticsApp;

