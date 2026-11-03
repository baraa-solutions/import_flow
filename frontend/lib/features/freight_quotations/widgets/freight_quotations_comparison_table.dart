import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';

/// جدول / أعمدة مقارنة عروض أسعار الشحن لموردي النولون والخطوط الملاحية
class FreightQuotationsComparisonTable extends StatelessWidget {
  final List<dynamic> quotations;
  final int? selectedQuotationId;
  final ValueChanged<int>? onSelectQuotation;

  const FreightQuotationsComparisonTable({
    super.key,
    required this.quotations,
    this.selectedQuotationId,
    this.onSelectQuotation,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const emerald = AppTheme.emerald;
    const charcoal = AppTheme.charcoal;
    final gold = Colors.amber.shade700;

    // Determine cheapest id to highlight
    int? cheapestId;
    if (quotations.isNotEmpty) {
      var cheapest = quotations.first;
      for (var q in quotations) {
        if ((q['total_cost'] ?? 0) < (cheapest['total_cost'] ?? 0)) {
          cheapest = q;
        }
      }
      cheapestId = cheapest['quotation_id'];
    }

    return SelectionArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: quotations.map((q) {
          final qId = q['quotation_id'];
          final isSelected = qId == selectedQuotationId;
          final isCheapest = qId == cheapestId;
          final carrierName = (q['provider_name'] ?? l10n.unknownCarrierFallback).toString();

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? emerald : Colors.grey.shade300,
                  width: isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? emerald.withValues(alpha: 0.1)
                          : charcoal.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Column(
                      children: [
                        if (isCheapest)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: gold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              l10n.badgeBestPrice,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => CopyHelper.copy(context, carrierName),
                          child: Tooltip(
                            message: l10n.copyTooltip,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    carrierName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.copy_rounded, size: 14, color: AppTheme.flatCobalt),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildDetailRow(
                          context,
                          l10n.totalFreightCostLabel,
                          '${q['total_cost']} ${q['currency_code']}',
                          bold: true,
                          color: emerald,
                        ),
                        _buildDetailRow(
                          context,
                          l10n.oceanFreightLabel,
                          '${q['ocean_freight_cost']} ${q['currency_code']}',
                        ),
                        _buildDetailRow(
                          context,
                          l10n.localChargesLabel,
                          '${q['local_charges_cost']} ${q['currency_code']}',
                        ),
                        const Divider(),
                        _buildDetailRow(
                          context,
                          l10n.transitDurationLabel,
                          l10n.transitDaysCount(q['transit_days'] ?? 0),
                        ),
                        _buildDetailRow(
                          context,
                          l10n.sailingDateLabel,
                          q['sailing_date']?.toString() ?? '-',
                        ),
                        _buildDetailRow(
                          context,
                          l10n.estimatedArrivalDateLabel,
                          q['estimated_arrival_date']?.toString() ?? '-',
                        ),
                        const Divider(),
                        if (q['remarks'] != null) ...[
                          Text(l10n.remarksLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          CopyableTableCell(
                            value: q['remarks'].toString(),
                            rowSummary: '${l10n.remarksLabel} ${q['remarks']}',
                            child: Text(q['remarks'].toString()),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppButton(
                      label: isSelected ? l10n.quoteAwardedBtn : l10n.awardQuoteBtn,
                      variant: isSelected ? AppButtonVariant.success : AppButtonVariant.primary,
                      size: AppButtonSize.large,
                      onPressed: onSelectQuotation != null && qId != null
                          ? () => onSelectQuotation!(qId as int)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: CopyableTableCell(
        value: value,
        rowSummary: '$label: $value',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppTheme.charcoal,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
