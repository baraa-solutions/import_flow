import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/app_update_providers.dart';
import 'update_feedback.dart';

/// Shows the non-dismissible "installing, the app will restart" overlay after
/// `/apply` or `/rollback` returned 202, then closes the app after
/// [updateExitDelay] so the installer can replace the binaries.
/// The exit goes through [appExitProvider], which never exits under tests.
Future<void> showRestartingAndExit(BuildContext context, WidgetRef ref) async {
  final exitApp = ref.read(appExitProvider);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const UpdateRestartingOverlay(),
  ));
  await Future<void>.delayed(updateExitDelay);
  exitApp();
}

/// Installs the already downloaded [version] (`POST /apply`), then shows the
/// restarting overlay and exits. Errors (403, 409, ...) become a SnackBar.
/// Returns false when the backend refused.
Future<bool> installUpdateAndRestart(BuildContext context, WidgetRef ref, String version) async {
  try {
    await ref.read(updateStatusProvider.notifier).applyUpdate(version);
  } catch (e) {
    if (context.mounted) showUpdateErrorSnackBar(context, e);
    return false;
  }
  if (context.mounted) await showRestartingAndExit(context, ref);
  return true;
}

class UpdateRestartingOverlay extends StatelessWidget {
  const UpdateRestartingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: false,
      child: SelectionArea(
        child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.emerald),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.updateInstalling, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(l.updateRestartingHint, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
