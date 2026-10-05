import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/customs_clearance_quotation_model.dart';
import '../services/customs_clearance_quotations_export_service.dart';

/// Status chip style of an RFQ (Draft / Quotations Received / Awarded).
({AppSeverity severity, String label}) rfqStatusStyle(AppLocalizations l, String status) {
  switch (status) {
    case 'Awarded':
      return (severity: AppSeverity.success, label: l.clearanceQuotesStatusAwarded);
    case 'Quotations Received':
      return (severity: AppSeverity.info, label: l.clearanceQuotesStatusReceived);
    case 'Draft':
      return (severity: AppSeverity.warning, label: l.clearanceQuotesStatusDraft);
    default:
      return (severity: AppSeverity.info, label: status);
  }
}

/// One RFQ: identity + status, cargo facts, awarded banner and the competing
/// quotations table (money columns right-aligned).
class RfqCard extends StatelessWidget {
  const RfqCard({
    super.key,
    required this.rfq,
    required this.onSmartExtract,
    required this.onAddQuote,
    required this.onAward,
    required this.onDeleteQuote,
  });

  final CustomsClearanceRFQModel rfq;
  final VoidCallback onSmartExtract;
  final VoidCallback onAddQuote;
  final void Function(int quotationId) onAward;
  final void Function(int quotationId) onDeleteQuote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = rfqStatusStyle(l10n, rfq.status);
    final awarded = rfq.status == 'Awarded';
    final decoration = AppTheme.cardDecorationOf(context).copyWith(
      border: Border.all(color: awarded ? AppTheme.emeraldBorder : AppTheme.borderOf(context)),
    );

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 16),
      padding: const EdgeInsetsDirectional.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, l10n, status),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _InfoBadge(Icons.anchor_rounded, l10n.clearanceQuotesBadgePort, rfq.portName),
              _InfoBadge(Icons.local_shipping_rounded, l10n.clearanceQuotesBadgeShipmentType,
                  '${rfq.shipmentType} (${rfq.containersCount})'),
              if (rfq.hsCode != null && rfq.hsCode!.isNotEmpty)
                _InfoBadge(Icons.category_rounded, l10n.clearanceQuotesBadgeHsCode, rfq.hsCode!, ltr: true),
              _InfoBadge(Icons.scale_rounded, l10n.clearanceQuotesBadgeWeight,
                  '${CcFormat.money(rfq.grossWeightKg)} ${l10n.kgUnit}', ltr: true),
              _InfoBadge(Icons.view_in_ar_rounded, l10n.clearanceQuotesBadgeVolume,
                  '${CcFormat.money(rfq.cbm)} ${l10n.cbmUnit}', ltr: true),
              if (rfq.lowestClearanceCost > 0)
                _InfoBadge(Icons.monetization_on_rounded, l10n.clearanceQuotesBadgeLowestCost,
                    '${CcFormat.money(rfq.lowestClearanceCost)} ${l10n.egpCurrency}',
                    color: AppTheme.successForeground, ltr: true),
              if (rfq.fastestTurnaroundDays > 0)
                _InfoBadge(Icons.timer_rounded, l10n.clearanceQuotesBadgeFastestDuration,
                    l10n.clearanceQuotesDaysCount(rfq.fastestTurnaroundDays),
                    color: AppTheme.infoForeground),
            ],
          ),
          if (awarded && rfq.awardedProviderName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.emeraldBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppTheme.successForeground, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.clearanceQuotesAwardedBannerPrefix} ${rfq.awardedProviderName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successForeground,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Divider(height: 24, color: AppTheme.borderOf(context)),
          _quotesHeader(context, l10n),
          const SizedBox(height: 10),
          if (rfq.quotations.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
              child: Text(
                l10n.clearanceQuotesNoQuotesYet,
                style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
              ),
            )
          else
            _quotesTable(context, l10n),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l10n, ({AppSeverity severity, String label}) status) {
    return Row(
      children: [
        InkWell(
          onTap: () => CopyHelper.copy(context, rfq.rfqCode),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.charcoalSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LtrText(
                  rfq.rfqCode,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                ),
                const SizedBox(width: 5),
                Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondaryOf(context)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            rfq.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
          tooltip: l10n.clearanceQuotesCopyDossierBtn,
          onPressed: () => CustomsClearanceQuotationsExportService.copyRfqDossier(context, [rfq]),
        ),
        const SizedBox(width: 6),
        CcStatusChip(label: status.label, severity: status.severity),
      ],
    );
  }

  Widget _quotesHeader(BuildContext context, AppLocalizations l10n) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(
          l10n.clearanceQuotesReceivedQuotesHeader(rfq.quotations.length),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            AppButton(
              label: l10n.clearanceQuotesSmartExtractQuoteBtn,
              icon: Icons.auto_awesome,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: onSmartExtract,
            ),
            AppButton(
              label: l10n.clearanceQuotesAddManualQuoteBtn,
              icon: Icons.add,
              size: AppButtonSize.small,
              onPressed: onAddQuote,
            ),
          ],
        ),
      ],
    );
  }

  Widget _quotesTable(BuildContext context, AppLocalizations l10n) {
    DataColumn col(String label, {bool numeric = false}) => DataColumn(
          numeric: numeric,
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
        columns: [
          col(l10n.clearanceQuotesColStatusActions),
          col(l10n.clearanceQuotesColBroker),
          col(l10n.clearanceQuotesColClearanceFee, numeric: true),
          col(l10n.clearanceQuotesColInlandTransport, numeric: true),
          col(l10n.clearanceQuotesColInspectionFee, numeric: true),
          col(l10n.clearanceQuotesColPortExpenses, numeric: true),
          col(l10n.clearanceQuotesColMiscellaneous, numeric: true),
          col(l10n.clearanceQuotesColEstimatedTotal, numeric: true),
          col(l10n.clearanceQuotesColDuration, numeric: true),
        ],
        rows: rfq.quotations.map((q) => _row(context, l10n, q)).toList(),
      ),
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, CustomsClearanceQuotationItemModel q) {
    final isAwarded = q.isAwarded;
    final rowSummary =
        '${q.providerName} | ${l10n.clearanceQuotesColEstimatedTotal}: ${q.totalCost.toStringAsFixed(0)} ${q.currency} | ${l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays)}';

    DataCell money(double v, {bool bold = false, Color? color}) {
      final text = '${CcFormat.money(v)} ${q.currency}';
      return DataCell(CopyableTableCell(
        value: text,
        rowSummary: rowSummary,
        child: LtrText(
          text,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ));
    }

    final days = l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays);

    return DataRow(
      color: isAwarded
          ? WidgetStateProperty.all(AppTheme.severityBackgroundOf(context, AppSeverity.success))
          : null,
      cells: [
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
              tooltip: l10n.copy,
              onPressed: () => CopyHelper.copy(context, rowSummary),
            ),
            if (isAwarded)
              CcStatusChip(
                label: l10n.clearanceQuotesStatusAwardedBadge,
                severity: AppSeverity.success,
                icon: Icons.check,
              )
            else
              AppButton(
                label: l10n.clearanceQuotesAwardAndApproveBtn,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: () => onAward(q.quotationId!),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
              tooltip: l10n.delete,
              onPressed: () => onDeleteQuote(q.quotationId!),
            ),
          ],
        )),
        DataCell(CopyableTableCell(
          value: q.providerName,
          rowSummary: rowSummary,
          child: Text(q.providerName,
              style: TextStyle(fontWeight: isAwarded ? FontWeight.bold : FontWeight.normal)),
        )),
        money(q.clearanceFee),
        money(q.inlandTransportFee),
        money(q.inspectionFee),
        money(q.portExpenses),
        money(q.miscellaneousFee),
        money(q.totalCost,
            bold: true, color: isAwarded ? AppTheme.successForeground : AppTheme.textPrimaryOf(context)),
        DataCell(CopyableTableCell(value: days, rowSummary: rowSummary, child: Text(days))),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge(this.icon, this.label, this.value, {this.color, this.ltr = false});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.bold,
      color: color ?? AppTheme.textPrimaryOf(context),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 5),
        Text('$label ', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context))),
        ltr ? LtrText(value, style: valueStyle) : Text(value, style: valueStyle),
      ],
    );
  }
}
