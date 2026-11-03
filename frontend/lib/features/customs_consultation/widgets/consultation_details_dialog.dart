import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_consultation_model.dart';
import '../services/customs_consultation_pdf_service.dart';
import '../services/customs_export_service.dart';
import 'consultation_metric_badge.dart';
import 'consultation_status_badges.dart';

void showConsultationDetailsDialog(
    BuildContext context, CustomsConsultationModel session) {
  showDialog(
    context: context,
    builder: (context) {
      final l = context.l10n;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SelectionArea(
        child: AlertDialog(
          backgroundColor:
              isDark ? AppTheme.darkCardBackground : AppTheme.white,
          title: Row(
            children: [
              const Icon(Icons.verified_user, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: CopyableText(
                  '${l.consultationDetailsTitle}: ${session.consultationCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
              ),
              ConsultationStatusBadge(status: session.overallStatus),
            ],
          ),
          content: SizedBox(
            width: 750,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkElevatedSurface
                          : AppTheme.charcoalSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText('${l.titleField}: ${session.title}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        CopyableText(
                            '${l.customsBrokerLabel}: ${session.brokerName} ${session.brokerContactPerson != null ? "(${session.brokerContactPerson})" : ""}'),
                        const SizedBox(height: 6),
                        CopyableText(
                            '${l.totalTaxesAndDutiesCol}: ${session.estimatedDutiesEgp.toStringAsFixed(2)} EGP'),
                        if (session.notes != null &&
                            session.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          CopyableText('${l.notes}: ${session.notes}'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ConsultationMetricBadge(
                          title: l.customsInspectionReadiness,
                          value: '${session.readinessPercentage}%',
                          color: AppTheme.cobalt),
                      const SizedBox(width: 8),
                      ConsultationMetricBadge(
                          title: l.itemsAndDocsCount,
                          value: '${session.totalDocumentsCount}',
                          color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      ConsultationMetricBadge(
                          title: l.clearanceReadyStatus,
                          value: '${session.approvedDocumentsCount}',
                          color: AppTheme.emerald),
                      const SizedBox(width: 8),
                      ConsultationMetricBadge(
                          title: l.blockingIssuesCount,
                          value: '${session.blockingIssuesCount}',
                          color: session.blockingIssuesCount > 0
                              ? AppTheme.crimson
                              : AppTheme.emerald),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (session.brokerQuoteItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.clearanceQuotesTab,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.charcoal),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: CopyableText(
                              '${l.totalExpenses}: ${session.totalBrokerFeesEgp.toStringAsFixed(2)} EGP',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cobalt,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.cloudWhite),
                      columnWidths: const {
                        0: FlexColumnWidth(2.8),
                        1: FlexColumnWidth(1.8),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(0.8),
                        4: FlexColumnWidth(1.4),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(
                                  alpha: isDark ? 0.2 : 0.08)),
                          children: [
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(l.expenseItemNameCol,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(l.categoryCol,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(l.itemPriceCol,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(l.quoteItemQuantity,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(l.totalExpenses,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                          ],
                        ),
                        ...session.brokerQuoteItems
                            .where((q) => q.isApplicable)
                            .map((quote) {
                          return TableRow(
                            children: [
                              Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CopyableText(quote.expenseName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11))),
                              Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CopyableText(
                                      quote.category.split('(').first.trim(),
                                      style: const TextStyle(fontSize: 10))),
                              Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CopyableText(
                                      '${quote.unitPrice.toStringAsFixed(2)} ${quote.currency}',
                                      style: const TextStyle(fontSize: 11))),
                              Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CopyableText('${quote.qty}',
                                      style: const TextStyle(fontSize: 11))),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                    '${quote.totalAmount.toStringAsFixed(2)} ${quote.currency}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.emerald,
                                        fontSize: 11)),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l.customsChecklistTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.cloudWhite),
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1.2),
                      3: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkElevatedSurface
                                : AppTheme.charcoal.withValues(alpha: 0.08)),
                        children: [
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(l.requiredDocCheckbox,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(l.responsiblePartyLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(l.statusCol,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(l.notes,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                      ...session.checklistItems.map((doc) {
                        final statusLower = doc.status.toLowerCase();
                        final isApproved = statusLower == 'approved' ||
                            statusLower == 'verified' ||
                            statusLower == 'completed' ||
                            statusLower == 'received' ||
                            statusLower == 'obtained' ||
                            statusLower.contains('معتمد') ||
                            statusLower.contains('مستوفى');
                        final isRejected = statusLower == 'rejected' ||
                            statusLower.contains('مرفوض');

                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  if (isApproved)
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppTheme.emerald, size: 16)
                                  else if (isRejected)
                                    const Icon(Icons.cancel_rounded,
                                        color: AppTheme.crimson, size: 16)
                                  else ...[
                                    const Icon(Icons.hourglass_top_rounded,
                                        color: AppTheme.orange, size: 15),
                                    if (doc.isBlockingShipment) ...[
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message: l
                                            .shipmentUpdateConsultBlockingTooltip,
                                        child: const Icon(Icons.block,
                                            color: AppTheme.crimson, size: 13),
                                      ),
                                    ],
                                  ],
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: CopyableText(doc.documentType,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600))),
                                ],
                              ),
                            ),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: CopyableText(doc.responsibleParty)),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: ConsultationDocStatusBadge(
                                    status: doc.status)),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child:
                                    CopyableText(doc.remarks ?? '-')),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l.print,
              icon: Icons.picture_as_pdf,
              variant: AppButtonVariant.primary,
              onPressed: () async {
                await Printing.layoutPdf(
                  onLayout: (format) =>
                      CustomsConsultationPdfService.generateConsultationPdf(
                          session),
                  name: 'Customs_Consultation_${session.consultationCode}',
                );
              },
            ),
            const SizedBox(width: 8),
            AppButton(
              label: l.export,
              icon: Icons.table_chart,
              variant: AppButtonVariant.success,
              onPressed: () async {
                final nafezaRes =
                    CustomsExportService.computeNafezaFeeBreakdown(
                  totalDutyEgp: session.estimatedDutiesEgp * 0.45,
                  totalVatEgp: session.estimatedDutiesEgp * 0.45,
                  totalServiceFeeEgp: session.estimatedDutiesEgp * 0.10,
                  totalScheduleTaxEgp: 0.0,
                );
                try {
                  final saved =
                      await CustomsExportService.exportCustomsStudyToExcel(
                    context: context,
                    title: session.title,
                    importFileCode: session.importFileCode,
                    brokerName: session.brokerName,
                    currency: 'EGP',
                    exchangeRate: 1.0,
                    totalFreightEgp: 0.0,
                    totalInsuranceEgp: 0.0,
                    calcLines: [],
                    nafezaResult: nafezaRes,
                    brokerQuoteItems: session.brokerQuoteItems,
                  );
                  if (saved != null && context.mounted) {
                    AppTheme.snackBar(context, '✅ $saved',
                        severity: AppSeverity.success);
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppTheme.snackBar(
                      context,
                      '❌ ${ApiErrorText.of(context.l10n, e)}',
                      severity: AppSeverity.danger,
                    );
                  }
                }
              },
            ),
            const Spacer(),
            AppButton(
              label: l.close,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    },
  );
}
