import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../providers/customs_consultation_provider.dart';
import '../../services/clearance_expense_types_export_service.dart';
import 'clearance_expense_type_dialogs.dart';

class ClearanceExpenseCatalogView extends ConsumerStatefulWidget {
  const ClearanceExpenseCatalogView({super.key});

  @override
  ConsumerState<ClearanceExpenseCatalogView> createState() => _ClearanceExpenseCatalogViewState();
}

class _ClearanceExpenseCatalogViewState extends ConsumerState<ClearanceExpenseCatalogView> {
  String _mgmtExpenseSearch = '';
  String _mgmtExpenseCategory = 'All';
  final ScrollController _catalogVerticalScrollController = ScrollController();
  final ScrollController _catalogHorizontalScrollController = ScrollController();

  @override
  void dispose() {
    _catalogVerticalScrollController.dispose();
    _catalogHorizontalScrollController.dispose();
    super.dispose();
  }

  String _formatCategory(String cat, bool isArabic) {
    if (DomainEnums.legacyToCode(DomainEnumType.brokerExpenseCategory, cat) != null) {
      return DomainEnums.label(context.l10n, DomainEnumType.brokerExpenseCategory, cat);
    }
    if (isArabic) {
      if (cat.contains('(') && cat.contains(')')) {
        final start = cat.indexOf('(') + 1;
        final end = cat.indexOf(')');
        return cat.substring(start, end).trim();
      }
      return cat;
    } else {
      return cat.split('(').first.trim();
    }
  }

  String _formatUnit(String unit, bool isArabic) {
    if (DomainEnums.legacyToCode(DomainEnumType.brokerUnit, unit) != null) {
      return DomainEnums.label(context.l10n, DomainEnumType.brokerUnit, unit);
    }
    if (isArabic) {
      if (unit.contains('(') && unit.contains(')')) {
        final start = unit.indexOf('(') + 1;
        final end = unit.indexOf(')');
        return unit.substring(start, end).trim();
      }
      return unit;
    } else {
      return unit.split('(').first.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final expenseTypesAsync = ref.watch(clearanceExpenseTypesProvider);

    return expenseTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('❌ Error: $e')),
      data: (expenses) {
        final filtered = expenses.where((exp) {
          if (_mgmtExpenseCategory != 'All' &&
              DomainEnums.legacyToCode(DomainEnumType.brokerExpenseCategory, exp.category) !=
                  _mgmtExpenseCategory) {
            return false;
          }
          if (_mgmtExpenseSearch.isNotEmpty) {
            final q = _mgmtExpenseSearch.toLowerCase();
            return exp.expenseCode.toLowerCase().contains(q) ||
                exp.nameAr.toLowerCase().contains(q) ||
                (exp.nameEn?.toLowerCase().contains(q) ?? false);
          }
          return true;
        }).toList();

        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toolbar
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 250,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: l.searchExpenseCatalogHint,
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: _mgmtExpenseSearch.isNotEmpty
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            tooltip: l.copyExpenseRowSummaryTooltip,
                                            onPressed: () => CopyHelper.copy(context, _mgmtExpenseSearch),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.clear, size: 16),
                                            onPressed: () => setState(() => _mgmtExpenseSearch = ''),
                                          ),
                                        ],
                                      )
                                    : null,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() => _mgmtExpenseSearch = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 280,
                            child: SearchableDropdownField<String>(
                              value: _mgmtExpenseCategory,
                              labelText: l.filterCategoryLabel,
                              items: [
                                SearchableDropdownItem(value: 'All', label: l.allCategoriesItem),
                                ...ClearanceExpenseTypeDialogs.brokerCategoryItems(l),
                              ],
                              onChanged: (v) => setState(() => _mgmtExpenseCategory = v ?? 'All'),
                            ),
                          ),
                          const Spacer(),
                          AppButton(
                            label: l.addNewExpenseTypeBtn,
                            icon: Icons.add,
                            variant: AppButtonVariant.primary,
                            onPressed: () => ClearanceExpenseTypeDialogs.showAdd(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Export Action Buttons Bar
                      Row(
                        children: [
                          AppButton(
                            label: l.expenseCatalogExportExcelBtn,
                            icon: Icons.table_view_rounded,
                            variant: AppButtonVariant.success,
                            size: AppButtonSize.small,
                            onPressed: () => ClearanceExpenseTypesExportService.exportExcel(context, filtered),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: l.expenseCatalogExportPdfBtn,
                            icon: Icons.picture_as_pdf_rounded,
                            variant: AppButtonVariant.danger,
                            size: AppButtonSize.small,
                            onPressed: () => ClearanceExpenseTypesExportService.printOrSavePdf(context, filtered),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: l.expenseCatalogExportTsvBtn,
                            icon: Icons.grid_on_rounded,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            onPressed: () => ClearanceExpenseTypesExportService.exportTsv(context, filtered),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: l.expenseCatalogCopyDossierBtn,
                            icon: Icons.copy_all_rounded,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            onPressed: () => ClearanceExpenseTypesExportService.copyDossier(context, filtered),
                          ),
                          const Spacer(),
                          Text(
                            l.expenseCatalogTotalCountLabel(filtered.length),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textStrong,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Table of Expenses
              Expanded(
                child: Card(
                  elevation: 2,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Scrollbar(
                        controller: _catalogVerticalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _catalogVerticalScrollController,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _catalogHorizontalScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            notificationPredicate: (notif) =>
                                notif.depth == 1 || notif.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              controller: _catalogHorizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  columnSpacing: 14,
                                  horizontalMargin: 12,
                                  headingRowHeight: 42,
                                  dataRowMinHeight: 48,
                                  dataRowMaxHeight: 56,
                                  headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                                  headingTextStyle: const TextStyle(
                                    color: AppTheme.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  columns: [
                                    DataColumn(label: Text(context.l10n.actionsCol)),
                                    DataColumn(label: Text(l.expenseCodeCol)),
                                    DataColumn(label: Text(l.expenseNameArCol)),
                                    DataColumn(label: Text(l.expenseNameEnCol)),
                                    DataColumn(label: Text(l.expenseCategoryCol)),
                                    DataColumn(label: Text(l.calculationUnitCol)),
                                    DataColumn(label: Text(l.defaultCurrencyCol)),
                                  ],
                                  rows: filtered.map((exp) {
                                    final rowSummary =
                                        ClearanceExpenseTypesExportService.toRowSummary(exp, l, isArabic: isArabic);
                                    final catText = _formatCategory(exp.category, isArabic);
                                    final unitText = _formatUnit(exp.defaultUnit, isArabic);
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppTheme.charcoalSurface,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.cloudWhite),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit_rounded, size: 17, color: AppTheme.cobalt),
                                                  tooltip: l.editExpenseTooltip,
                                                  splashRadius: 16,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () =>
                                                      ClearanceExpenseTypeDialogs.showEdit(context, ref, exp),
                                                ),
                                                Container(width: 1, height: 16, color: AppTheme.cloudWhite),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded,
                                                      size: 17, color: AppTheme.crimson),
                                                  tooltip: l.deleteExpenseTooltip,
                                                  splashRadius: 16,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () =>
                                                      ClearanceExpenseTypeDialogs.showDeleteConfirm(context, ref, exp),
                                                ),
                                                Container(width: 1, height: 16, color: AppTheme.cloudWhite),
                                                IconButton(
                                                  icon: const Icon(Icons.control_point_duplicate_rounded,
                                                      size: 16, color: AppTheme.cobalt),
                                                  tooltip: l.cloneRowTooltip,
                                                  splashRadius: 16,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () =>
                                                      ClearanceExpenseTypeDialogs.showAdd(context, ref, template: exp),
                                                ),
                                                Container(width: 1, height: 16, color: AppTheme.cloudWhite),
                                                IconButton(
                                                  icon: const Icon(Icons.copy_rounded,
                                                      size: 16, color: AppTheme.textMuted),
                                                  tooltip: l.copyExpenseRowSummaryTooltip,
                                                  splashRadius: 16,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () => CopyHelper.copy(context, rowSummary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: exp.expenseCode,
                                            rowSummary: rowSummary,
                                            child: InkWell(
                                              onTap: () => CopyHelper.copy(context, exp.expenseCode),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.cobalt.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(exp.expenseCode,
                                                        style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.cobalt,
                                                            fontSize: 12)),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.copy_rounded,
                                                        size: 12, color: AppTheme.cobalt),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 220),
                                            child: CopyableTableCell(
                                              value: exp.nameAr,
                                              rowSummary: rowSummary,
                                              child: Text(
                                                exp.nameAr,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 220),
                                            child: CopyableTableCell(
                                              value: exp.nameEn ?? '-',
                                              rowSummary: rowSummary,
                                              child: Text(
                                                exp.nameEn ?? '-',
                                                style: const TextStyle(fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 160),
                                            child: CopyableTableCell(
                                              value: catText,
                                              rowSummary: rowSummary,
                                              child: Text(
                                                catText,
                                                style: const TextStyle(fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 130),
                                            child: CopyableTableCell(
                                              value: unitText,
                                              rowSummary: rowSummary,
                                              child: Text(
                                                unitText,
                                                style: const TextStyle(fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          CopyableTableCell(
                                            value: exp.defaultCurrency ?? '-',
                                            rowSummary: rowSummary,
                                            child: Text(
                                              exp.defaultCurrency ?? '-',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600, fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
