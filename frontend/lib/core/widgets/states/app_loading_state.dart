import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';

/// ⏳ Loading State Widget — ImportFlow ERP
///
/// Replaces 176+ manual `Center(child: CircularProgressIndicator(...))` 
/// patterns across 110 files.
///
/// Usage:
/// ```dart
/// // In AsyncValue.when()
/// state.when(
///   loading: () => const AppLoadingState(),
///   data: (items) => _buildList(items),
///   error: (e, st) => AppErrorState(error: e, onRetry: () => ref.invalidate(myProvider)),
/// )
///
/// // Full-screen loading
/// const AppLoadingState()
///
/// // Section loading (smaller, no flex expansion)
/// const AppLoadingState.section()
///
/// // Inline micro-spinner
/// const AppLoadingState.inline()
/// ```
class AppLoadingState extends StatelessWidget {
  final _LoadingLayout _layout;
  final String? message;

  const AppLoadingState({super.key, this.message})
      : _layout = _LoadingLayout.fullscreen;

  const AppLoadingState.section({super.key, this.message})
      : _layout = _LoadingLayout.section;

  const AppLoadingState.inline({super.key, this.message})
      : _layout = _LoadingLayout.inline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final msg = message ?? l.loading;

    return switch (_layout) {
      _LoadingLayout.fullscreen => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppTheme.cobalt,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                msg,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      _LoadingLayout.section => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AppTheme.cobalt,
                    strokeWidth: 2.5,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedOf(context),
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      _LoadingLayout.inline => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: AppTheme.cobalt,
                strokeWidth: 2,
              ),
            ),
            if (message != null) ...[
              const SizedBox(width: 8),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedOf(context),
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
    };
  }
}

enum _LoadingLayout { fullscreen, section, inline }
