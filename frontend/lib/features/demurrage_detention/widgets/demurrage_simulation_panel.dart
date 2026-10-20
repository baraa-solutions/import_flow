import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/demurrage_model.dart';
import 'demurrage_status.dart';

/// Result side of the demurrage simulator: severity banner with the countdown,
/// the three-clock cost summary (right-aligned money) and the tiered breakdown.
class DemurrageSimulationPanel extends StatelessWidget {
  const DemurrageSimulationPanel({super.key, required this.result, required this.onCopyBreakdown});

  final DemurrageSimulationResultModel result;
  final VoidCallback onCopyBreakdown;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(context, l),
        const SizedBox(height: 14),
        _costSummary(context, l),
        const SizedBox(height: 14),
        _breakdown(context, l),
      ],
    );
  }

  Widget _banner(BuildContext context, AppLocalizations l) {
    final severity = DemurrageStatusStyle.ofBadge(result.statusBadge);
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    final text = result.countdownText(l);
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(DemurrageStatusStyle.iconOf(severity), color: fg, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Tooltip(
              message: l.demurrageCopyFieldTooltip,
              child: InkWell(
                onTap: () => CopyHelper.copy(context, text),
                child: Text(
                  text,
                  style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 14, height: 1.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costSummary(BuildContext context, AppLocalizations l) {
    final res = result;
    final totalColor = AppTheme.severityForegroundOf(
      context,
      res.totalCostEgp > 0 ? AppSeverity.danger : AppSeverity.success,
    );
    return CcSectionCard(
      title: l.totalDemurrageCostSummaryTitle,
      icon: Icons.account_balance_wallet_outlined,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final tiles = [
                _CostTile(
                  title: l.demurrageFeeMetric,
                  amount: CcMoneyText(res.demurrageFeeFx, currency: 'USD', fontSize: 16, color: AppTheme.crimson),
                  days: l.daysOverdueFormatted(res.demurrageDaysOverdue),
                  color: AppTheme.crimson,
                ),
                _CostTile(
                  title: l.detentionFeeMetric,
                  amount: CcMoneyText(res.detentionFeeFx, currency: 'USD', fontSize: 16, color: AppTheme.orange),
                  days: l.daysOverdueFormatted(res.detentionDaysOverdue),
                  color: AppTheme.orange,
                ),
                _CostTile(
                  title: l.portStorageFeeMetric,
                  amount: res.storageFeeFx > 0 && res.storageCurrency != 'EGP'
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CcMoneyText(
                              res.storageFeeFx,
                              currency: res.storageCurrency,
                              fontSize: 16,
                              color: AppTheme.cobalt,
                            ),
                            if (res.storageFeeEgp > 0)
                              Text(
                                '(${res.storageFeeEgp.toStringAsFixed(2)} EGP)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                              ),
                          ],
                        )
                      : CcMoneyText(res.storageFeeEgp, fontSize: 16, color: AppTheme.cobalt),
                  days: l.daysOverdueFormatted(res.storageDaysOverdue),
                  color: AppTheme.cobalt,
                ),
              ];
              if (c.maxWidth < 480) {
                return Column(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      tiles[i],
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                ),
              );
            },
          ),
          Divider(height: 28, color: AppTheme.borderOf(context)),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.totalDueComprehensiveCost,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              CcMoneyText(res.totalCostEgp, color: totalColor, fontSize: 22, textAlign: TextAlign.end),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdown(BuildContext context, AppLocalizations l) {
    final res = result;
    final hasTiers = res.storageTierBreakdown.isNotEmpty ||
        res.breakdownDetails.any((b) => (b is Map && (b['tiers_applied'] as List?)?.isNotEmpty == true));
    TextStyle head = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimaryOf(context),
    );
    return CcSectionCard(
      title: l.tieredBreakdownTitle,
      icon: Icons.table_rows_outlined,
      margin: EdgeInsets.zero,
      trailing: AppButton(
        label: l.simBreakdownCopyTsvBtn,
        icon: Icons.copy_all_rounded,
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.small,
        onPressed: onCopyBreakdown,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 460),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
                headingRowHeight: 40,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text(l.colCategory, style: head)),
                  DataColumn(label: Text(l.colConsumedDays, style: head), numeric: true),
                  DataColumn(label: Text(l.colFreeDays, style: head), numeric: true),
                  DataColumn(label: Text(l.colOverdueDays, style: head), numeric: true),
                  DataColumn(label: Text(l.colFeeAmount, style: head), numeric: true),
                ],
                rows: res.breakdownDetails.map((b) {
                  final cat = l.demurrageCategoryLabel(b['category']);
                  final feeStr = b['currency'] == 'EGP'
                      ? l.egpCurrencyAmount((b['fee_egp'] ?? 0).toString())
                      : '${b['fee_fx']} ${b['currency']}';
                  final consumedStr = l.daysCountFormatted(b['days_consumed'] ?? 0);
                  final freeStr = l.daysCountFormatted(b['free_days'] ?? 0);
                  final overdueStr = l.daysCountFormatted(b['days_overdue'] ?? 0);
                  final rowSummary = '$cat | $consumedStr | $freeStr | $overdueStr | $feeStr';
                  final overdue = (b['days_overdue'] ?? 0) > 0;
                  final feeColor = AppTheme.severityForegroundOf(
                    context,
                    overdue ? AppSeverity.danger : AppSeverity.success,
                  );
                  return DataRow(cells: [
                    DataCell(CopyableTableCell(
                      value: cat,
                      rowSummary: rowSummary,
                      child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                    )),
                    DataCell(CopyableTableCell(
                      value: (b['days_consumed'] ?? 0).toString(),
                      rowSummary: rowSummary,
                      child: LtrText(consumedStr),
                    )),
                    DataCell(CopyableTableCell(
                      value: (b['free_days'] ?? 0).toString(),
                      rowSummary: rowSummary,
                      child: LtrText(freeStr),
                    )),
                    DataCell(CopyableTableCell(
                      value: (b['days_overdue'] ?? 0).toString(),
                      rowSummary: rowSummary,
                      child: LtrText(
                        overdueStr,
                        style: TextStyle(
                          fontWeight: overdue ? FontWeight.bold : FontWeight.normal,
                          color: overdue ? feeColor : null,
                        ),
                      ),
                    )),
                    DataCell(CopyableTableCell(
                      value: feeStr,
                      rowSummary: rowSummary,
                      child: LtrText(feeStr, style: TextStyle(fontWeight: FontWeight.bold, color: feeColor)),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
          if (hasTiers) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildTiersBreakdown(context, l),
          ],
        ],
      ),
    );
  }

  Widget _buildTiersBreakdown(BuildContext context, AppLocalizations l) {
    final res = result;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final List<Widget> sections = [];

    for (final b in res.breakdownDetails) {
      if (b is! Map) continue;
      final tiers = (b['tiers_applied'] as List?) ?? [];
      if (tiers.isEmpty) continue;
      final catName = l.demurrageCategoryLabel(b['category']?.toString() ?? '');
      final currency = b['currency']?.toString() ?? 'USD';

      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                catName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tiers.map<Widget>((t) {
                  final tMap = t is Map ? t : <String, dynamic>{};
                  final tierName = tMap['tier_name']?.toString() ?? '';
                  final rate = tMap['rate_per_day'] ?? 0;
                  final days = tMap['days_applied'] ?? 0;
                  final cost = tMap['tier_cost'] ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.borderOf(context)),
                    ),
                    child: Text(
                      '$tierName: $days ${isAr ? "يوم" : "days"} × $rate = $cost $currency',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondaryOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }

    if (sections.isEmpty && res.storageTierBreakdown.isNotEmpty) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.demurrageCategoryLabel('Port Storage'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: res.storageTierBreakdown.map<Widget>((t) {
                final tMap = t is Map ? t : <String, dynamic>{};
                final tierName = tMap['tier_name']?.toString() ?? '';
                final rate = tMap['rate_per_day'] ?? 0;
                final days = tMap['days_applied'] ?? 0;
                final cost = tMap['tier_cost'] ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAltOf(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.borderOf(context)),
                  ),
                  child: Text(
                    '$tierName: $days ${isAr ? "يوم" : "days"} × $rate = $cost ${res.storageCurrency}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondaryOf(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.layers_outlined, size: 16, color: AppTheme.cobalt),
            const SizedBox(width: 6),
            Text(
              isAr ? 'الشرائح الزمنية المطبقة:' : 'Applied Tier Breakdown:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sections,
      ],
    );
  }
}

class _CostTile extends StatelessWidget {
  const _CostTile({required this.title, required this.amount, required this.days, required this.color});

  final String title;
  final Widget amount;
  final String days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: amount),
          const SizedBox(height: 4),
          Text(days, style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context))),
        ],
      ),
    );
  }
}
