import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_date_picker_field.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/original_documents_collection_model.dart';
import '../../providers/original_documents_collection_provider.dart';
import '../idoc_ui.dart';

/// Dialogs for Original Documents Collection workflow.
class OriginalDocsDialogs {
  /// Shows the modal dialog to confirm courier delivery proof.
  static Future<void> showCourierDeliveryProofDialog({
    required BuildContext context,
    required WidgetRef ref,
    required int importFileId,
    required String courierNo,
    required String courierCompany,
    String? trackingNo,
    required String importFileCode,
    Future<void> Function()? onSessionReload,
  }) async {
    final l = context.l10n;
    DateTime selectedDate = DateTime.now();
    final now = DateTime.now();
    final timeCtrl = TextEditingController(
      text: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    final receiverCtrl = TextEditingController();
    final podCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool markDocsReceived = true;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final dateStr = AppDatePickerField.format(selectedDate);

          return SelectionArea(
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_outlined, color: AppTheme.emerald, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.courierDeliveryProofDialogTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$importFileCode | $courierCompany ${trackingNo != null ? "($trackingNo)" : ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.cobalt,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 12),
                      // Receipt Date & Time Pickers
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppDatePickerField(
                              label: l.courierReceiptDateLabel,
                              value: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                              onChanged: (picked) {
                                if (picked != null) {
                                  setModalState(() => selectedDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: timeCtrl,
                              decoration: InputDecoration(
                                labelText: l.courierReceiptTimeLabel,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.access_time, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Received By Field
                      TextField(
                        controller: receiverCtrl,
                        decoration: InputDecoration(
                          labelText: l.courierReceivedByLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // POD Reference
                      TextField(
                        controller: podCtrl,
                        decoration: InputDecoration(
                          labelText: l.courierPodRefLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.receipt_long_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Notes
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l.idocAReceiptAndVisualInspectionNotes,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.notes, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Auto-mark documents received checkbox
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.markAssociatedDocsReceivedLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emerald,
                            ),
                          ),
                          value: markDocsReceived,
                          activeColor: AppTheme.emerald,
                          onChanged: (val) => setModalState(() => markDocsReceived = val ?? true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IdocUi.fit(
                  AppButton(
                    label: l.cancel,
                    variant: AppButtonVariant.ghost,
                    onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  ),
                ),
                IdocUi.fit(
                  AppButton(
                    label: l.confirmCourierDeliveryBtn,
                    icon: Icons.verified,
                    variant: AppButtonVariant.success,
                    isLoading: isSubmitting,
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            try {
                              final req = CourierReceiptProofRequestModel(
                                importFileId: importFileId,
                                courierNo: courierNo,
                                receivedDate: dateStr,
                                receivedTime: timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null,
                                receivedBy: receiverCtrl.text.trim().isNotEmpty
                                    ? receiverCtrl.text.trim()
                                    : (Localizations.localeOf(context).languageCode == 'ar'
                                        ? 'مكتب الاستقبال والتخليص'
                                        : 'Receiving & Clearance Office'),
                                podReference: podCtrl.text.trim().isNotEmpty ? podCtrl.text.trim() : null,
                                notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                markDocumentsReceived: markDocsReceived,
                              );

                              await ref
                                  .read(originalDocumentsSessionsProvider.notifier)
                                  .confirmCourierReceipt(req);

                              ref.invalidate(courierAlertsProvider);
                              ref.invalidate(allCouriersProvider);

                              if (onSessionReload != null) {
                                await onSessionReload();
                              }

                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  AppTheme.snackBar(
                                    context,
                                    l.courierReceiptRecordedSuccess,
                                    severity: AppSeverity.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  AppTheme.snackBar(
                                    context,
                                    '${l.errorPrefix}: ${ApiErrorText.of(l, e)}',
                                    severity: AppSeverity.danger,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
