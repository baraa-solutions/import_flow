import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../../customs_clearance_quotations/models/customs_clearance_quotation_model.dart';

class BrokerQuoteDataTable extends StatelessWidget {
  final List<CustomsClearanceQuotationItemModel> quotes;
  final int? lowestCostId;
  final int? selectedBrokerId;
  final void Function(int quotationId)? onAward;
  final void Function(int quotationId)? onDeleteQuote;
  final void Function(CustomsClearanceQuotationItemModel quote)? onSelectQuote;

  const BrokerQuoteDataTable({
    super.key,
    required this.quotes,
    this.lowestCostId,
    this.selectedBrokerId,
    this.onAward,
    this.onDeleteQuote,
    this.onSelectQuote,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    DataColumn col(String label, {bool numeric = false}) => DataColumn(
          numeric: numeric,
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        headingRowHeight: 40,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 52,
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
        rows: quotes.map((q) => _buildRow(context, l10n, q)).toList(),
      ),
    );
  }

  DataRow _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    CustomsClearanceQuotationItemModel q,
  ) {
    final isAwarded = q.isAwarded;
    final isLowest = q.quotationId != null && q.quotationId == lowestCostId;
    final isSelected = selectedBrokerId != null && q.providerId == selectedBrokerId;

    final rowSummary =
        '${q.providerName} | ${l10n.clearanceQuotesColEstimatedTotal}: ${q.totalCost.toStringAsFixed(0)} ${q.currency} | ${l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays)}';

    DataCell moneyCell(double value, {bool isTotal = false}) {
      final text = '${CcFormat.money(value)} ${q.currency}';
      return DataCell(
        CopyableTableCell(
          value: text,
          rowSummary: rowSummary,
          child: LtrText(
            text,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 13 : 12,
              color: isAwarded
                  ? AppTheme.wcagEmerald
                  : (isLowest && isTotal ? AppTheme.emerald : AppTheme.textPrimaryOf(context)),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    final days = l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays);

    return DataRow(
      color: isAwarded
          ? WidgetStateProperty.all(AppTheme.severityBackgroundOf(context, AppSeverity.success))
          : (isSelected ? WidgetStateProperty.all(AppTheme.cobaltLight.withValues(alpha: 0.5)) : null),
      cells: [
        // Status & Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                tooltip: l10n.copy,
                onPressed: () => CopyHelper.copy(
                  context,
                  rowSummary,
                  customMessage: l10n.clearanceQuotesCopyRowSuccess,
                ),
              ),
              if (isAwarded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 14, color: AppTheme.wcagEmerald),
                      const SizedBox(width: 4),
                      Text(
                        l10n.clearanceQuotesStatusAwardedBadge,
                        style: const TextStyle(
                          color: AppTheme.wcagEmerald,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (onAward != null && q.quotationId != null)
                AppButton(
                  label: l10n.clearanceQuotesAwardAndApproveBtn,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => onAward!(q.quotationId!),
                ),
              if (onSelectQuote != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.cobalt),
                  tooltip: l10n.apply,
                  onPressed: () => onSelectQuote!(q),
                ),
              ],
              if (onDeleteQuote != null && q.quotationId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                  tooltip: l10n.delete,
                  onPressed: () => onDeleteQuote!(q.quotationId!),
                ),
            ],
          ),
        ),

        // Broker Name & License
        DataCell(
          CopyableTableCell(
            value: q.providerName,
            rowSummary: rowSummary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      q.providerName,
                      style: TextStyle(
                        fontWeight: isAwarded ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    if (isLowest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.emeraldBorder),
                        ),
                        child: Text(
                          l10n.clearanceQuotesBadgeLowestCost,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.wcagEmerald,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (q.licenseNumber != null && q.licenseNumber!.isNotEmpty)
                  Text(
                    q.licenseNumber!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Fees
        moneyCell(q.clearanceFee),
        moneyCell(q.inlandTransportFee),
        moneyCell(q.inspectionFee),
        moneyCell(q.portExpenses),
        moneyCell(q.miscellaneousFee),

        // Estimated Total
        moneyCell(q.totalCost, isTotal: true),

        // Duration / Turnaround
        DataCell(
          CopyableTableCell(
            value: days,
            rowSummary: rowSummary,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.charcoalSurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                days,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
