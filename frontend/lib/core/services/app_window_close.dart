import 'package:window_manager/window_manager.dart';

/// One step of the app-close sequence (backup, backend shutdown, ...).
/// Each step owns its own timeout; a throw is swallowed so closing never stops.
typedef AppCloseStep = Future<void> Function();

/// Runs [steps] in order, then closes the main window through the normal Win32
/// path ([closeMainWindowSafely]).
Future<void> runAppCloseSequence(
  WindowManager windowManager, {
  required List<AppCloseStep> steps,
}) async {
  for (final step in steps) {
    try {
      await step();
    } catch (_) {}
  }
  await closeMainWindowSafely(windowManager);
}

/// Closes the main window so Windows destroys it (WM_CLOSE -> WM_DESTROY ->
/// Flutter engine shutdown -> PostQuitMessage) while the message loop still runs.
///
/// Never use `windowManager.destroy()` here: in window_manager 0.3.x it is only
/// `PostQuitMessage(0)`, so the loop ends while the window and engine are alive
/// and the engine is torn down afterwards. That crashed every close of v2.1.x
/// (access violation in flutter_windows.dll+0x1d7b0, ~20 s white "Not
/// Responding" window, then 0xC000041D).
Future<void> closeMainWindowSafely(WindowManager windowManager) async {
  await windowManager.setPreventClose(false);
  await windowManager.close();
}
