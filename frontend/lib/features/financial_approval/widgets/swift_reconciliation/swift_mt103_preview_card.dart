import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../financial_ui.dart';
import '../../models/financial_approval_model.dart';
import '../../services/financial_export_service.dart';
import 'swift_discrepancy_dialog.dart';
import 'swift_reconciliation_common.dart';

/// Modal dialog and official preview card for MT103 SWIFT reconciliation details.
class SwiftMt103PreviewDialog extends ConsumerWidget {
  final PaymentRequestModel pay;
  final VoidCallback? onReconciled;

  const SwiftMt103PreviewDialog({
    super.key,
    required this.pay,
    this.onReconciled,
  });

  static Future<void> show(
    BuildContext context, {
    required PaymentRequestModel pay,
    VoidCallback? onReconciled,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => SwiftMt103PreviewDialog(
        pay: pay,
        onReconciled: onReconciled,
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textStrong)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SelectionArea(
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.swiftDetailsDialogTitle(pay.paymentCode),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SwiftVarianceBadge(
              status: pay.swiftVarianceStatus,
              variance: pay.swiftVarianceAmount,
              currency: pay.currencyCode,
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        pay.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.charcoal,
                        ),
                      ),
                    ),
                    if (pay.importFileCode != null)
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () =>
                            CopyHelper.copy(context, pay.importFileCode!),
                        child: Tooltip(
                          message: l10n.swiftCopyFieldTooltip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.copy_rounded,
                                    color: AppTheme.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  pay.importFileCode!,
                                  style: const TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${l10n.swiftBeneficiaryLabel} ${pay.beneficiaryName ?? pay.supplierName}',
                ),
                Text(
                  '${l10n.swiftBankLabel} ${pay.bankName ?? "-"} | SWIFT: ${pay.swiftCode ?? "-"} | ${l10n.swiftAccountLabel} ${pay.ibanAccountNo ?? "-"}',
                ),
                const Divider(),
                Row(
                  children: [
                    _buildStatPill(
                      l10n.swiftRequestDateLabel,
                      pay.requestDate.isNotEmpty ? pay.requestDate : '-',
                      AppTheme.charcoal,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      l10n.swiftColSwiftDate,
                      pay.swiftReceiptDate ?? l10n.swiftBadgePending,
                      AppTheme.cobalt,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      l10n.swiftProcessingTimeLabel,
                      pay.swiftProcessingDays != null
                          ? l10n.swiftDaysCount(pay.swiftProcessingDays)
                          : '-',
                      AppTheme.emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatPill(
                      l10n.swiftRequestedAmountLabel,
                      '${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}',
                      AppTheme.cobalt,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      l10n.swiftTransferredAmountLabel,
                      pay.swiftTransferredAmount != null
                          ? '${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}'
                          : '-',
                      AppTheme.emerald,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      l10n.swiftVarianceLabel,
                      pay.swiftVarianceAmount != null
                          ? '${pay.swiftVarianceAmount!.toStringAsFixed(2)} ${pay.currencyCode}'
                          : '-',
                      AppTheme.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cloudWhite),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tag,
                              color: AppTheme.cobalt, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${l10n.swiftColSwiftRef}:',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  pay.swiftReferenceNo ??
                                      l10n.swiftStatusUnregistered,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.cobalt,
                                    fontSize: 14,
                                  ),
                                ),
                                if (pay.swiftReferenceNo != null &&
                                    pay.swiftReferenceNo!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => CopyHelper.copy(
                                        context, pay.swiftReferenceNo!),
                                    child: Tooltip(
                                      message: l10n.swiftCopyFieldTooltip,
                                      child: const Icon(Icons.copy_rounded,
                                          size: 15, color: AppTheme.cobalt),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (pay.swiftReconciliationNotes != null &&
                          pay.swiftReconciliationNotes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.swiftReconciliationNotesLabel}: ${pay.swiftReconciliationNotes}',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FinancialUi.fit(AppButton(
            label: l10n.swiftCloseBtn,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          )),
          FinancialUi.fit(AppButton(
            label: l10n.swiftPrintSlipBtn,
            variant: AppButtonVariant.secondary,
            icon: Icons.picture_as_pdf,
            onPressed: () {
              FinancialExportService.printOrSaveSwiftSlipPdf(
                context: context,
                payment: pay,
              );
            },
          )),
          FinancialUi.fit(AppButton(
            label: l10n.swiftCopySummaryBtn,
            variant: AppButtonVariant.secondary,
            icon: Icons.copy_rounded,
            onPressed: () => copyPaymentDossier(
              context: context,
              ref: ref,
              pay: pay,
            ),
          )),
          FinancialUi.fit(AppButton(
            label: l10n.swiftEditBtn,
            variant: AppButtonVariant.primary,
            icon: Icons.edit,
            onPressed: () {
              Navigator.of(context).pop();
              SwiftDiscrepancyDialog.show(
                context,
                pay: pay,
                onReconciled: onReconciled,
              );
            },
          )),
        ],
      ),
    );
  }
}
