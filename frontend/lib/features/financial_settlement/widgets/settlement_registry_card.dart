import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/buttons/icon_action_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/recalculate_button.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../models/financial_settlement_model.dart';
import '../providers/financial_settlement_provider.dart';
import 'settlement_ui.dart';

/// Localised label of a settlement expense category (code or legacy label).
String settlementCategoryLabel(BuildContext context, String cat) {
  switch (cat) {
    case 'Freight':
      return context.l10n.financialSettlementCategoryFreight;
    case 'Customs Duty':
      return context.l10n.financialSettlementCategoryCustomsDuty;
    case 'Brokerage':
      return context.l10n.financialSettlementCategoryBrokerage;
    case 'Local Transport':
      return context.l10n.financialSettlementCategoryLocalTransport;
    case 'Storage':
      return context.l10n.financialSettlementCategoryStorage;
    default:
      // Clearance invoices carry an expense_category code (or a legacy label).
      return DomainEnums.labelIfKnown(context.l10n, DomainEnumType.clearanceExpenseCategory, cat) ?? cat;
  }
}

/// Localised label of a settlement allocation rule.
String settlementRuleLabel(BuildContext context, String rule) {
  switch (rule) {
    case 'Volume-Based':
      return context.l10n.financialSettlementRuleVolumeBased;
    case 'Value-Based':
      return context.l10n.financialSettlementRuleValueBased;
    case 'Weight-Based':
      return context.l10n.financialSettlementRuleWeightBased;
    case 'Equal':
      return context.l10n.financialSettlementRuleEqual;
    default:
      return rule;
  }
}

/// One settlement in the registry: header, cost summary strip, the expense and
/// item tables, and the row actions. All data changes go through the
/// [financialSettlementProvider] notifier exactly as before.
class SettlementRegistryCard extends ConsumerWidget {
  const SettlementRegistryCard({
    super.key,
    required this.record,
    required this.importFileTitle,
    required this.onOpenJournal,
    required this.onCopyBreakdown,
    required this.onCopyRow,
    required this.onClone,
    required this.onOpenInvoices,
    required this.onOpenActualCost,
  });

  final LandedCostSettlementModel record;
  final String importFileTitle;
  final VoidCallback onOpenJournal;
  final VoidCallback onCopyBreakdown;
  final VoidCallback onCopyRow;
  final VoidCallback onClone;
  final VoidCallback onOpenInvoices;
  final VoidCallback onOpenActualCost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final r = record;
    final egp = l10n.financialSettlementCurrencyEgp;

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        side: BorderSide(color: SettlementTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref, l10n),
            const SizedBox(height: 12),
            SettlementMetricStrips(
              perRow: 4,
              metrics: [
                MetricCardData(
                  title: l10n.financialSettlementMetricFobTotal,
                  value: '${formatSettlementMoney(r.totalFobEgp)} $egp',
                  icon: Icons.inventory_2_outlined,
                  color: AppTheme.charcoal,
                ),
                MetricCardData(
                  title: l10n.financialSettlementMetricExpensesTotal,
                  value: '${formatSettlementMoney(r.totalExpensesEgp)} $egp',
                  icon: Icons.receipt_long_outlined,
                  color: AppTheme.orange,
                ),
                MetricCardData(
                  title: l10n.financialSettlementMetricLandedCostTotal,
                  value: '${formatSettlementMoney(r.totalLandedCostEgp)} $egp',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppTheme.cobalt,
                ),
                MetricCardData(
                  title: l10n.financialSettlementMetricMarkupFactor,
                  value: '${r.averageMarkupFactor.toStringAsFixed(3)}x',
                  icon: Icons.trending_up,
                  color: AppTheme.emerald,
                ),
              ],
            ),
            const SizedBox(height: SettlementTokens.sectionGap),
            SettlementSectionHeader(
              title: l10n.settlementSectionExpenses,
              icon: Icons.receipt_long_outlined,
              color: AppTheme.cobalt,
            ),
            const SizedBox(height: 8),
            _buildExpensesTable(context, l10n, egp),
            const SizedBox(height: SettlementTokens.sectionGap),
            SettlementSectionHeader(
              title: l10n.settlementSectionItems,
              icon: Icons.inventory_2_outlined,
              color: AppTheme.emerald,
            ),
            const SizedBox(height: 8),
            _buildItemsTable(context, l10n, egp),
            const SizedBox(height: 12),
            _buildActions(context, ref, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final r = record;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: CopyableText(
            r.settlementCode,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
          ),
        ),
        CopyableText(
          importFileTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
        ),
        Text(
          l10n.financialSettlementAccountantLabel(r.accountantName),
          style: const TextStyle(fontSize: 12, color: AppTheme.textStrong),
        ),
        settlementStatusChip(context, r.status),
      ],
    );
  }

  Widget _buildExpensesTable(BuildContext context, AppLocalizations l10n, String egp) {
    final r = record;
    return _tableFrame(
      DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 36,
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columns: [
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColInvoiceNo)),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColCategory)),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColProvider)),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColAmountFx), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColExchangeRate), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColAmountEgp), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColAllocationRule)),
        ],
        rows: r.expenseInvoices.map((exp) {
          final category = settlementCategoryLabel(context, exp.category);
          final rule = settlementRuleLabel(context, exp.allocationRule);
          final amountFx = '${formatSettlementMoney(exp.amountFx)} ${exp.currency}';
          final amountEgp = '${formatSettlementMoney(exp.amountEgp)} $egp';
          // Row summary keeps the raw 2-decimals values (copied text, not display).
          final rowSummary =
              '${exp.invoiceNo}\t$category\t${exp.providerName}\t${exp.amountFx.toStringAsFixed(2)} ${exp.currency}\t${exp.exchangeRate}\t${exp.amountEgp.toStringAsFixed(2)} $egp\t$rule';
          return DataRow(cells: [
            DataCell(CopyableTableCell(
              value: exp.invoiceNo,
              rowSummary: rowSummary,
              child: LtrText(exp.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
            DataCell(CopyableTableCell(value: category, rowSummary: rowSummary, child: Text(category))),
            DataCell(CopyableTableCell(value: exp.providerName, rowSummary: rowSummary, child: Text(exp.providerName))),
            DataCell(CopyableTableCell(
              value: amountFx,
              rowSummary: rowSummary,
              child: SettlementMoneyText(amountFx),
            )),
            DataCell(CopyableTableCell(
              value: '${exp.exchangeRate}',
              rowSummary: rowSummary,
              child: SettlementMoneyText('${exp.exchangeRate}'),
            )),
            DataCell(CopyableTableCell(
              value: amountEgp,
              rowSummary: rowSummary,
              child: SettlementMoneyText(
                amountEgp,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
              ),
            )),
            DataCell(CopyableTableCell(
              value: rule,
              rowSummary: rowSummary,
              child: SettlementStatusChip(label: rule, color: AppTheme.textStrong, dense: true),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildItemsTable(BuildContext context, AppLocalizations l10n, String egp) {
    final r = record;
    String money(double v) => '${formatSettlementMoney(v)} $egp';
    return _tableFrame(
      DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        headingRowColor: WidgetStateProperty.all(AppTheme.emerald.withOpacity(0.08)),
        columns: [
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColItemCode)),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColItemName)),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColQty), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColFobUnit), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColAllocatedFreight), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColAllocatedCustoms), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColAllocatedClearance), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColAllocatedTransport), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColUnitLandedCost), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.financialSettlementColMarkupFactor), numeric: true),
        ],
        rows: r.itemLandedCosts.map((itm) {
          String raw(double v) => '${v.toStringAsFixed(2)} $egp';
          final rowSummary =
              '${itm.itemCode}\t${itm.itemName}\t${itm.qtyLabel}\t${raw(itm.fobUnitEgp)}\t${raw(itm.allocatedFreightEgp)}\t${raw(itm.allocatedCustomsEgp)}\t${raw(itm.allocatedClearanceEgp)}\t${raw(itm.allocatedTransportEgp)}\t${raw(itm.unitLandedCostEgp)}\t${itm.markupFactor.toStringAsFixed(3)}x';

          Widget cell(String value, Widget child) =>
              CopyableTableCell(value: value, rowSummary: rowSummary, child: child);

          final unitLanded = money(itm.unitLandedCostEgp);
          final markup = '${itm.markupFactor.toStringAsFixed(3)}x';
          return DataRow(cells: [
            DataCell(cell(itm.itemCode, LtrText(itm.itemCode, style: const TextStyle(fontWeight: FontWeight.bold)))),
            DataCell(cell(itm.itemName, Text(itm.itemName))),
            DataCell(cell(itm.qtyLabel, SettlementMoneyText(itm.qtyLabel))),
            DataCell(cell(money(itm.fobUnitEgp), SettlementMoneyText(money(itm.fobUnitEgp)))),
            DataCell(cell(money(itm.allocatedFreightEgp), SettlementMoneyText(money(itm.allocatedFreightEgp)))),
            DataCell(cell(money(itm.allocatedCustomsEgp), SettlementMoneyText(money(itm.allocatedCustomsEgp)))),
            DataCell(cell(money(itm.allocatedClearanceEgp), SettlementMoneyText(money(itm.allocatedClearanceEgp)))),
            DataCell(cell(money(itm.allocatedTransportEgp), SettlementMoneyText(money(itm.allocatedTransportEgp)))),
            DataCell(cell(
              unitLanded,
              SettlementMoneyText(
                unitLanded,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
              ),
            )),
            DataCell(cell(
              markup,
              SettlementMoneyText(
                markup,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _tableFrame(Widget table) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: SettlementTokens.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final r = record;
    final notifier = ref.read(financialSettlementProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RowActionsPill(
          onView: onOpenJournal,
          onEdit: () {
            notifier.recalculateSettlement(r.settlementId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.financialSettlementRecalculateSuccessSnack(r.settlementCode)),
                backgroundColor: AppTheme.cobalt,
              ),
            );
          },
          onPrint: onCopyBreakdown,
          onDelete: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(l10n.financialSettlementDeleteTitle),
                content: Text(l10n.financialSettlementDeleteMessage),
                actions: [
                  SettlementFit(child: AppButton(
                    label: l10n.cancel,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(c, false),
                  )),
                  SettlementFit(child: AppButton(
                    label: l10n.delete,
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(c, true),
                  )),
                ],
              ),
            );
            if (confirm == true) {
              notifier.softDeleteSettlement(r.settlementId);
            }
          },
          viewTooltip: l10n.financialSettlementViewTooltip,
          editTooltip: l10n.financialSettlementEditTooltip,
          printTooltip: l10n.financialSettlementPrintTooltip,
          deleteTooltip: l10n.financialSettlementDeleteTooltip,
        ),
        RecalculateButton(
          entityType: 'financial_settlement',
          entityId: r.settlementId,
          sourcePage: 'FinancialSettlementRegistry',
          label: l10n.financialSettlementRecalculateBtn,
          onSuccess: (result) {
            ref.invalidate(financialSettlementProvider);
          },
        ),
        IconActionButton(
          key: Key('copySettlementRowBtn_${r.settlementCode}'),
          icon: Icons.copy_all,
          color: AppTheme.cobalt,
          tooltip: l10n.copyFinancialSettlementRowSuccess,
          onTap: onCopyRow,
        ),
        SettlementFit(child: AppButton(
          key: Key('cloneSettlementBtn_${r.settlementCode}'),
          label: l10n.cloneFinancialSettlementTooltip,
          icon: Icons.difference_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onClone,
        )),
        SettlementFit(child: AppButton(
          key: Key('settlementInvoicesBtn_${r.settlementCode}'),
          label: l10n.settlementClo01Btn,
          icon: Icons.receipt_long_rounded,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          onPressed: onOpenInvoices,
        )),
        SettlementFit(child: AppButton(
          key: Key('actualLandedCostBtn_${r.settlementCode}'),
          label: l10n.settlementClo02Btn,
          icon: Icons.calculate_rounded,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: onOpenActualCost,
        )),
        SettlementFit(child: AppButton(
          label: l10n.financialSettlementCopyBreakdownTsvBtn,
          icon: Icons.copy_all,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onCopyBreakdown,
        )),
        SettlementFit(child: AppButton(
          label: l10n.settlementExportOdooBtn,
          icon: Icons.menu_book_outlined,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          onPressed: onOpenJournal,
        )),
      ],
    );
  }
}
