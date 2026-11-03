import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../simulation/widgets/what_if_simulator_dialog.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import '../widgets/dialogs/clone_budget_review_dialog.dart';
import '../widgets/financial_ui.dart';
import '../widgets/search_and_clone_budget_dialog.dart';
import '../widgets/tabs/approved_budgets_registry_tab.dart';
import '../widgets/tabs/estimated_budget_tab.dart';
import '../widgets/tabs/payment_requests_registry_tab.dart';
import '../widgets/tabs/payment_requests_tab.dart';
import 'swift_reconciliation_screen.dart';

class FinancialApprovalScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final int? initialImportFileId;

  const FinancialApprovalScreen({
    super.key,
    this.initialIndex = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<FinancialApprovalScreen> createState() =>
      _FinancialApprovalScreenState();
}

class _FinancialApprovalScreenState
    extends ConsumerState<FinancialApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Set<int> _visitedTabs = {widget.initialIndex};

  int? _paySelectedImportFileId;
  int? _bgtSelectedImportFileId;

  final GlobalKey<PaymentRequestsTabState> _paymentRequestsTabKey =
      GlobalKey<PaymentRequestsTabState>();
  final GlobalKey<EstimatedBudgetTabState> _estimatedBudgetTabKey =
      GlobalKey<EstimatedBudgetTabState>();

  @override
  void initState() {
    super.initState();
    _paySelectedImportFileId = widget.initialImportFileId;
    _bgtSelectedImportFileId = widget.initialImportFileId;

    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(() {
      if (!_visitedTabs.contains(_tabController.index)) {
        setState(() => _visitedTabs.add(_tabController.index));
      }
    });

    Future.microtask(() {
      if (!ref.read(currenciesProvider).isLoading) {
        ref.read(currenciesProvider.notifier).fetchCurrencies();
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(suppliersProvider).isLoading) {
        ref.read(suppliersProvider.notifier).fetchSuppliers();
      }
      if (!ref.read(paymentRequestsProvider).isLoading) {
        ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
      }
      if (!ref.read(importBudgetsProvider).isLoading) {
        ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
      }
      if (!ref.read(purchaseOrdersProvider).isLoading) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
    });
  }

  @override
  void didUpdateWidget(FinancialApprovalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _visitedTabs.add(widget.initialIndex);
      _tabController.animateTo(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToPaymentEdit(PaymentRequestModel p) {
    setState(() {
      _visitedTabs.add(0);
      _tabController.index = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paymentRequestsTabKey.currentState?.loadPaymentRequestForEdit(p);
    });
  }

  void _navigateToBudgetEdit(ImportBudgetModel b) {
    setState(() {
      _visitedTabs.add(1);
      _tabController.index = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _estimatedBudgetTabKey.currentState?.loadBudgetForEdit(b);
    });
  }

  void _openCloneBudget(ImportBudgetModel b) {
    CloneBudgetReviewDialog.show(
      context: context,
      ref: ref,
      budget: b,
      onCloned: (cloned) {
        _navigateToBudgetEdit(cloned);
      },
    );
  }

  void _openSearchAndCloneBudget() {
    final budgets = ref.read(importBudgetsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SearchAndCloneBudgetDialog(
            budgets: budgets,
            onSelectBudget: (b) => _openCloneBudget(b),
          ),
        ),
      ),
    );
  }

  void _openSwiftReconciliation() {
    setState(() {
      _visitedTabs.add(4);
      _tabController.index = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final paymentsState = ref.watch(paymentRequestsProvider);
    final budgetsState = ref.watch(importBudgetsProvider);

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.payment_outlined,
        titleEn: 'Payment Requests',
        titleAr: 'طلبات السداد المالي للمورد',
      ),
      const VerticalNavTabItem(
        icon: Icons.pie_chart_outline,
        titleEn: 'Import Budget Approval',
        titleAr: 'اعتماد الميزانية الاستيرادية',
      ),
      VerticalNavTabItem(
        icon: Icons.account_balance_wallet_outlined,
        titleEn: 'Saved Budgets Registry',
        titleAr: 'سجل الميزانيات المعتمدة',
        badge: (budgetsState.valueOrNull?.length ?? 0) > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${budgetsState.valueOrNull?.length ?? 0}',
                  style: const TextStyle(
                    color: AppTheme.emerald,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
      VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Payment Requests Registry',
        titleAr: 'سجل طلبات السداد والتحويلات',
        badge: (paymentsState.valueOrNull?.length ?? 0) > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${paymentsState.valueOrNull?.length ?? 0}',
                  style: const TextStyle(
                    color: AppTheme.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
      const VerticalNavTabItem(
        icon: Icons.auto_awesome,
        titleEn: 'SWIFT MT103 Reconciliation',
        titleAr: 'استخراج ومطابقة السويفت (MT103)',
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'PHASE-1: STEP_04',
      titleEn: 'Financial Approvals & Budget Management',
      titleAr: 'الموافقات المالية وإدارة الميزانية',
      headerIcon: Icons.account_balance_wallet_outlined,
      headerColor: AppTheme.orange,
      tabs: tabs,
      selectedIndex: _tabController.index,
      onTabSelected: (index) => setState(() {
        _visitedTabs.add(index);
        _tabController.index = index;
      }),
      selectedImportFileId: _paySelectedImportFileId ??
          _bgtSelectedImportFileId ??
          widget.initialImportFileId,
      onShipmentStatusChanged: () {
        ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
        ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      },
      headerActions: [
        FinancialUi.fit(AppButton(
          label: l.whatIfSimulatorButton,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          icon: Icons.analytics_outlined,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const WhatIfSimulatorDialog(),
            );
          },
        )),
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.7)),
          tooltip: l.liveRefreshTooltip,
          onPressed: () {
            ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
            ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
            ref.read(importFilesProvider.notifier).fetchImportFiles();
            ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
            ref.read(suppliersProvider.notifier).fetchSuppliers();
            ref.read(currenciesProvider.notifier).fetchCurrencies();
          },
        ),
      ],
      body: SelectionArea(
        child: IndexedStack(
          index: _tabController.index,
          children: [
            // ── TAB 1: PAYMENT REQUEST FORM (BP-012) ───────────────────────────
            if (_visitedTabs.contains(0))
              PaymentRequestsTab(
                key: _paymentRequestsTabKey,
                initialImportFileId: widget.initialImportFileId,
                onOpenSwiftReconciliation: _openSwiftReconciliation,
                onImportFileChanged: (val) {
                  setState(() => _paySelectedImportFileId = val);
                },
              )
            else
              const SizedBox.shrink(),

            // ── TAB 2: IMPORT BUDGET APPROVAL FORM (BP-013) ────────────────────
            if (_visitedTabs.contains(1))
              EstimatedBudgetTab(
                key: _estimatedBudgetTabKey,
                initialImportFileId: widget.initialImportFileId,
                onImportFileChanged: (val) {
                  setState(() => _bgtSelectedImportFileId = val);
                },
              )
            else
              const SizedBox.shrink(),

            // ── TAB 3: SAVED BUDGETS REGISTRY ──────────────────────────────────
            if (_visitedTabs.contains(2))
              ApprovedBudgetsRegistryTab(
                onEditBudget: _navigateToBudgetEdit,
                onCloneBudget: _openCloneBudget,
                onSearchAndClone: _openSearchAndCloneBudget,
                onSwitchToForm: () => setState(() {
                  _visitedTabs.add(1);
                  _tabController.index = 1;
                }),
              )
            else
              const SizedBox.shrink(),

            // ── TAB 4: PAYMENT REQUESTS REGISTRY ───────────────────────────────
            if (_visitedTabs.contains(3))
              PaymentRequestsRegistryTab(
                onEditPayment: _navigateToPaymentEdit,
                onOpenSwiftReconciliation: _openSwiftReconciliation,
              )
            else
              const SizedBox.shrink(),

            // ── TAB 5: SWIFT MT103 PARSER & RECONCILIATION ─────────────────────
            if (_visitedTabs.contains(4))
              const SwiftReconciliationScreen(isEmbedded: true)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
