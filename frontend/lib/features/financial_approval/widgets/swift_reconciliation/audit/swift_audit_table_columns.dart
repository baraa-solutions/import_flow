import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/display_name_resolver.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../../../import_files/providers/import_files_provider.dart';
import '../../../models/financial_approval_model.dart';
import '../../financial_ui.dart';
import '../swift_discrepancy_dialog.dart';
import '../swift_mt103_preview_card.dart';
import '../swift_reconciliation_common.dart';

class SwiftAuditTableColumns {
  static List<EnterpriseColumn<PaymentRequestModel>> buildColumns({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l10n,
    VoidCallback? onReconciled,
  }) {
    return [
      EnterpriseColumn<PaymentRequestModel>(
        id: 'actions',
        title: l10n.swiftColActions,
        width: 320,
        isSortable: false,
        isSearchable: false,
        cellBuilder: (ctx, pay, _) {
          final isReconciled =
              pay.swiftReferenceNo != null && pay.swiftReferenceNo!.isNotEmpty;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FinancialUi.fit(AppButton(
                label: isReconciled ? l10n.swiftEditBtn : l10n.swiftRegisterBtn,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: isReconciled ? Icons.edit : Icons.account_balance,
                onPressed: () => SwiftDiscrepancyDialog.show(
                  context,
                  pay: pay,
                  onReconciled: onReconciled,
                ),
              )),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.visibility,
                    color: AppTheme.charcoal, size: 18),
                tooltip: l10n.swiftDetailsBtn,
                onPressed: () => SwiftMt103PreviewDialog.show(
                  context,
                  pay: pay,
                  onReconciled: onReconciled,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: AppTheme.cobalt, size: 16),
                tooltip: l10n.swiftCopyDossierBtn,
                onPressed: () => copyPaymentDossier(
                  context: context,
                  ref: ref,
                  pay: pay,
                ),
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'payment_code',
        title: l10n.swiftColPaymentCode,
        width: 210,
        searchValue: (pay) => '${pay.paymentCode} ${pay.importFileCode ?? ""}',
        exportValue: (pay) => pay.paymentCode,
        cellBuilder: (ctx, pay, _) {
          final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final shipName = DisplayNameResolver.resolveShipmentNameByCode(
            pay.importFileCode,
            shipments: allFiles,
            isArabic: isAr,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LtrText(
                    pay.paymentCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SwiftCopyBadge(
                    text: pay.paymentCode,
                    tooltip: l10n.swiftCopyBtn,
                  ),
                ],
              ),
              if (pay.importFileCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shipName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pay.importFileCode!,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppTheme.textStrong,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      SwiftCopyBadge(
                        text: pay.importFileCode!,
                        tooltip: l10n.swiftCopyBtn,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'beneficiary',
        title: l10n.swiftColBeneficiaryBank,
        width: 180,
        searchValue: (pay) =>
            '${pay.beneficiaryName ?? pay.supplierName} ${pay.bankName ?? ""}',
        exportValue: (pay) =>
            '${pay.beneficiaryName ?? pay.supplierName} - ${pay.bankName ?? ""}',
        cellBuilder: (ctx, pay, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pay.beneficiaryName ?? pay.supplierName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            Text(
              pay.bankName ?? l10n.swiftUnspecifiedBank,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'request_date',
        title: l10n.swiftColRequestDate,
        width: 115,
        isNumeric: true,
        searchValue: (pay) => pay.requestDate,
        exportValue: (pay) => pay.requestDate,
        cellBuilder: (ctx, pay, _) => Text(
          pay.requestDate.isNotEmpty ? pay.requestDate : '-',
        ),
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'swift_date',
        title: l10n.swiftColSwiftDate,
        width: 115,
        isNumeric: true,
        searchValue: (pay) => pay.swiftReceiptDate ?? '',
        exportValue: (pay) => pay.swiftReceiptDate ?? '-',
        cellBuilder: (ctx, pay, _) {
          final isReconciled =
              pay.swiftReferenceNo != null && pay.swiftReferenceNo!.isNotEmpty;
          return Text(
            pay.swiftReceiptDate ?? l10n.swiftPendingSwiftBadge,
            style: TextStyle(
              fontWeight:
                  isReconciled ? FontWeight.bold : FontWeight.normal,
              color: isReconciled ? AppTheme.charcoal : AppTheme.textMuted,
            ),
          );
        },
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'processing_time',
        title: l10n.swiftColProcessingTime,
        width: 130,
        cellBuilder: (ctx, pay, _) {
          if (pay.swiftProcessingDays == null) {
            return Text(
              l10n.swiftProcessingPending,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            );
          }
          final days = pay.swiftProcessingDays!;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: days <= 3
                  ? AppTheme.emeraldLight
                  : (days <= 7 ? AppTheme.orangeLight : AppTheme.crimsonLight),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: days <= 3
                    ? AppTheme.emeraldBorder
                    : (days <= 7 ? AppTheme.orange : AppTheme.crimsonBorder),
              ),
            ),
            child: Text(
              '⚡ ${l10n.swiftDaysCount(days.toString())}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: days <= 3
                    ? AppTheme.wcagEmerald
                    : (days <= 7 ? AppTheme.wcagOrange : AppTheme.crimson),
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'requested_amount',
        title: l10n.swiftColRequestedAmount,
        width: 135,
        isNumeric: true,
        searchValue: (pay) => '${pay.requestedAmount} ${pay.currencyCode}',
        exportValue: (pay) =>
            '${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}',
        cellBuilder: (ctx, pay, _) => Text(
          '${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'transferred_amount',
        title: l10n.swiftColTransferredAmount,
        width: 135,
        isNumeric: true,
        searchValue: (pay) => pay.swiftTransferredAmount?.toString() ?? '',
        exportValue: (pay) => pay.swiftTransferredAmount != null
            ? '${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}'
            : '-',
        cellBuilder: (ctx, pay, _) => pay.swiftTransferredAmount != null
            ? Text(
                '${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              )
            : const Text('-', style: TextStyle(color: AppTheme.textMuted)),
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'variance_status',
        title: l10n.swiftColVarianceStatus,
        width: 130,
        searchValue: (pay) => pay.swiftVarianceStatus ?? '',
        exportValue: (pay) =>
            '${pay.swiftVarianceStatus ?? "-"} ${pay.swiftVarianceAmount != null ? pay.swiftVarianceAmount!.toStringAsFixed(2) : ""}',
        cellBuilder: (ctx, pay, _) => SwiftVarianceBadge(
          status: pay.swiftVarianceStatus,
          variance: pay.swiftVarianceAmount,
          currency: pay.currencyCode,
        ),
      ),
      EnterpriseColumn<PaymentRequestModel>(
        id: 'swift_ref',
        title: l10n.swiftColSwiftRef,
        width: 150,
        searchValue: (pay) => pay.swiftReferenceNo ?? '',
        exportValue: (pay) => pay.swiftReferenceNo ?? '-',
        cellBuilder: (ctx, pay, _) {
          if (pay.swiftReferenceNo != null && pay.swiftReferenceNo!.isNotEmpty) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobaltLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.cobaltBorder),
                  ),
                  child: Text(
                    pay.swiftReferenceNo!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.cobalt,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SwiftCopyBadge(
                  text: pay.swiftReferenceNo!,
                  tooltip: l10n.swiftCopyBtn,
                ),
              ],
            );
          }
          return Text(
            l10n.swiftUnregistered,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          );
        },
      ),
    ];
  }
}
