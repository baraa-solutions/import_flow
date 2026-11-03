import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/incoterm_model.dart';
import '../providers/incoterms_provider.dart';

/// تبويب بنود التكلفة للشروط الدولية
class CostItemsTab extends ConsumerWidget {
  final String searchQuery;
  const CostItemsTab({super.key, required this.searchQuery});

  static const List<String> categories = [
    'Freight',
    'Customs',
    'Port',
    'Bank',
    'Other',
  ];

  static String getCategoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Freight':
        return l10n.costCategoryFreight;
      case 'Customs':
        return l10n.costCategoryCustoms;
      case 'Port':
        return l10n.costCategoryPort;
      case 'Bank':
        return l10n.costCategoryBank;
      default:
        return l10n.costCategoryOther;
    }
  }

  static void copyCostItemsTsv(BuildContext context, List<CostItemModel> items) {
    final l10n = context.l10n;
    final headers = [
      l10n.costItemsTsvHeaderCode,
      l10n.costItemsTsvHeaderName,
      l10n.costItemsTsvHeaderCategory,
      l10n.costItemsTsvHeaderDescription,
      l10n.costItemsTsvHeaderStatus,
    ];
    final rows = items.map((i) => [
          i.costItemCode,
          i.costItemName,
          getCategoryLabel(l10n, i.costCategory),
          i.description ?? '',
          i.isActive ? l10n.statusActive : l10n.statusInactive,
        ]);
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.costItemsExportTsvSuccess);
  }

  static void showCostItemDialog(BuildContext context, WidgetRef ref, {CostItemModel? item}) {
    final l10n = context.l10n;
    final codeCtrl = TextEditingController(text: item?.costItemCode ?? '');
    final nameCtrl = TextEditingController(text: item?.costItemName ?? '');
    String selectedCategory = item?.costCategory ?? 'Freight';
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SelectionArea(
          child: AlertDialog(
            title: Text(item == null ? l10n.addCostItemDialogTitle : l10n.editCostItemDialogTitle),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.costItemCodeLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, codeCtrl.text),
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.costItemNameLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, nameCtrl.text),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: selectedCategory,
                      labelText: l10n.costCategoryLabel,
                      items: categories
                          .map((c) => SearchableDropdownItem<String>(value: c, label: getCategoryLabel(l10n, c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.costItemDescriptionLabel,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                          tooltip: l10n.incotermsCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, descCtrl.text),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              AppButton(
                label: l10n.cancel,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
              ),
              AppButton(
                label: item == null ? l10n.addCostItemBtn : l10n.save,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                isLoading: isLoading,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => isLoading = true);
                  final data = {
                    'cost_item_code': codeCtrl.text.trim().toUpperCase(),
                    'cost_item_name': nameCtrl.text.trim(),
                    'cost_category': selectedCategory,
                    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  };
                  String? error;
                  if (item == null) {
                    error = await ref.read(costItemsProvider.notifier).createCostItem(data);
                  } else {
                    error = await ref.read(costItemsProvider.notifier).updateCostItem(item.costItemId, data);
                  }
                  setDialogState(() => isLoading = false);
                  if (ctx.mounted) {
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppTheme.snackBar(context, error, severity: AppSeverity.danger),
                      );
                    } else {
                      Navigator.pop(ctx);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildCostItemSummary(AppLocalizations l10n, CostItemModel item) {
    final b = StringBuffer();
    b.writeln('📋 ${l10n.incotermsTabCostItems}');
    b.writeln('${l10n.costItemCodeBadgeLabel}${item.costItemCode}');
    b.writeln('${l10n.costItemNameCol}: ${item.costItemName}');
    b.writeln('${l10n.costItemCategoryCol}: ${getCategoryLabel(l10n, item.costCategory)}');
    b.writeln('${l10n.costItemStatusCol}: ${item.isActive ? l10n.statusActive : l10n.statusInactive}');
    if (item.description != null && item.description!.isNotEmpty) {
      b.writeln('${l10n.costItemDescriptionLabel}: ${item.description}');
    }
    return b.toString().trim();
  }

  String _buildCostItemRowSummary(AppLocalizations l10n, CostItemModel item) {
    return '${item.costItemCode}\t${item.costItemName}\t${getCategoryLabel(l10n, item.costCategory)}\t${item.description ?? ""}\t${item.isActive ? l10n.statusActive : l10n.statusInactive}';
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Freight':
        return AppTheme.cobalt;
      case 'Customs':
        return AppTheme.orange;
      case 'Port':
        return const Color(0xFF8E44AD);
      case 'Bank':
        return AppTheme.emerald;
      default:
        return Colors.grey;
    }
  }

  Widget _cell({required Widget child}) => TableRowInkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      );

  Widget _buildCostItemTable(BuildContext context, WidgetRef ref, List<CostItemModel> items) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width > 1100
                    ? MediaQuery.of(context).size.width - 300
                    : 950,
              ),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(190),
                  1: FixedColumnWidth(110),
                  2: FlexColumnWidth(2),
                  3: FixedColumnWidth(130),
                  4: FixedColumnWidth(85),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.charcoal),
                    children: [
                      l10n.costItemActionsCol,
                      l10n.costItemCodeCol,
                      l10n.costItemNameCol,
                      l10n.costItemCategoryCol,
                      l10n.costItemStatusCol,
                    ]
                        .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  ...items.asMap().entries.map((entry) {
                    final item = entry.value;
                    final isEven = entry.key % 2 == 0;
                    final catColor = _categoryColor(item.costCategory);
                    return TableRow(
                      decoration: BoxDecoration(
                        color: isEven
                            ? AppTheme.surfaceOf(context)
                            : (AppTheme.isDark(context) ? AppTheme.darkSurface : Colors.grey.shade50),
                      ),
                      children: [
                        _cell(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: l10n.costItemCopySummaryBtn,
                                child: InkWell(
                                  onTap: () => CopyHelper.copy(
                                    context,
                                    _buildCostItemSummary(l10n, item),
                                    customMessage: l10n.costItemCopySummarySuccess,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                    margin: const EdgeInsetsDirectional.only(end: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(
                                      Icons.copy_all_rounded,
                                      size: 15,
                                      color: AppTheme.emerald,
                                    ),
                                  ),
                                ),
                              ),
                              RowActionsPill(
                                onView: () => showCostItemDialog(context, ref, item: item),
                                onEdit: () => showCostItemDialog(context, ref, item: item),
                                onPrint: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    AppTheme.snackBar(
                                      context,
                                      l10n.printCostItemSnack(item.costItemCode, item.costItemName),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                onDelete: () async {
                                  final confirm = await AppConfirmDialog.showToggleActive(
                                    context,
                                    isCurrentlyActive: item.isActive,
                                    message: item.isActive
                                        ? l10n.confirmDeactivateCostItem(item.costItemName)
                                        : l10n.confirmActivateCostItem(item.costItemName),
                                  );
                                  if (confirm) {
                                    ref.read(costItemsProvider.notifier).toggleActive(item.costItemId, item.isActive);
                                  }
                                },
                                deleteTooltip: item.isActive ? l10n.deactivateCostItemTooltip : l10n.activateCostItemTooltip,
                              ),
                            ],
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: item.costItemCode,
                            rowSummary: _buildCostItemRowSummary(l10n, item),
                            child: Tooltip(
                              message: l10n.incotermsCopyFieldTooltip,
                              child: InkWell(
                                onTap: () => CopyHelper.copy(context, item.costItemCode),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.costItemCode,
                                        style: TextStyle(
                                          color: catColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.copy_rounded, size: 11, color: catColor),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: '${item.costItemName}${item.description != null ? " - ${item.description}" : ""}',
                            rowSummary: _buildCostItemRowSummary(l10n, item),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.costItemName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                ),
                                if (item.description != null)
                                  Text(
                                    item.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: getCategoryLabel(l10n, item.costCategory),
                            rowSummary: _buildCostItemRowSummary(l10n, item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                getCategoryLabel(l10n, item.costCategory),
                                style: TextStyle(
                                  color: catColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _cell(
                          child: CopyableTableCell(
                            value: item.isActive ? l10n.statusActive : l10n.statusInactive,
                            rowSummary: _buildCostItemRowSummary(l10n, item),
                            child: AppStatusBadge(
                              label: item.isActive ? l10n.statusActive : l10n.statusInactive,
                              severity: item.isActive ? AppSeverity.success : AppSeverity.danger,
                              size: AppStatusBadgeSize.small,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final costItemsAsync = ref.watch(costItemsProvider);

    return SelectionArea(
      child: costItemsAsync.when(
        loading: () => const AppLoadingState(),
        error: (e, _) => AppErrorState(
          error: e,
          onRetry: () => ref.read(costItemsProvider.notifier).fetchCostItems(),
        ),
        data: (items) {
          final filtered = searchQuery.isEmpty
              ? items
              : items
                  .where((i) =>
                      i.costItemCode.toLowerCase().contains(searchQuery) ||
                      i.costItemName.toLowerCase().contains(searchQuery) ||
                      i.costCategory.toLowerCase().contains(searchQuery))
                  .toList();
          if (filtered.isEmpty) {
            return AppEmptyState(
              icon: Icons.payments_outlined,
              message: l10n.noCostItemsFound,
            );
          }
          return _buildCostItemTable(context, ref, filtered);
        },
      ),
    );
  }
}
