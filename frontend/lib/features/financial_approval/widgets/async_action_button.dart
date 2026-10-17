import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';

/// A button for a single async backend action (approve, mark paid, ...).
///
/// While [onAction] runs the button shows a spinner and ignores taps. If it
/// throws, the backend message ([ApiError.message], which unwraps
/// `{code, message}` details) is shown in a SnackBar and the button re-enables.
class AsyncActionButton extends StatefulWidget {
  final String label;
  final AppButtonVariant variant;
  final Future<void> Function() onAction;
  final bool enabled;

  const AsyncActionButton({
    super.key,
    required this.label,
    required this.onAction,
    this.variant = AppButtonVariant.primary,
    this.enabled = true,
  });

  @override
  State<AsyncActionButton> createState() => _AsyncActionButtonState();
}

class _AsyncActionButtonState extends State<AsyncActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || !widget.enabled) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.onAction();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ApiError.message(e)),
          backgroundColor: AppTheme.crimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: widget.label,
      variant: widget.variant,
      isLoading: _busy,
      onPressed: (_busy || !widget.enabled) ? null : _run,
    );
  }
}
