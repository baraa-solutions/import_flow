import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../logistics_invoices/screens/logistics_invoices_screen.dart';
import '../models/financial_settlement_model.dart';
import '../providers/financial_settlement_provider.dart';
import '../widgets/registry/settlement_file_picker_dialog.dart';
import '../widgets/registry/settlement_registry_view.dart';
import '../widgets/search_and_clone_financial_settlement_dialog.dart';
import '../widgets/settlement_form_dialog.dart';
import 'landed_cost_comparison_screen.dart';
import 'odoo_journal_entry_dialog.dart';

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

  void _showOdooDialog(int settlementId, String settlementCode) {
    showDialog(
      context: context,
      builder: (context) => OdooJournalEntryDialog(
        settlementId: settlementId,
        settlementCode: settlementCode,
      ),
    );
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
          onPressed: () => SettlementFilePickerDialog.pickAndOpen(
            context: context,
            files: importFiles,
            actualCost: false,
          ),
        ),
        const SizedBox(width: 8),
        AppButton(
          key: const Key('globalActualLandedCostBtn'),
          label: l10n.settlementClo02Btn,
          icon: Icons.calculate_rounded,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: () => SettlementFilePickerDialog.pickAndOpen(
            context: context,
            files: importFiles,
            actualCost: true,
          ),
        ),
        const SizedBox(width: 8),
        AppButton(
          key: const Key('globalLogisticsInvoicesBtn'),
          label: l10n.isArabic ? 'فواتير الخدمات اللوجستية' : 'Logistics Service Invoices',
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
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.7), size: density.buttonIconSize),
          tooltip: l10n.financialSettlementRefreshTooltip,
          onPressed: _reloadSettlements,
        ),
      ],
      body: IndexedStack(
        index: _selectedTab == 1 ? 1 : 0,
        children: [
          SettlementRegistryView(
            recordsState: recordsState,
            importFilesMap: importFilesMap,
            searchController: _searchController,
            onReload: _reloadSettlements,
            onNewSettlement: () => _showAddDialog(),
            onSearchAndClone: () => _openSearchAndCloneDialog(recordsState.valueOrNull ?? []),
            onSearchChanged: (val) {
              ref.read(financialSettlementProvider.notifier).fetchSettlements(search: val);
            },
            onClearSearch: () {
              _searchController.clear();
              ref.read(financialSettlementProvider.notifier).fetchSettlements(search: '');
            },
            onOpenJournal: _showOdooDialog,
            onClone: _onCloneSettlement,
          ),
          _visitedTabs.contains(1)
              ? const LandedCostComparisonScreen(isEmbedded: true)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
