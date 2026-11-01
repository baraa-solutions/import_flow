import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/estimated_landed_cost_model.dart';
import '../settlement_ui.dart';

/// Items breakdown and Expenses breakdown tables for Estimated Landed Cost simulation
class EstLandedCostTables {
  static Widget buildTableFrame(Widget table) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: SettlementTokens.border),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table,
          ),
        ),
      ),
    );
  }

  static Widget buildItemsTable(
    BuildContext context,
    EstimatedLandedCostSimulationModel data,
  ) {
    final l10n = context.l10n;

    if (data.itemsBreakdown.isEmpty) {
      return SettlementStateView.empty(
        message: l10n.settlementEstNoItems,
        icon: Icons.inventory_2_outlined,
      );
    }

    return buildTableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columnSpacing: 16,
        horizontalMargin: 12,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        columns: [
          DataColumn(label: settlementHeadCell(l10n.settlementEstColNo), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColItemCode)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColItemName)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColHs)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColQty), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColFobUnit), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColFobTotal), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColDuty), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColVat), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColFreight), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColTotalLanded), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColUnitLanded), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColUnitLandedFc), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColMarkup), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColMarkupPct), numeric: true),
        ],
        rows: data.itemsBreakdown.map((itm) {
          return DataRow(cells: [
            DataCell(SettlementMoneyText('${itm.lineNo}')),
            DataCell(LtrText(itm.itemCode, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(itm.itemName)),
            DataCell(LtrText(itm.hsCode, style: const TextStyle(fontFamily: 'monospace'))),
            DataCell(SettlementMoneyText('${itm.qty}')),
            DataCell(SettlementMoneyText('${itm.unitPriceFc.toStringAsFixed(2)} ${data.currency}')),
            DataCell(SettlementMoneyText(formatSettlementMoney(itm.fobTotalEgp))),
            DataCell(SettlementMoneyText(formatSettlementMoney(itm.allocatedCustomsDutyEgp))),
            DataCell(SettlementMoneyText(formatSettlementMoney(itm.allocatedVatEgp))),
            DataCell(SettlementMoneyText(formatSettlementMoney(
                itm.allocatedFreightEgp + itm.allocatedClearanceAndPortEgp + itm.allocatedInlandTransportEgp))),
            DataCell(SettlementMoneyText(
              formatSettlementMoney(itm.totalLandedCostEgp),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
            )),
            DataCell(SettlementMoneyText(
              formatSettlementMoney(itm.unitLandedCostEgp),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
            )),
            DataCell(SettlementMoneyText(
              '${itm.unitLandedCostFc.toStringAsFixed(2)} ${data.currency}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            )),
            DataCell(SettlementMoneyText(
              '×${itm.markupFactor.toStringAsFixed(3)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange),
            )),
            DataCell(SettlementMoneyText(
              '+${itm.markupPercent.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  static Widget buildExpensesTable(
    BuildContext context,
    EstimatedLandedCostSimulationModel data,
  ) {
    final l10n = context.l10n;

    if (data.expensesBreakdown.isEmpty) {
      return SettlementStateView.empty(
        message: l10n.settlementEstNoExpenses,
        icon: Icons.receipt_long_outlined,
      );
    }

    return buildTableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columns: [
          DataColumn(label: settlementHeadCell(l10n.settlementEstColExpCategory)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColDescription)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColAmountEgp), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColAmountFc), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColSource)),
          DataColumn(label: settlementHeadCell(l10n.settlementEstColAllocRule)),
        ],
        rows: data.expensesBreakdown.map((exp) {
          return DataRow(cells: [
            DataCell(Text(exp.category, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(exp.description)),
            DataCell(SettlementMoneyText(
              formatSettlementMoney(exp.amountEgp),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            )),
            DataCell(SettlementMoneyText('${exp.amountFc.toStringAsFixed(2)} ${exp.currency}')),
            DataCell(Text(exp.source)),
            DataCell(Text(exp.allocationRule)),
          ]);
        }).toList(),
      ),
    );
  }
}
