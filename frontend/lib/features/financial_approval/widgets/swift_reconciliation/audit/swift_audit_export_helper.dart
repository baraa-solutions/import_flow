import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/display_name_resolver.dart';
import '../../../../../core/widgets/copyable_data_helper.dart';
import '../../../../import_files/providers/import_files_provider.dart';
import '../../../models/financial_approval_model.dart';

class SwiftAuditExportHelper {
  static void exportTsv({
    required BuildContext context,
    required WidgetRef ref,
    required List<PaymentRequestModel> payments,
  }) {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    // Header
    buffer.writeln([
      l10n.swiftTsvHeaderPaymentCode,
      l10n.swiftTsvHeaderImportFile,
      l10n.swiftTsvHeaderBeneficiary,
      l10n.swiftTsvHeaderBank,
      l10n.swiftTsvHeaderRequestDate,
      l10n.swiftTsvHeaderSwiftReceiptDate,
      l10n.swiftTsvHeaderProcessingDays,
      l10n.swiftTsvHeaderRequestedAmount,
      l10n.swiftTsvHeaderTransferredAmount,
      l10n.swiftTsvHeaderVariance,
      l10n.swiftTsvHeaderSwiftRef,
      l10n.swiftTsvHeaderStatus,
    ].join('\t'));

    final allFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    for (final p in payments) {
      final days =
          p.swiftProcessingDays != null ? '${p.swiftProcessingDays}' : '-';
      final transferred = p.swiftTransferredAmount != null
          ? '${p.swiftTransferredAmount} ${p.swiftTransferredCurrency ?? p.currencyCode}'
          : '-';
      final variance = p.swiftVarianceAmount != null
          ? '${p.swiftVarianceAmount} ${p.swiftTransferredCurrency ?? p.currencyCode}'
          : '-';
      final status = p.swiftVarianceStatus ??
          (p.swiftReferenceNo != null && p.swiftReferenceNo!.isNotEmpty
              ? l10n.swiftBadgeMatchedFull
              : l10n.swiftBadgePending);
      final resolvedShipTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        p.importFileCode,
        shipments: allFiles,
        isArabic: isAr,
      );

      buffer.writeln([
        p.paymentCode,
        resolvedShipTitle,
        p.beneficiaryName ?? p.supplierName,
        p.bankName ?? '-',
        p.requestDate,
        p.swiftReceiptDate ?? '-',
        days,
        '${p.requestedAmount} ${p.currencyCode}',
        transferred,
        variance,
        p.swiftReferenceNo ?? '-',
        status,
      ].join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.swiftExportTsvSuccess,
    );
  }

  static void copyFilteredSummary({
    required BuildContext context,
    required List<PaymentRequestModel> payments,
  }) {
    final l10n = context.l10n;
    final matchedCount =
        payments.where((p) => p.swiftVarianceStatus == 'Matched').length;
    final pendingCount = payments
        .where((p) => p.swiftReferenceNo == null || p.swiftReferenceNo!.isEmpty)
        .length;
    final varianceCount = payments
        .where((p) =>
            p.swiftVarianceStatus == 'Deficit' ||
            p.swiftVarianceStatus == 'Surplus')
        .length;

    final summary = '''
${l10n.swiftScreenTitle}
${l10n.swiftTableTitle(payments.length)}
${l10n.swiftTotalRequestsMetric}: ${payments.length}
${l10n.swiftMatchedSwiftMetric}: $matchedCount
${l10n.swiftPendingSwiftMetric}: $pendingCount
${l10n.swiftVariancesMetric}: $varianceCount
'''
        .trim();

    CopyHelper.copy(
      context,
      summary,
      customMessage: l10n.swiftCopySummarySuccess,
    );
  }
}
