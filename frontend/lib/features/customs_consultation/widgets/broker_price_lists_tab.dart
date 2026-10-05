import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/customs_consultation_model.dart';
import '../providers/customs_consultation_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart';
import '../services/clearance_expense_types_export_service.dart';
import 'price_list_form_dialog.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../../../core/localization/domain_enum_labels.dart';

class BrokerPriceListsTab extends ConsumerStatefulWidget {
  const BrokerPriceListsTab({super.key});

  @override
  ConsumerState<BrokerPriceListsTab> createState() => _BrokerPriceListsTabState();
}

class _BrokerPriceListsTabState extends ConsumerState<BrokerPriceListsTab> {
  int? _selectedMgmtBrokerId;
  String _mgmtExpenseSearch = '';
  String _mgmtExpenseCategory = 'All';
  int _managementSubTabIndex = 0;
  final ScrollController _catalogVerticalScrollController = ScrollController();
  final ScrollController _catalogHorizontalScrollController = ScrollController();

  @override
  void dispose() {
    _catalogVerticalScrollController.dispose();
    _catalogHorizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(allPartnersProvider).isLoading) {
        ref.read(allPartnersProvider.notifier).fetchPartners();
      }
      if (!ref.read(partnersProvider).isLoading) {
        ref.read(partnersProvider.notifier).fetchPartners();
      }
      if (!ref.read(brokerPriceListsProvider).isLoading) {
        ref.read(brokerPriceListsProvider.notifier).fetchPriceLists();
      }
      if (!ref.read(clearanceExpenseTypesProvider).isLoading) {
        ref.read(clearanceExpenseTypesProvider.notifier).fetchExpenseTypes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildPriceListsAndCatalogTab();
  }

  Widget _buildPriceListsAndCatalogTab() {
    final l = context.l10n;
    final priceListsAsync = ref.watch(brokerPriceListsProvider);
    final expenseTypesAsync = ref.watch(clearanceExpenseTypesProvider);
    final allPartners = ref.watch(allPartnersProvider).valueOrNull ?? ref.watch(partnersProvider).valueOrNull ?? [];
    final brokersList = allPartners
        .where((p) => p.partnerType.toLowerCase().contains('customs broker') || p.partnerType.toLowerCase().contains('مخلص'))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-Tab Switcher (Segmented Control)
          Row(
            children: [
              ChoiceChip(
                label: Text(l.brokerPriceListsTab, style: const TextStyle(fontWeight: FontWeight.bold)),
                selected: _managementSubTabIndex == 0,
                selectedColor: AppTheme.cobalt.withOpacity(0.18),
                onSelected: (_) => setState(() => _managementSubTabIndex = 0),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text(l.clearanceQuotesTab, style: const TextStyle(fontWeight: FontWeight.bold)),
                selected: _managementSubTabIndex == 1,
                selectedColor: AppTheme.cobalt.withOpacity(0.18),
                onSelected: (_) => setState(() => _managementSubTabIndex = 1),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text(l.smartClearanceQuoteExtractor, style: const TextStyle(fontWeight: FontWeight.bold)),
                selected: _managementSubTabIndex == 2,
                selectedColor: const Color(0xFF6C5CE7).withOpacity(0.18),
                onSelected: (_) => setState(() => _managementSubTabIndex = 2),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-Tab Content
          Expanded(
            child: _managementSubTabIndex == 0
                ? _buildBrokerPriceListsView(priceListsAsync, brokersList)
                : (_managementSubTabIndex == 1
                    ? _buildExpenseCatalogView(expenseTypesAsync)
                    : const CustomsClearanceQuotationsScreen(embedded: true)),
          ),
        ],
      ),
    );
  }
  Widget _buildBrokerPriceListsView(AsyncValue<List<BrokerPriceListModel>> priceListsAsync, List<dynamic> brokersList) {
    final l = context.l10n;
    return priceListsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('❌ Error: $e')),
      data: (priceLists) {
        final filteredLists = priceLists.where((pl) {
          if (_selectedMgmtBrokerId != null && pl.brokerId != _selectedMgmtBrokerId) return false;
          return true;
        }).toList();

        return Column(
          children: [
            // Filter Bar
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: SearchableDropdownField<int?>(
                        value: _selectedMgmtBrokerId,
                        labelText: l.filterByBroker,
                        searchHintText: l.searchBrokerHint,
                        items: [
                          SearchableDropdownItem(value: null, label: l.allBrokers),
                          ...brokersList.map((b) => SearchableDropdownItem<int?>(
                                value: b.providerId,
                                label: b.partnerName,
                              )),
                        ],
                        onChanged: (v) => setState(() => _selectedMgmtBrokerId = v),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text('🤖 ${l.smartClearanceQuoteExtractor}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => showSmartClearanceExtractorDialog(context, ref),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                      onPressed: () => showPriceListFormDialog(context, ref, brokersList: brokersList),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(l.createBrokerPriceListBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Price Lists Table / Grid
            Expanded(
              child: filteredLists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(l.noBrokerPriceListsFound, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => showPriceListFormDialog(context, ref, brokersList: brokersList),
                            icon: const Icon(Icons.add),
                            label: Text(l.addPriceListNowBtn),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredLists.length,
                      itemBuilder: (ctx, idx) {
                        final pl = filteredLists[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppTheme.cobalt.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.price_change, color: AppTheme.cobalt),
                            ),
                            title: Row(
                              children: [
                                Text(pl.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: pl.isActive ? Colors.green.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text(pl.isActive ? l.activePriceListStatus : l.archivedPriceListStatus, style: TextStyle(color: pl.isActive ? Colors.green.shade900 : Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                if (pl.clonedFromCode != null && pl.clonedFromCode!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      l.clonedFromBadge(pl.clonedFromCode!),
                                      style: const TextStyle(
                                        color: AppTheme.cobalt,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.cobalt,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => showPriceListFormDialog(context, ref, existingPriceList: pl, brokersList: brokersList),
                                  icon: const Icon(Icons.edit, color: Colors.white, size: 14),
                                  label: Text(l.editPricesAndItemsBtn, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 20),
                                  tooltip: l.clonePriceListActionTooltip,
                                  onPressed: () {
                                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                    CloneEntityReviewDialog.show(
                                      context,
                                      entityType: l.clonePriceListDialogTitle,
                                      sourceCode: pl.priceListCode,
                                      suggestedNewCode: '${pl.priceListCode}-CLONE',
                                      sourceTitle: pl.title,
                                      copiedFieldsSummary: {
                                        isAr ? 'المخلص الجمركي' : 'Customs Broker': pl.brokerName,
                                        isAr ? 'ميناء التخليص' : 'Target Port': pl.portName ?? '-',
                                        isAr ? 'عدد بنود الأسعار' : 'Items Count': '${pl.items.length}',
                                        isAr ? 'تاريخ السريان' : 'Effective From': pl.effectiveFrom,
                                      },
                                      mandatorilyResetFields: [
                                        l.cloneFieldStatusDraftBadge,
                                        isAr ? 'تحديث رقم الإصدار تلقائياً (الإصدار الجديد)' : 'Increment version number',
                                        isAr ? 'توليد كود مرجعي فريد غير مكرر' : 'Generate unique new reference code',
                                      ],
                                      allowCopyLineItems: true,
                                      allowCopyAttachments: false,
                                      initialCopyLineItems: true,
                                      initialCopyAttachments: false,
                                      onConfirm: ({
                                        required String newCode,
                                        required String newTitle,
                                        required bool copyLineItems,
                                        required bool copyAttachments,
                                        String? notes,
                                      }) async {
                                        final sm = ScaffoldMessenger.of(context);
                                        await ref.read(brokerPriceListsProvider.notifier).clonePriceList(
                                          pl.priceListId,
                                          {
                                            'new_price_list_code': newCode,
                                            'new_title': newTitle,
                                            'copy_items': copyLineItems,
                                            if (notes != null) 'notes': notes,
                                          },
                                        );
                                        sm.showSnackBar(
                                          SnackBar(
                                            content: Text(l.clonedSuccessfullyToast(newCode)),
                                            backgroundColor: AppTheme.emerald,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: l.archivePriceListTooltip,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(l.confirmArchivePriceListTitle),
                                        content: Text(l.confirmArchivePriceListMsg(pl.title)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: Text(l.archiveBtn, style: const TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref.read(brokerPriceListsProvider.notifier).softDeletePriceList(pl.priceListId);
                                    }
                                  },
                                ),
                              ],
                            ),
                            subtitle: Text('${l.responsibleCustomsBroker}: ${pl.brokerName} | ${l.targetPortField}: ${pl.portName ?? "-"} | ${pl.effectiveFrom} | ${pl.items.length}'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (pl.notes != null && pl.notes!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber.shade200)),
                                        child: Text('📝 ${l.priceListNotesHeader} ${pl.notes}', style: const TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Table(
                                      border: TableBorder.all(color: Colors.grey.shade300),
                                      columnWidths: const {
                                        0: FlexColumnWidth(3.0),
                                        1: FlexColumnWidth(2.0),
                                        2: FlexColumnWidth(1.2),
                                        3: FlexColumnWidth(1.5),
                                        4: FlexColumnWidth(2.0),
                                      },
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(color: AppTheme.charcoal.withOpacity(0.08)),
                                          children: [
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.expenseItemNameCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.expenseCategoryCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.expenseUnitCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.standardPriceCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.priceRangeAndNotesCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          ],
                                        ),
                                        ...pl.items.map((itm) => TableRow(
                                              children: [
                                                Padding(padding: const EdgeInsets.all(6), child: Text(itm.expenseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(itm.category.split('(').first.trim(), style: const TextStyle(fontSize: 10))),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(itm.unitType, style: const TextStyle(fontSize: 10))),
                                                Padding(padding: const EdgeInsets.all(6), child: Text('${itm.standardPrice.toStringAsFixed(2)} ${itm.currency}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 11))),
                                                Padding(
                                                  padding: const EdgeInsets.all(6),
                                                  child: Text(
                                                    itm.minPrice != null && itm.maxPrice != null
                                                        ? '${itm.minPrice!.toStringAsFixed(0)} - ${itm.maxPrice!.toStringAsFixed(0)} ${itm.currency}'
                                                        : (itm.notes ?? '-'),
                                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                  ),
                                                ),
                                              ],
                                            )),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
  /// Category picker items: the stored value is the code, the label follows the UI language.
  List<SearchableDropdownItem<String>> _brokerCategoryItems(AppLocalizations l, [String? current]) {
    final codes = DomainEnums.codesOf(DomainEnumType.brokerExpenseCategory);
    return [
      for (final code in codes)
        SearchableDropdownItem(value: code, label: DomainEnums.label(l, DomainEnumType.brokerExpenseCategory, code)),
      if (current != null && current.isNotEmpty && current != 'All' && !codes.contains(current))
        SearchableDropdownItem(value: current, label: current),
    ];
  }

  /// Unit picker items (codes). A legacy free-text unit that is not a known
  /// code stays selectable as-is so editing an old row does not change it.
  List<SearchableDropdownItem<String>> _brokerUnitItems(AppLocalizations l, String current) {
    final codes = DomainEnums.codesOf(DomainEnumType.brokerUnit);
    return [
      for (final code in codes)
        SearchableDropdownItem(value: code, label: DomainEnums.label(l, DomainEnumType.brokerUnit, code)),
      if (current.isNotEmpty && !codes.contains(current)) SearchableDropdownItem(value: current, label: current),
    ];
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

  Widget _buildExpenseCatalogView(AsyncValue<List<ClearanceExpenseTypeModel>> expenseTypesAsync) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return expenseTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('❌ Error: $e')),
      data: (expenses) {
        final filtered = expenses.where((exp) {
          if (_mgmtExpenseCategory != 'All' &&
              DomainEnums.legacyToCode(DomainEnumType.brokerExpenseCategory, exp.category) != _mgmtExpenseCategory) {
            return false;
          }
          if (_mgmtExpenseSearch.isNotEmpty) {
            final q = _mgmtExpenseSearch.toLowerCase();
            return exp.expenseCode.toLowerCase().contains(q) || exp.nameAr.toLowerCase().contains(q) || (exp.nameEn?.toLowerCase().contains(q) ?? false);
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
                                ..._brokerCategoryItems(l),
                              ],
                              onChanged: (v) => setState(() => _mgmtExpenseCategory = v ?? 'All'),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                            onPressed: _showAddExpenseTypeDialog,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: Text(l.addNewExpenseTypeBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Export Action Buttons Bar
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.table_view_rounded, size: 16),
                            label: Text(l.expenseCatalogExportExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => ClearanceExpenseTypesExportService.exportExcel(context, filtered),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                            label: Text(l.expenseCatalogExportPdfBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => ClearanceExpenseTypesExportService.printOrSavePdf(context, filtered),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.grid_on_rounded, size: 16),
                            label: Text(l.expenseCatalogExportTsvBtn, style: const TextStyle(fontSize: 12)),
                            onPressed: () => ClearanceExpenseTypesExportService.exportTsv(context, filtered),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.copy_all_rounded, size: 16),
                            label: Text(l.expenseCatalogCopyDossierBtn, style: const TextStyle(fontSize: 12)),
                            onPressed: () => ClearanceExpenseTypesExportService.copyDossier(context, filtered),
                          ),
                          const Spacer(),
                          Text(
                            l.expenseCatalogTotalCountLabel(filtered.length),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Table of Expenses (Responsive & Proportionate)
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
                            notificationPredicate: (notif) => notif.depth == 1 || notif.metrics.axis == Axis.horizontal,
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
                                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  columns: [
                                    DataColumn(label: Text(isArabic ? 'الإجراءات' : 'Actions')),
                                    DataColumn(label: Text(l.expenseCodeCol)),
                                    DataColumn(label: Text(l.expenseNameArCol)),
                                    DataColumn(label: Text(l.expenseNameEnCol)),
                                    DataColumn(label: Text(l.expenseCategoryCol)),
                                    DataColumn(label: Text(l.calculationUnitCol)),
                                    DataColumn(label: Text(l.defaultCurrencyCol)),
                                  ],
                                  rows: filtered.map((exp) {
                                    final rowSummary = ClearanceExpenseTypesExportService.toRowSummary(exp, l, isArabic: isArabic);
                                    final catText = _formatCategory(exp.category, isArabic);
                                    final unitText = _formatUnit(exp.defaultUnit, isArabic);
                                    return DataRow(
                                      cells: [
                                        // 2. Actions (Edit, Delete, Copy) - Prominently Placed in 2nd Column
                                        DataCell(
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade300),
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
                                                  onPressed: () => _showEditExpenseTypeDialog(exp),
                                                ),
                                                Container(width: 1, height: 16, color: Colors.grey.shade300),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                                                  tooltip: l.deleteExpenseTooltip,
                                                  splashRadius: 16,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () => _showDeleteExpenseTypeConfirmDialog(exp),
                                                ),
                                                Container(width: 1, height: 16, color: Colors.grey.shade300),
                                                IconButton(
                                                  icon: const Icon(Icons.control_point_duplicate_rounded, size: 16, color: AppTheme.cobalt),
                                                  tooltip: l.cloneRowTooltip,
                                                  splashRadius: 16,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () => _showAddExpenseTypeDialog(template: exp),
                                                ),
                                                Container(width: 1, height: 16, color: Colors.grey.shade300),
                                                IconButton(
                                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
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
                                        // 1. Code with Clickable Copy Badge
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
                                                  color: AppTheme.cobalt.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(exp.expenseCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12)),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 3. Name Ar
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 220),
                                            child: CopyableTableCell(
                                              value: exp.nameAr,
                                              rowSummary: rowSummary,
                                              child: Text(
                                                exp.nameAr,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 4. Name En
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
                                        // 5. Category
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
                                        // 6. Calculation Unit
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
                                        // 7. Default Currency
                                        DataCell(
                                          CopyableTableCell(
                                            value: exp.defaultCurrency,
                                            rowSummary: rowSummary,
                                            child: Text(
                                              exp.defaultCurrency,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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

  void _showEditExpenseTypeDialog(ClearanceExpenseTypeModel exp) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: exp.expenseCode);
    final nameArCtrl = TextEditingController(text: exp.nameAr);
    final nameEnCtrl = TextEditingController(text: exp.nameEn ?? '');
    String category = DomainEnums.initialCode(DomainEnumType.brokerExpenseCategory, exp.category, exp.category);
    String defaultUnit = DomainEnums.initialCode(DomainEnumType.brokerUnit, exp.defaultUnit, exp.defaultUnit);
    String currency = exp.defaultCurrency;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Text(l.editExpenseTypeDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseCodeField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'يرجى إدخال الكود' : 'Code required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameArCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseNameArField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'يرجى إدخال الاسم العربي' : 'Arabic name required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameEnCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseNameEnField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: category,
                      labelText: l.categoryCol,
                      items: [
                        ..._brokerCategoryItems(l, category),
                      ],
                      onChanged: (v) => setDlgState(() => category = v ?? category),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: defaultUnit,
                            labelText: l.defaultCalculationUnitField,
                            items: _brokerUnitItems(l, defaultUnit),
                            onChanged: (v) => setDlgState(() => defaultUnit = v ?? defaultUnit),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: currency,
                            labelText: l.defaultCurrencyCol,
                            items: const [
                              SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                              SearchableDropdownItem(value: 'USD', label: 'USD'),
                              SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                            ],
                            onChanged: (v) => setDlgState(() => currency = v ?? 'EGP'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref.read(clearanceExpenseTypesProvider.notifier).updateExpenseType(
                          exp.expenseId,
                          {
                            'expense_code': codeCtrl.text.trim(),
                            'name_ar': nameArCtrl.text.trim(),
                            'name_en': nameEnCtrl.text.trim().isNotEmpty ? nameEnCtrl.text.trim() : null,
                            'category': category,
                            'default_unit': defaultUnit,
                            'default_currency': currency,
                            'display_order': exp.displayOrder,
                            'is_active': exp.isActive,
                          },
                        );
                        ref.invalidate(clearanceExpenseTypesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l.expenseTypeUpdatedToast),
                            backgroundColor: AppTheme.emerald,
                          ),
                        );
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.saveExpenseBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteExpenseTypeConfirmDialog(ClearanceExpenseTypeModel exp) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text(l.confirmDeleteExpenseTypeTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            l.confirmDeleteExpenseTypeMsg(exp.nameAr, exp.expenseCode),
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDlgState(() => isDeleting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref.read(clearanceExpenseTypesProvider.notifier).deleteExpenseType(exp.expenseId);
                        ref.invalidate(clearanceExpenseTypesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l.expenseTypeDeletedToast),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } catch (e) {
                        setDlgState(() => isDeleting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isDeleting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseTypeDialog({ClearanceExpenseTypeModel? template}) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: TableRowCloneHelper.withCodeSuffix(template?.expenseCode) ?? '');
    final nameArCtrl = TextEditingController(text: TableRowCloneHelper.withCopySuffix(template?.nameAr) ?? '');
    final nameEnCtrl = TextEditingController(text: TableRowCloneHelper.withCopySuffix(template?.nameEn) ?? '');
    String category = DomainEnums.initialCode(
        DomainEnumType.brokerExpenseCategory, template?.category, template?.category ?? 'CLEARANCE_FEES');
    String defaultUnit =
        DomainEnums.initialCode(DomainEnumType.brokerUnit, template?.defaultUnit, template?.defaultUnit ?? 'PER_INVOICE');
    String currency = template?.defaultCurrency ?? 'EGP';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            template != null
                ? (isArabic ? 'استنساخ بند المصروف المرجعي' : 'Clone Clearance Expense Item')
                : l.newExpenseTypeDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseCodeField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'يرجى إدخال الكود' : 'Code required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameArCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseNameArField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'يرجى إدخال الاسم العربي' : 'Arabic name required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameEnCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseNameEnField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: category,
                      labelText: l.categoryCol,
                      items: [
                        ..._brokerCategoryItems(l, category),
                      ],
                      onChanged: (v) => setDlgState(() => category = v ?? category),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: defaultUnit,
                            labelText: l.defaultCalculationUnitField,
                            items: _brokerUnitItems(l, defaultUnit),
                            onChanged: (v) => setDlgState(() => defaultUnit = v ?? defaultUnit),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: currency,
                            labelText: l.defaultCurrencyCol,
                            items: const [
                              SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                              SearchableDropdownItem(value: 'USD', label: 'USD'),
                              SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                            ],
                            onChanged: (v) => setDlgState(() => currency = v ?? 'EGP'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() => isSaving = true);
                      try {
                        await ref.read(clearanceExpenseTypesProvider.notifier).createExpenseType({
                          'expense_code': codeCtrl.text.trim(),
                          'name_ar': nameArCtrl.text.trim(),
                          'name_en': nameEnCtrl.text.trim().isNotEmpty ? nameEnCtrl.text.trim() : null,
                          'category': category,
                          'default_unit': defaultUnit,
                          'default_currency': currency,
                          'display_order': 99,
                          'is_active': true,
                        });
                        ref.invalidate(clearanceExpenseTypesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.saveExpenseBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
