import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/update_format.dart';
import '../models/update_models.dart';
import '../providers/app_update_providers.dart';
import 'update_feedback.dart';
import 'update_restarting_overlay.dart';

Future<void> showUpdateRollbackDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const UpdateRollbackDialog(),
  );
}

/// Confirms `POST /rollback` (plan §4.5 step 8). Shows the backup timestamp and
/// a data-loss warning; the confirm button stays disabled until the user ticks
/// the explicit acknowledgement.
class UpdateRollbackDialog extends ConsumerStatefulWidget {
  const UpdateRollbackDialog({super.key});

  static const confirmKey = ValueKey('update_rollback_confirm');
  static const acknowledgeKey = ValueKey('update_rollback_acknowledge');

  @override
  ConsumerState<UpdateRollbackDialog> createState() => _UpdateRollbackDialogState();
}

class _UpdateRollbackDialogState extends ConsumerState<UpdateRollbackDialog> {
  bool _acknowledged = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // A candidate created by this mount's build is already fresh.
    if (ref.exists(rollbackCandidateProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(rollbackCandidateProvider);
      });
    }
  }

  Future<void> _confirm(RollbackCandidate candidate) async {
    if (_busy || !_acknowledged) return;
    setState(() => _busy = true);
    try {
      await ref.read(updateStatusProvider.notifier).rollback(candidate.backupFile);
      if (!mounted) return;
      await showRestartingAndExit(context, ref);
    } catch (e) {
      if (mounted) showUpdateErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final candidateAsync = ref.watch(rollbackCandidateProvider);
    final candidate = candidateAsync.valueOrNull;

    Widget body;
    if (candidateAsync.isLoading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppTheme.cobalt),
        ),
      );
    } else if (candidate == null) {
      body = Text(
        candidateAsync.hasError ? updateErrorText(l, candidateAsync.error) : l.updateRollbackNoBackup,
        style: const TextStyle(color: AppTheme.crimson),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.crimsonLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.crimsonBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.updateRollbackWarning(formatUpdateTimestamp(candidate.backupTime)),
                    style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: UpdateRollbackDialog.acknowledgeKey,
              value: _acknowledged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.crimson,
              title: Text(l.updateRollbackConfirmCheck, style: const TextStyle(fontSize: 13)),
              onChanged: _busy ? null : (v) => setState(() => _acknowledged = v ?? false),
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l.updateRollbackTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(width: 480, child: body),
        actions: [
          AppButton(
            label: l.updateClose,
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          if (candidate != null)
            AppButton(
              key: UpdateRollbackDialog.confirmKey,
              label: l.updateRollbackConfirmBtn,
              variant: AppButtonVariant.danger,
              icon: Icons.restore_rounded,
              isLoading: _busy,
              onPressed: _acknowledged ? () => _confirm(candidate) : null,
            ),
        ],
      ),
    );
  }
}
