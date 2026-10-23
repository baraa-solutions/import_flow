import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../localization/app_localizations.dart';
import '../services/backend_launcher.dart';
import '../theme/app_theme.dart';
import 'buttons/app_button.dart';

/// Shows [child] once the local backend answers `/health`; until then a small
/// "starting the system" view, and on failure an error with Retry.
///
/// Holds the login / session-restore flow until the backend is up. After the
/// first successful start the child stays mounted: a later recovery (backend
/// died, see `recoverBackendOnConnectionError`) is shown as an overlay so open
/// tabs and unsaved forms are not torn down.
class BackendStartupGate extends ConsumerStatefulWidget {
  const BackendStartupGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackendStartupGate> createState() => _BackendStartupGateState();
}

class _BackendStartupGateState extends ConsumerState<BackendStartupGate> {
  bool _wasReady = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(backendStartupProvider);
    if (status.isReady) _wasReady = true;
    if (!_wasReady) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Sorour Brand Background Watermark (Startup Screen) ──
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Center(
                    child: Opacity(
                      opacity: isDark ? 0.035 : 0.05,
                      child: Image.asset(
                        'assets/brand/sorour_logo_watermark.png',
                        width: 480,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: 960,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _StatusPanel(status: status),
          ],
        ),
      );
    }
    // Same Stack shape whether or not the overlay shows, so the child element
    // is never reparented (that would drop its state).
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!status.isReady) ...[
          ModalBarrier(
            dismissible: false,
            color: AppTheme.charcoal.withValues(alpha: 0.35),
          ),
          Material(
            type: MaterialType.transparency,
            child: _StatusPanel(status: status),
          ),
        ],
      ],
    );
  }
}

class _StatusPanel extends ConsumerWidget {
  const _StatusPanel({required this.status});

  final BackendLaunchStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: AppTheme.cardDecorationOf(context),
        child: status.isFailed
            ? _FailedView(
                failure: status.failure ?? BackendLaunchFailure.timeout,
                onRetry: () => ref.read(backendStartupProvider.notifier).retry(),
              )
            : const _StartingView(),
      ),
    );
  }
}

class _StartingView extends StatelessWidget {
  const _StartingView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      key: const ValueKey('backend-startup-starting'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          isDark
              ? 'assets/brand/sorour_logo_dark.png'
              : 'assets/brand/sorour_logo_full.png',
          height: 60,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.cobalt),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.backendStartupStarting,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.backendStartupStartingHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FailedView extends StatefulWidget {
  const _FailedView({required this.failure, required this.onRetry});

  final BackendLaunchFailure failure;
  final Future<void> Function() onRetry;

  @override
  State<_FailedView> createState() => _FailedViewState();
}

class _FailedViewState extends State<_FailedView> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _port() {
    final uri = Uri.tryParse(ApiConstants.serverUrl);
    return (uri != null && uri.hasPort) ? '${uri.port}' : ApiConstants.serverUrl;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final portInUse = widget.failure == BackendLaunchFailure.portInUse;
    return Column(
      key: const ValueKey('backend-startup-failed'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          portInUse ? Icons.lan_outlined : Icons.cloud_off_rounded,
          size: 48,
          color: AppTheme.crimson,
        ),
        const SizedBox(height: 14),
        Text(
          l10n.backendStartupFailedTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.crimson,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          portInUse
              ? l10n.backendStartupPortInUseMessage(_port())
              : l10n.backendStartupFailedMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: l10n.retry,
          icon: Icons.refresh,
          isLoading: _busy,
          onPressed: _busy ? null : _retry,
        ),
      ],
    );
  }
}
