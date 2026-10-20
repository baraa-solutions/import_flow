import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/copyable_data_helper.dart';
import '../../features/import_files/models/import_file_model.dart';
import '../../features/import_files/providers/import_files_provider.dart';

class ReopenShipmentDialog extends ConsumerStatefulWidget {
  final ImportFileModel importFile;
  final VoidCallback? onSuccess;

  const ReopenShipmentDialog({
    super.key,
    required this.importFile,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required ImportFileModel importFile,
    VoidCallback? onSuccess,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReopenShipmentDialog(
        importFile: importFile,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<ReopenShipmentDialog> createState() => _ReopenShipmentDialogState();
}

class _ReopenShipmentDialogState extends ConsumerState<ReopenShipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleReopenShipment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = context.l10n;
    setState(() => _isSubmitting = true);
    try {
      final reopened = await ref.read(importFilesProvider.notifier).reopenShipment(
            widget.importFile.importFileId,
            _reasonController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop();
        final phaseName = reopened?.currentModule ?? widget.importFile.closedAtPhase ?? 'Phase 1';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.reopenShipmentSuccessSnack(widget.importFile.importFileCode, phaseName)),
            backgroundColor: AppTheme.emerald,
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.reopenShipmentErrorSnack('$e')),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restoredPhase = widget.importFile.closedAtPhase ?? 'Phase 1 - Import Planning & Feasibility';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(20),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.emerald.withValues(alpha: 0.08),
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(12),
            topEnd: Radius.circular(12),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.restart_alt, color: AppTheme.emerald, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.reopenShipmentDialogTitle(widget.importFile.importFileCode),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 550,
        child: SelectionArea(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notice Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.reopenShipmentRestoredPhase(restoredPhase),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emerald,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.reopenShipmentNotice,
                        style: const TextStyle(fontSize: 11, color: AppTheme.charcoal, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reason Text Field
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.l10n.reopenShipmentReasonLabel,
                    hintText: context.l10n.reopenShipmentReasonHint,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    alignLabelWithHint: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: context.l10n.fileClosureCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, _reasonController.text),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return context.l10n.reopenShipmentReasonValidatorEmpty;
                    }
                    if (val.trim().length < 3) {
                      return context.l10n.reopenShipmentReasonValidatorMin;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _handleReopenShipment,
          icon: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow, size: 18),
          label: Text(context.l10n.reopenShipmentConfirmBtn),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
