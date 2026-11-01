import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../settlement_ui.dart';

Color getExpenseCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'freight':
      return AppTheme.cobalt;
    case 'customs':
      return AppTheme.orange;
    case 'clearance':
      return AppTheme.wcagEmerald;
    case 'transport':
      return AppTheme.charcoal;
    case 'storage':
      return AppTheme.wcagOrange;
    default:
      return AppTheme.textSecondary;
  }
}

class LandedCostExpenseTable extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;

  const LandedCostExpenseTable({
    super.key,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return EnterpriseDataTable<Map<String, dynamic>>(
      storageKey: 'LandedCostComparisonExpenses',
      showHeaderToolbar: false,
      showPagination: false,
      initialPageSize: 1000,
      emptyMessage: l10n.noLandedCostDataRegistered,
      columns: [
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'category',
          title: l10n.colExpenseCategory,
          exportValue: (e) {
            final categoryRaw = e['category']?.toString() ?? 'other';
            return DomainEnums.labelIfKnown(l10n, DomainEnumType.clearanceExpenseCategory, categoryRaw) ??
                l10n.expenseCategoryName(categoryRaw);
          },
          cellBuilder: (ctx, e, _) {
            final categoryRaw = e['category']?.toString() ?? 'other';
            final categoryLocalized = DomainEnums.labelIfKnown(l10n, DomainEnumType.clearanceExpenseCategory, categoryRaw) ??
                l10n.expenseCategoryName(categoryRaw);
            return SettlementStatusChip(
              label: categoryLocalized,
              color: getExpenseCategoryColor(categoryRaw),
              dense: true,
            );
          },
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'provider',
          title: l10n.colExpenseProvider,
          exportValue: (e) => e['provider_name']?.toString() ?? '-',
          cellBuilder: (ctx, e, _) => Text(e['provider_name']?.toString() ?? '-'),
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'currency',
          title: l10n.colExpenseCurrency,
          exportValue: (e) => e['currency']?.toString() ?? 'EGP',
          cellBuilder: (ctx, e, _) => Text(e['currency']?.toString() ?? 'EGP'),
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'amount_fx',
          title: l10n.colExpenseAmountFx,
          isNumeric: true,
          exportValue: (e) => (e['amount_fx'] ?? 0).toString(),
          cellBuilder: (ctx, e, _) => SettlementMoneyText((e['amount_fx'] ?? 0).toString()),
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'exchange_rate',
          title: l10n.colExpenseExchangeRate,
          isNumeric: true,
          exportValue: (e) => (e['exchange_rate'] ?? 1).toString(),
          cellBuilder: (ctx, e, _) => SettlementMoneyText((e['exchange_rate'] ?? 1).toString()),
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'amount_egp',
          title: l10n.colExpenseAmountEgp,
          isNumeric: true,
          exportValue: (e) => (e['amount_egp'] ?? 0).toString(),
          cellBuilder: (ctx, e, _) => SettlementMoneyText(
            (e['amount_egp'] ?? 0).toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      data: expenses,
    );
  }
}

class LandedCostItemTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const LandedCostItemTable({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return EnterpriseDataTable<Map<String, dynamic>>(
      storageKey: 'LandedCostComparisonItems',
      showHeaderToolbar: false,
      showPagination: false,
      initialPageSize: 1000,
      emptyMessage: l10n.noLandedCostDataRegistered,
      columns: [
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'item_code',
          title: l10n.colItemCode,
          exportValue: (e) => e['item_code']?.toString() ?? '-',
          cellBuilder: (ctx, e, _) {
            final itemCode = e['item_code']?.toString() ?? '-';
            return LtrText(itemCode, style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'item_name',
          title: l10n.colItemName,
          exportValue: (e) => e['item_name']?.toString() ?? '-',
          cellBuilder: (ctx, e, _) => Text(e['item_name']?.toString() ?? '-'),
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'qty',
          title: l10n.colItemQty,
          isNumeric: true,
          exportValue: (e) => (e['qty'] ?? 0).toString(),
          cellBuilder: (ctx, e, _) => SettlementMoneyText((e['qty'] ?? 0).toString()),
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'fob_unit',
          title: l10n.colFobUnitPrice,
          isNumeric: true,
          exportValue: (e) => ((e['fob_unit_egp'] ?? 0) as num).toStringAsFixed(2),
          cellBuilder: (ctx, e, _) {
            final fobUnit = ((e['fob_unit_egp'] ?? 0) as num).toStringAsFixed(2);
            return SettlementMoneyText(formatSettlementMoney(double.tryParse(fobUnit) ?? 0));
          },
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'unit_landed_cost',
          title: l10n.colLandedUnitPrice,
          isNumeric: true,
          exportValue: (e) => ((e['unit_landed_cost_egp'] ?? 0) as num).toStringAsFixed(2),
          cellBuilder: (ctx, e, _) {
            final landedUnit = ((e['unit_landed_cost_egp'] ?? 0) as num).toStringAsFixed(2);
            return SettlementMoneyText(
              formatSettlementMoney(double.tryParse(landedUnit) ?? 0),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
            );
          },
        ),
        EnterpriseColumn<Map<String, dynamic>>(
          id: 'markup_factor',
          title: l10n.colCostMarkupFactor,
          isNumeric: true,
          exportValue: (e) => '${((e['markup_factor'] ?? 1.0) as num).toDouble().toStringAsFixed(2)}x',
          cellBuilder: (ctx, e, _) {
            final markup = ((e['markup_factor'] ?? 1.0) as num).toDouble();
            final markupText = '${markup.toStringAsFixed(2)}x';
            return SettlementStatusChip(label: markupText, color: AppTheme.charcoal, dense: true);
          },
        ),
      ],
      data: items,
    );
  }
}
