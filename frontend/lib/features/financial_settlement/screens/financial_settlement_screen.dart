import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/buttons/icon_action_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/financial_settlement_model.dart';
import '../providers/financial_settlement_provider.dart';
import '../widgets/actual_landed_cost_dialog.dart';
import '../widgets/final_settlement_invoices_dialog.dart';
import '../widgets/search_and_clone_financial_settlement_dialog.dart';
import '../widgets/settlement_form_dialog.dart';
import '../widgets/settlement_registry_card.dart';
import '../widgets/settlement_ui.dart';
import 'landed_cost_comparison_screen.dart';
import 'odoo_journal_entry_dialog.dart';
import '../../logistics_invoices/screens/logistics_invoices_screen.dart';

class FinancialSettlementScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  const FinancialSettlementScreen({super.key, this.initialSubTab = 0});

  @override
  ConsumerState<FinancialSettlementScreen> createState() => _FinancialSettlementScreenState();
}

class _FinancialSettlementScreenState extends ConsumerState<FinancialSettlementScreen> {
  final TextEditingController _searchController = TextEditingController();
  late int _selectedTab;
  final Set<int> _visitedTabs = {};

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialSubTab;
    _visitedTabs.add(_selectedTab);
    Future.microtask(() {
      if (!ref.read(financialSettlementProvider).isLoading) {
        ref.read(financialSettlementProvider.notifier).fetchSettlements();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  @override
  void didUpdateWidget(covariant FinancialSettlementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubTab != oldWidget.initialSubTab) {
      setState(() {
        _selectedTab = widget.initialSubTab;
        _visitedTabs.add(_selectedTab);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reloadSettlements() {
    if (!ref.read(financialSettlementProvider).isLoading) {
      ref.read(financialSettlementProvider.notifier).fetchSettlements();
    }
  }

  void _showAddDialog({LandedCostSettlementModel? initialRecord, bool isCloneDraft = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SettlementFormDialog(
        initialRecord: initialRecord,
        isCloneDraft: isCloneDraft,
      ),
    );
  }

  void _openSearchAndCloneDialog(List<LandedCostSettlementModel> records) {
    showDialog(
      context: context,
      builder: (c) => SearchAndCloneFinancialSettlementDialog(
        records: records,
        onSelectRecord: (selected) => _onCloneSettlement(selected),
      ),
    );
  }

  void _onCloneSettlement(LandedCostSettlementModel source) {
    // A clone must target a different import file; the backend generates the
    // code, status and totals, so nothing is fabricated on the client.
    final clonedExpenses = source.expenseInvoices
        .map((e) => ExpenseInvoiceModel(
              invoiceNo: '${e.invoiceNo}-DRAFT',
              category: e.category,
              providerName: e.providerName,
              currency: e.currency,
              amountFx: e.amountFx,
              exchangeRate: e.exchangeRate,
              allocationRule: e.allocationRule,
            ))
        .toList();
    final clonedItems = source.itemLandedCosts
        .map((i) => ItemLandedCostModel(
              itemCode: i.itemCode,
              itemName: '${i.itemName}${TableRowCloneHelper.copySuffix}',
              qty: i.qty,
              grossWeightKg: i.grossWeightKg,
              cbm: i.cbm,
              fobUnitEgp: i.fobUnitEgp,
            ))
        .toList();
    final cloned = LandedCostSettlementModel(
      settlementId: 0,
      settlementCode: '',
      importFileId: source.importFileId,
      expenseInvoices: clonedExpenses,
      itemLandedCosts: clonedItems,
      createdAt: '',
      updatedAt: '',
    );
    _showAddDialog(initialRecord: cloned, isCloneDraft: true);
  }

  // ── Shared formatting helpers for copy / export ───────────────────────────

  String _fileTitle(LandedCostSettlementModel r, Map<int, dynamic> importFilesMap) {
    final matchingFile = importFilesMap[r.importFileId];
    final fileCode = matchingFile?.primaryNameWithCode ?? 'IMP-${r.importFileId}';
    final compName = matchingFile?.companyName ?? '';
    return compName.isNotEmpty ? '$fileCode - $compName' : fileCode;
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'Calculated':
        return l10n.financialSettlementStatusCalculated;
      case 'Approved':
        return l10n.financialSettlementStatusApproved;
      case 'Draft':
        return l10n.financialSettlementStatusDraft;
      default:
        return status;
    }
  }

  List<String> _registryHeaders(AppLocalizations l10n, {required bool withCurrency}) {
    final c = withCurrency ? ' (${l10n.financialSettlementCurrencyEgp})' : '';
    return [
      l10n.settlementExpColCode,
      l10n.settlementExpColFile,
      l10n.settlementExpColAccountant,
      l10n.settlementExpColStatus,
      '${l10n.settlementExpColFob}$c',
      '${l10n.settlementExpColExpenses}$c',
      '${l10n.settlementExpColLanded}$c',
      l10n.settlementExpColMarkup,
    ];
  }

  void _copySettlementRowTsv(
    LandedCostSettlementModel r,
    AppLocalizations l10n,
    Map<int, dynamic> importFilesMap,
  ) {
    final values = [
      r.settlementCode,
      _fileTitle(r, importFilesMap),
      r.accountantName,
      _statusLabel(l10n, r.status),
      r.totalFobEgp.toStringAsFixed(2),
      r.totalExpensesEgp.toStringAsFixed(2),
      r.totalLandedCostEgp.toStringAsFixed(2),
      '${r.averageMarkupFactor.toStringAsFixed(3)}x',
    ];

    TableCopyHelper.copyRow(
      context,
      values,
      headers: _registryHeaders(l10n, withCurrency: true),
      customMessage: l10n.copyFinancialSettlementRowSuccess,
    );
  }

  Future<void> _exportSettlementsExcel(
    List<LandedCostSettlementModel> records,
    AppLocalizations l10n,
    Map<int, dynamic> importFilesMap,
  ) async {
    final rows = records
        .map((r) => [
              r.settlementCode,
              _fileTitle(r, importFilesMap),
              r.accountantName,
              _statusLabel(l10n, r.status),
              r.totalFobEgp.toStringAsFixed(2),
              r.totalExpensesEgp.toStringAsFixed(2),
              r.totalLandedCostEgp.toStringAsFixed(2),
              '${r.averageMarkupFactor.toStringAsFixed(3)}x',
            ])
        .toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Financial Settlement',
      importFileNameOrCode: 'Registry',
      headers: _registryHeaders(l10n, withCurrency: true),
      rows: rows,
    );
  }

  Future<void> _exportSettlementsPdf(
    List<LandedCostSettlementModel> records,
    AppLocalizations l10n,
    Map<int, dynamic> importFilesMap,
  ) async {
    final currencyStr = l10n.financialSettlementCurrencyEgp;
    final rows = records
        .map((r) => [
              r.settlementCode,
              _fileTitle(r, importFilesMap),
              r.accountantName,
              _statusLabel(l10n, r.status),
              '${r.totalFobEgp.toStringAsFixed(2)} $currencyStr',
              '${r.totalExpensesEgp.toStringAsFixed(2)} $currencyStr',
              '${r.totalLandedCostEgp.toStringAsFixed(2)} $currencyStr',
              '${r.averageMarkupFactor.toStringAsFixed(3)}x',
            ])
        .toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Financial Settlement',
      importFileNameOrCode: 'Registry',
      headers: _registryHeaders(l10n, withCurrency: false),
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: l10n.settlementPdfTitle,
        subtitle: l10n.settlementPdfSubtitle,
        metadata: {
          l10n.settlementPdfMetaTotal: records.length.toString(),
          l10n.financialSettlementStatusCalculated:
              records.where((r) => r.status == 'Calculated').length.toString(),
          l10n.financialSettlementStatusApproved:
              records.where((r) => r.status == 'Approved').length.toString(),
        },
      ),
    );
  }

  void _showOdooDialog(int settlementId, String settlementCode) {
    showDialog(
      context: context,
      builder: (context) => OdooJournalEntryDialog(
        settlementId: settlementId,
        settlementCode: settlementCode,
      ),
    );
  }

  void _copySettlementRecordsTsv(
    BuildContext context,
    List<LandedCostSettlementModel> records,
    Map<int, dynamic> importFilesMap,
  ) {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln(_registryHeaders(l10n, withCurrency: true).join('\t'));

    for (final r in records) {
      buffer.writeln([
        r.settlementCode,
        _fileTitle(r, importFilesMap),
        r.accountantName,
        _statusLabel(l10n, r.status),
        r.totalFobEgp.toStringAsFixed(2),
        r.totalExpensesEgp.toStringAsFixed(2),
        r.totalLandedCostEgp.toStringAsFixed(2),
        '${r.averageMarkupFactor.toStringAsFixed(3)}x',
      ].join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.financialSettlementExportTsvSuccess,
    );
  }

  void _copySettlementBreakdownTsv(
    BuildContext context,
    LandedCostSettlementModel record,
    Map<int, dynamic> importFilesMap,
  ) {
    final l10n = context.l10n;
    final currencyStr = l10n.financialSettlementCurrencyEgp;
    final buffer = StringBuffer();
    final fileTitle = _fileTitle(record, importFilesMap);

    buffer.writeln(l10n.settlementBreakdownTitle(record.settlementCode));
    buffer.writeln('${l10n.settlementExpColFile}:\t$fileTitle\t${l10n.settlementExpColAccountant}:\t${record.accountantName}');
    buffer.writeln('${l10n.settlementExpColFob}:\t${record.totalFobEgp.toStringAsFixed(2)} $currencyStr\t${l10n.settlementExpColExpenses}:\t${record.totalExpensesEgp.toStringAsFixed(2)} $currencyStr');
    buffer.writeln('${l10n.settlementExpColLanded}:\t${record.totalLandedCostEgp.toStringAsFixed(2)} $currencyStr\t${l10n.settlementExpColMarkup}:\t${record.averageMarkupFactor.toStringAsFixed(3)}x');
    buffer.writeln('');
    buffer.writeln('=== ${l10n.settlementBreakdownExpensesSection} ===');
    buffer.writeln([
      l10n.financialSettlementColInvoiceNo,
      l10n.financialSettlementColCategory,
      l10n.financialSettlementColProvider,
      l10n.financialSettlementColAmountFx,
      l10n.financialSettlementColExchangeRate,
      l10n.financialSettlementColAmountEgp,
      l10n.financialSettlementColAllocationRule,
    ].join('\t'));

    for (final exp in record.expenseInvoices) {
      buffer.writeln([
        exp.invoiceNo,
        settlementCategoryLabel(context, exp.category),
        exp.providerName,
        '${exp.amountFx.toStringAsFixed(2)} ${exp.currency}',
        '${exp.exchangeRate}',
        '${exp.amountEgp.toStringAsFixed(2)} $currencyStr',
        settlementRuleLabel(context, exp.allocationRule),
      ].join('\t'));
    }

    buffer.writeln('');
    buffer.writeln('=== ${l10n.settlementBreakdownItemsSection} ===');
    buffer.writeln([
      l10n.financialSettlementColItemCode,
      l10n.financialSettlementColItemName,
      l10n.financialSettlementColQty,
      l10n.financialSettlementColFobUnit,
      l10n.financialSettlementColAllocatedFreight,
      l10n.financialSettlementColAllocatedCustoms,
      l10n.financialSettlementColAllocatedClearance,
      l10n.financialSettlementColAllocatedTransport,
      l10n.financialSettlementColUnitLandedCost,
      l10n.financialSettlementColMarkupFactor,
    ].join('\t'));

    for (final itm in record.itemLandedCosts) {
      buffer.writeln([
        itm.itemCode,
        itm.itemName,
        itm.qtyLabel,
        '${itm.fobUnitEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.allocatedFreightEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.allocatedCustomsEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.allocatedClearanceEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.allocatedTransportEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.unitLandedCostEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.markupFactor.toStringAsFixed(3)}x',
      ].join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.financialSettlementCopyBreakdownSuccess,
    );
  }

  void _openGlobalDialog({required bool actualCost}) {
    final l10n = context.l10n;
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(actualCost
              ? l10n.settlementSelectShipmentForActual
              : l10n.settlementSelectShipmentForInvoices),
        ),
      );
      return;
    }
    if (actualCost) {
      ActualLandedCostDialog.show(
        context,
        importFileId: files.first.importFileId,
        importFileCode: files.first.importFileCode,
      );
    } else {
      FinalSettlementInvoicesDialog.show(
        context,
        importFileId: files.first.importFileId,
        importFileCode: files.first.importFileCode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final recordsState = ref.watch(financialSettlementProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importFilesMap = {for (final f in importFiles) f.importFileId: f};

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.calculate_outlined,
        titleEn: l10n.settlementTabRegistry,
        titleAr: l10n.settlementTabRegistry,
      ),
      VerticalNavTabItem(
        icon: Icons.analytics_outlined,
        titleEn: l10n.settlementTabComparison,
        titleAr: l10n.settlementTabComparison,
      ),
      VerticalNavTabItem(
        icon: Icons.add_chart_outlined,
        titleEn: l10n.settlementTabNew,
        titleAr: l10n.settlementTabNew,
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'PHASE-6: STEP_20',
      titleEn: l10n.settlementScreenTitle,
      titleAr: l10n.settlementScreenTitle,
      headerIcon: Icons.calculate,
      headerColor: AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: _selectedTab,
      onTabSelected: (index) {
        if (index == 2) {
          _showAddDialog();
        } else {
          setState(() {
            _selectedTab = index;
            _visitedTabs.add(index);
          });
        }
      },
      headerActions: [
        AppButton(
          key: const Key('globalFinalSettlementInvoicesBtn'),
          label: l10n.settlementClo01Btn,
          icon: Icons.receipt_long_rounded,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          onPressed: () => _openGlobalDialog(actualCost: false),
        ),
        const SizedBox(width: 8),
        AppButton(
          key: const Key('globalActualLandedCostBtn'),
          label: l10n.settlementClo02Btn,
          icon: Icons.calculate_rounded,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: () => _openGlobalDialog(actualCost: true),
        ),
        const SizedBox(width: 8),
        AppButton(
          key: const Key('globalLogisticsInvoicesBtn'),
          label: 'فواتير الخدمات اللوجستية (LSI)',
          icon: Icons.account_balance_wallet_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => const LogisticsInvoicesScreen(),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withOpacity(0.7), size: density.buttonIconSize),
          tooltip: l10n.financialSettlementRefreshTooltip,
          onPressed: _reloadSettlements,
        ),
      ],
      body: IndexedStack(
        index: _selectedTab == 1 ? 1 : 0,
        children: [
          _buildRegistryView(context, recordsState, importFilesMap),
          _visitedTabs.contains(1)
              ? const LandedCostComparisonScreen(isEmbedded: true)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AsyncValue<List<LandedCostSettlementModel>> recordsState,
    Map<int, dynamic> importFilesMap,
  ) {
    final l10n = context.l10n;
    List<LandedCostSettlementModel> currentRecords() => recordsState.valueOrNull ?? [];

    return SettlementPanel(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SettlementFit(child: AppButton(
            key: const Key('createSettlementBtn'),
            label: l10n.financialSettlementNewSettlementBtn,
            icon: Icons.add_chart,
            variant: AppButtonVariant.primary,
            onPressed: () => _showAddDialog(),
          )),
          SettlementFit(child: AppButton(
            key: const Key('searchAndCloneSettlementBtn'),
            label: l10n.searchAndCloneFinancialSettlementBtn,
            icon: Icons.difference_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => _openSearchAndCloneDialog(currentRecords()),
          )),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.financialSettlementSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    return value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(financialSettlementProvider.notifier).fetchSettlements(search: '');
                            },
                          )
                        : const SizedBox.shrink();
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) {
                ref.read(financialSettlementProvider.notifier).fetchSettlements(search: val);
              },
            ),
          ),
          SettlementFit(child: AppButton(
            key: const Key('copySettlementTableTsvBtn'),
            label: l10n.financialSettlementExportTsvBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () {
              final records = currentRecords();
              if (records.isNotEmpty) {
                _copySettlementRecordsTsv(context, records, importFilesMap);
              }
            },
          )),
          IconActionButton(
            key: const Key('exportSettlementExcelBtn'),
            icon: Icons.description_outlined,
            color: AppTheme.emerald,
            tooltip: l10n.exportFinancialSettlementExcelTooltip,
            iconSize: 20,
            onTap: () {
              final records = currentRecords();
              if (records.isNotEmpty) {
                _exportSettlementsExcel(records, l10n, importFilesMap);
              }
            },
          ),
          IconActionButton(
            key: const Key('exportSettlementPdfBtn'),
            icon: Icons.picture_as_pdf_outlined,
            color: AppTheme.crimson,
            tooltip: l10n.exportFinancialSettlementPdfTooltip,
            iconSize: 20,
            onTap: () {
              final records = currentRecords();
              if (records.isNotEmpty) {
                _exportSettlementsPdf(records, l10n, importFilesMap);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegistryView(
    BuildContext context,
    AsyncValue<List<LandedCostSettlementModel>> recordsState,
    Map<int, dynamic> importFilesMap,
  ) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Data Actions Toolbar
                  MasterDataToolbarWidget(
                    moduleEndpoint: 'financial-settlement',
                    title: 'Financial_Settlement',
                    onRefreshNeeded: _reloadSettlements,
                  ),
                  const SizedBox(height: 12),
                  _buildToolbar(context, recordsState, importFilesMap),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Settlement List Area
            recordsState.when(
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: SettlementStateView.loading(message: l10n.settlementRegistryLoading),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: SettlementStateView.error(
                  message: '${l10n.financialSettlementFetchError} ${ApiErrorText.of(l10n, err)}',
                  actionLabel: l10n.settlementRetry,
                  onAction: _reloadSettlements,
                ),
              ),
              data: (records) {
                if (records.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: SettlementStateView.empty(
                      message: l10n.financialSettlementEmptyRecords,
                      icon: Icons.calculate_outlined,
                      actionLabel: l10n.settlementRegistryEmptyAction,
                      onAction: () => _showAddDialog(),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      final r = records[idx];
                      final matchingFile = importFilesMap[r.importFileId];
                      final fileCode = matchingFile?.importFileCode ?? 'IMP-${r.importFileId}';
                      return SettlementRegistryCard(
                        record: r,
                        importFileTitle: _fileTitle(r, importFilesMap),
                        onOpenJournal: () => _showOdooDialog(r.settlementId, r.settlementCode),
                        onCopyBreakdown: () => _copySettlementBreakdownTsv(context, r, importFilesMap),
                        onCopyRow: () => _copySettlementRowTsv(r, context.l10n, importFilesMap),
                        onClone: () => _onCloneSettlement(r),
                        onOpenInvoices: () => FinalSettlementInvoicesDialog.show(
                          context,
                          importFileId: r.importFileId,
                          importFileCode: fileCode,
                        ),
                        onOpenActualCost: () => ActualLandedCostDialog.show(
                          context,
                          importFileId: r.importFileId,
                          importFileCode: fileCode,
                        ),
                      );
                    },
                    childCount: records.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
