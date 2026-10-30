import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../operational_dashboard/providers/operational_dashboard_provider.dart';
import '../providers/lifecycle_board_provider.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
/// Helper to display a unified "Skip Stage" dialog across all screens.
/// Enforces business rules: mandatory reason (>= 5 chars), policy validation,
/// loading feedback, and automatic provider invalidation upon completion.
class SkipStepDialogHelper {
  static Future<bool> show({
    required BuildContext context,
    required WidgetRef ref,
    required String importFileCode,
    String? currentStepCode,
    String? currentStepName,
    VoidCallback? onSuccess,
  }) async {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    // Resolve step code if not explicitly passed (default to STEP_01 or derived)
    final resolvedStepCode = (currentStepCode != null && currentStepCode.isNotEmpty)
        ? currentStepCode
        : inferStepCode(currentStepName);

    final resolvedStepName = currentStepName ?? resolvedStepCode;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return SelectionArea(
              child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fast_forward_rounded, color: AppTheme.orange, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.skipStepDialogTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target shipment and step banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_outlined, size: 15, color: AppTheme.cobalt),
                                const SizedBox(width: 6),
                                LtrText(
                                  importFileCode,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.cobalt),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.timeline_rounded, size: 15, color: AppTheme.orange),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$resolvedStepCode: $resolvedStepName',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.charcoal),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        l10n.skipStepConfirmText(resolvedStepName, importFileCode),
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 12),

                      // Reason Field
                      TextFormField(
                        controller: reasonController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: l10n.skipReasonLabel,
                          hintText: l10n.skipReasonHint,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return l10n.skipReasonRequired;
                          }
                          if (v.trim().length < 5) {
                            return 'يلزم إدخال 5 أحرف على الأقل لتبرير التخطي';
                          }
                          return null;
                        },
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(false),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final notifier = ref.read(lifecycleBoardActionProvider.notifier);
                          final success = await notifier.skipStep(
                            importFileCode: importFileCode,
                            currentStepCode: resolvedStepCode,
                            skipReason: reasonController.text.trim(),
                          );

                          if (ctx.mounted) {
                            setDialogState(() => isSubmitting = false);
                            if (success) {
                              Navigator.of(dialogCtx).pop(true);
                            } else {
                              // Display red error SnackBar with backend reason (e.g. policy blocked)
                              final errorMsg = notifier.lastErrorMessage ?? l10n.stepAdvanceErrorSnack;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.crimson,
                                  duration: const Duration(seconds: 6),
                                  content: Text(
                                    errorMsg,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                              Navigator.of(dialogCtx).pop(false);
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.fast_forward_rounded, size: 16),
                  label: Text(
                    isSubmitting ? 'جاري التخطي...' : l10n.confirmSkipAndAdvanceBtn,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              ),
            );
          },
        );
      },
    );

    if (result == true && context.mounted) {
      // Invalidate providers for real-time reactivity
      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(operationalDashboardProvider);
      ref.invalidate(paginatedImportFilesProvider);
      ref.invalidate(importFilesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.orange,
          content: Text(
            l10n.stepSkippedSuccessSnack(resolvedStepCode, importFileCode),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

      onSuccess?.call();
      return true;
    }

    return false;
  }

  /// Extracts or infers a STEP_xx code from a stage name or string.
  @visibleForTesting
  static String inferStepCode(String? stageName) {
    if (stageName == null || stageName.isEmpty) return 'STEP_01';
    final match = RegExp(r'STEP_\d{2}', caseSensitive: false).firstMatch(stageName);
    if (match != null) {
      return match.group(0)!.toUpperCase();
    }
    // Fallback: search common keywords
    final lower = stageName.toLowerCase();
    if (lower.contains('clearance') || lower.contains('تخليص')) return 'STEP_13';
    if (lower.contains('freight') || lower.contains('نولون')) return 'STEP_01';
    if (lower.contains('customs') || lower.contains('جمرك') || lower.contains('استشار') || lower.contains('تعريفة')) return 'STEP_02';
    if (lower.contains('requirement') || lower.contains('اشتراطات')) return 'STEP_03';
    if (lower.contains('financial') || lower.contains('مالي')) return 'STEP_04';
    if (lower.contains('acid') || lower.contains('نافذة')) return 'STEP_05';
    if (lower.contains('booking') || lower.contains('حجز')) return 'STEP_06';
    if (lower.contains('cargox') || lower.contains('مستندات')) return 'STEP_07';
    if (lower.contains('tracking') || lower.contains('إبحار')) return 'STEP_08';
    if (lower.contains('warehouse') || lower.contains('مخزن') || lower.contains('grn')) return 'STEP_19';
    if (lower.contains('landed') || lower.contains('تكلفة')) return 'STEP_20';
    if (lower.contains('close') || lower.contains('إغلاق')) return 'STEP_21';

    return 'STEP_01';
  }
}
