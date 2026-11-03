import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/actual_landed_cost_model.dart';
import '../settlement_ui.dart';
import 'actual_landed_cost_summary.dart';

/// Categories breakdown and Items breakdown tables for Actual Landed Cost calculation
class ActualLandedCostTables {
  static Widget buildTableFrame(Widget table) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SettlementTokens.radius),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: SettlementTokens.border),
              borderRadius: BorderRadius.circular(SettlementTokens.radius),
            ),
            child: table,
          ),
        ),
      ),
    );
  }

  static Widget buildCategoriesVarianceTab(
    BuildContext context,
    ActualLandedCostCalculationResponseModel calc,
  ) {
    final l10n = context.l10n;
    if (calc.categoriesBreakdown.isEmpty) {
      return SettlementStateView.empty(
        message: l10n.settlementClo02NoExpenses,
        icon: Icons.receipt_long_outlined,
      );
    }
    final egp = l10n.financialSettlementCurrencyEgp;

    return buildTableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columnSpacing: 18,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
        columns: [
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColExpense)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColEstimated), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColActual), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColVariance), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColPct), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColStatus)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColInvoices), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColSource)),
        ],
        rows: calc.categoriesBreakdown.map((cat) {
          Color statusColor = AppTheme.flatEmerald;
          String statusText = l10n.settlementClo02StatusSaving;
          if (cat.varianceStatus == 'NO_ESTIMATE') {
            statusColor = AppTheme.textSecondary;
            statusText = '-';
          } else if (cat.varianceStatus == 'UNFAVORABLE') {
            statusColor = AppTheme.flatCrimson;
            statusText = l10n.settlementClo02StatusOver;
          } else if (cat.varianceStatus == 'MATCHED') {
            statusColor = AppTheme.flatCobalt;
            statusText = l10n.settlementClo02StatusMatched;
          }

          return DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat.categoryAr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(cat.category, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              DataCell(SettlementMoneyText(
                  cat.estimatedAmountEgp != null
                      ? '${formatSettlementMoney(cat.estimatedAmountEgp!)} $egp'
                      : '-',
                  style: const TextStyle(fontSize: 12))),
              DataCell(SettlementMoneyText('${formatSettlementMoney(cat.actualAmountEgp)} $egp',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataCell(
                SettlementMoneyText(
                  cat.varianceEgp != null
                      ? '${cat.varianceEgp! >= 0 ? '+' : ''}${formatSettlementMoney(cat.varianceEgp!)} $egp'
                      : '-',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
              DataCell(
                SettlementMoneyText(
                  cat.variancePct != null
                      ? formatSettlementPercent(cat.variancePct!)
                      : '-',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              DataCell(SettlementStatusChip(label: statusText, color: statusColor, dense: true)),
              DataCell(SettlementMoneyText('${cat.invoicesCount}', style: const TextStyle(fontSize: 12))),
              DataCell(
                SizedBox(
                  width: 220,
                  child: Text(
                    cat.sourceNote,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textStrong),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  static Widget buildItemsLandedCostTab(
    BuildContext context,
    ActualLandedCostCalculationResponseModel calc,
  ) {
    final l10n = context.l10n;
    if (calc.itemsBreakdown.isEmpty) {
      return SettlementStateView.empty(
        message: l10n.settlementClo02NoItems,
        icon: Icons.inventory_2_outlined,
      );
    }
    final egp = l10n.financialSettlementCurrencyEgp;

    return buildTableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columnSpacing: 16,
        columns: [
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColItemCode)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColItemName)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColHs)),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColQty), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColFobPrice), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColFobTotal), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColAllocated), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColItemTotal), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColUnitActual), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColUnitEstimated), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColUnitVariance), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementClo02ColMarkup), numeric: true),
        ],
        rows: calc.itemsBreakdown.map((item) {
          final varColor = ActualLandedCostSummary.varianceColor(item.varianceStatus);
          final totalExpensesAllocated = item.totalActualLandedCostEgp - item.fobTotalEgp;

          return DataRow(
            cells: [
              DataCell(LtrText(item.itemCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              DataCell(
                SizedBox(
                  width: 140,
                  child: Text(
                    item.itemNameAr,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(LtrText(item.hsCode, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              DataCell(SettlementMoneyText('${item.quantity.toStringAsFixed(0)} ${item.unitOfMeasure}', style: const TextStyle(fontSize: 12))),
              DataCell(SettlementMoneyText('${item.fobUnitPriceFc.toStringAsFixed(2)} ${item.currency}', style: const TextStyle(fontSize: 12))),
              DataCell(SettlementMoneyText('${formatSettlementMoney(item.fobTotalEgp)} $egp', style: const TextStyle(fontSize: 12))),
              DataCell(SettlementMoneyText('${formatSettlementMoney(totalExpensesAllocated)} $egp', style: const TextStyle(fontSize: 12, color: AppTheme.flatOrange))),
              DataCell(SettlementMoneyText('${formatSettlementMoney(item.totalActualLandedCostEgp)} $egp', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataCell(
                SettlementMoneyText(
                  '${formatSettlementMoney(item.actualUnitLandedCostEgp)} $egp',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.flatCobalt),
                ),
              ),
              DataCell(SettlementMoneyText(
                  item.estimatedUnitLandedCostEgp != null
                      ? '${formatSettlementMoney(item.estimatedUnitLandedCostEgp!)} $egp'
                      : '-',
                  style: const TextStyle(fontSize: 12))),
              DataCell(
                SettlementMoneyText(
                  item.unitCostVariancePct != null
                      ? formatSettlementPercent(item.unitCostVariancePct!)
                      : '-',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: varColor),
                ),
              ),
              DataCell(
                SettlementStatusChip(
                  label: '${item.markupFactor.toStringAsFixed(3)}x',
                  color: AppTheme.flatCobalt,
                  dense: true,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
