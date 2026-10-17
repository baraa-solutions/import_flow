import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';

/// ❌ Error State Widget — ImportFlow ERP
///
/// Replaces 164+ manual `Center(child: Column(children: [Icon(error), Text]))` 
/// error patterns in Riverpod `AsyncValue.when(error:...)` across 105 files.
///
/// Usage:
/// ```dart
/// // In AsyncValue.when()
/// state.when(
///   loading: () => const AppLoadingState(),
///   data: (items) => _buildList(items),
///   error: (e, st) => AppErrorState(
///     error: e,
///     onRetry: () => ref.invalidate(myProvider),
///   ),
/// )
///
/// // Simple error without retry
/// AppErrorState(error: e)
///
/// // Custom message
/// AppErrorState(message: l10n.operationFailed, onRetry: _reload)
/// ```
class AppErrorState extends StatelessWidget {
  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  const AppErrorState({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    // Resolve display message: prefer explicit `message`, then error.toString(),
    // finally generic fallback.
    String displayMsg;
    if (message != null) {
      displayMsg = message!;
    } else if (error != null) {
      final raw = error.toString();
      // Truncate very long error strings to stay readable.
      displayMsg = raw.length > 200 ? '${raw.substring(0, 197)}…' : raw;
    } else {
      displayMsg = l.operationFailed;
    }

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayMsg,
                style: const TextStyle(
                  color: AppTheme.crimson,
                  fontSize: 12.5,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(l.retry, style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.cobalt,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.crimson,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              l.operationFailed,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.crimson,
                letterSpacing: 0,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l.retry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cobalt,
                  side: const BorderSide(color: AppTheme.cobalt),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, letterSpacing: 0),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
