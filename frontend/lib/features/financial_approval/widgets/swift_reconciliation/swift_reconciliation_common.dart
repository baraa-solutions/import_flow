import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';
import '../../../import_files/providers/import_files_provider.dart';

const String kSampleSwiftMT103 =
    '''{1:F01ARAIECXXXXX.SN...ISN.}{2:I103CITIUS33XXXXN}{3:{108:xxxxx}}{4:
:20/TRANSACTION REFERENCE NUMBER       : FT/26228/KZ70Q
:23B/BANK OPERATION CODE              : CRED
:32A/Value Date, CCY, Amount          : 260818USD43704,00
:50K/ORDERING CUST                     : /EG780057004001017153610010101
                                        SCAS FOR CONSTRUCTION AND FINISHING
                                        ROAD 18
                                        EGYPT,44 ROAD 18
                                        SARIAT EL MAADI,CAIRO
:57A/Account with Bank                : PCBCCNBJJSS
:59/Beneficiary Customer              : /32250198613609841015
                                        SUZHOU YUHENG TEXTILE CO., LTD
                                        16 KANGSHENG ROAD ZHITANG TOWN
                                        CHANGSHU CITY SUZHOU CHINA
:70/DETAILS OF PAYMENT                : EG0010040 PI NO.YH20260730.6
                                        ALL DOCUMENTS SHOULD BE TRADED
                                        THROUGH AAIB
:71A/DETAILS OF CHARGES               : SHA
-}''';

class SwiftVarianceBadge extends StatelessWidget {
  final String? status;
  final double? variance;
  final String currency;

  const SwiftVarianceBadge({
    super.key,
    required this.status,
    required this.variance,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (status == 'Matched' || (variance != null && variance!.abs() < 0.001)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.emeraldLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.emerald, size: 14),
            const SizedBox(width: 4),
            Text(
              l10n.swiftBadgeMatchedFull,
              style: const TextStyle(
                color: AppTheme.emerald,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'Deficit' || (variance != null && variance! < 0)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.crimsonLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_downward, color: AppTheme.crimson, size: 14),
            const SizedBox(width: 4),
            Text(
              l10n.swiftBadgeDeficit(
                variance?.abs().toStringAsFixed(2) ?? '0.00',
                currency,
              ),
              style: const TextStyle(
                color: AppTheme.crimson,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'Surplus' || (variance != null && variance! > 0)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.orangeLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_upward, color: AppTheme.orange, size: 14),
            const SizedBox(width: 4),
            Text(
              l10n.swiftBadgeSurplus(
                variance?.toStringAsFixed(2) ?? '0.00',
                currency,
              ),
              style: const TextStyle(
                color: AppTheme.orange,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.cloudWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.swiftBadgePending,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }
  }
}

class SwiftCopyBadge extends StatelessWidget {
  final String text;
  final String? tooltip;

  const SwiftCopyBadge({
    super.key,
    required this.text,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => CopyHelper.copy(context, text),
      child: Tooltip(
        message: tooltip ?? context.l10n.swiftCopyBtn,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
        ),
      ),
    );
  }
}

void copyPaymentDossier({
  required BuildContext context,
  required WidgetRef ref,
  required PaymentRequestModel pay,
}) {
  final l10n = context.l10n;
  final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final resolvedShipTitle = DisplayNameResolver.resolveShipmentTitleByCode(
    pay.importFileCode,
    shipments: allFiles,
    isArabic: isAr,
  );
  final status = pay.swiftVarianceStatus ??
      (pay.swiftReferenceNo != null && pay.swiftReferenceNo!.isNotEmpty
          ? l10n.swiftBadgeMatchedFull
          : l10n.swiftBadgePending);
  final text = '''
${l10n.swiftDetailsDialogTitle(pay.paymentCode)}
${l10n.swiftRequestTitleLabel} ${pay.title}
${l10n.swiftTsvHeaderImportFile}: $resolvedShipTitle
${l10n.swiftBeneficiaryLabel} ${pay.beneficiaryName ?? pay.supplierName}
${l10n.swiftBankLabel} ${pay.bankName ?? "-"} | SWIFT: ${pay.swiftCode ?? "-"} | ${l10n.swiftAccountLabel} ${pay.ibanAccountNo ?? "-"}
${l10n.swiftRequestDateLabel}: ${pay.requestDate.isNotEmpty ? pay.requestDate : "-"}
${l10n.swiftReceiptDateLabel}: ${pay.swiftReceiptDate ?? l10n.swiftBadgePending}
${l10n.swiftProcessingTimeLabel}: ${pay.swiftProcessingDays != null ? "${pay.swiftProcessingDays}" : "-"}
${l10n.swiftRequestedAmountLabel}: ${pay.requestedAmount.toStringAsFixed(2)} ${pay.currencyCode}
${l10n.swiftTransferredAmountLabel}: ${pay.swiftTransferredAmount != null ? "${pay.swiftTransferredAmount!.toStringAsFixed(2)} ${pay.swiftTransferredCurrency ?? pay.currencyCode}" : "-"}
${l10n.swiftVarianceLabel}: ${pay.swiftVarianceAmount != null ? "${pay.swiftVarianceAmount!.toStringAsFixed(2)} ${pay.currencyCode}" : "-"} ($status)
${l10n.swiftColSwiftRef}: ${pay.swiftReferenceNo ?? l10n.swiftStatusUnregistered}
${l10n.swiftReconciliationNotesLabel}: ${pay.swiftReconciliationNotes ?? "-"}
'''
      .trim();

  CopyHelper.copy(context, text, customMessage: l10n.swiftCopySummarySuccess);
}
