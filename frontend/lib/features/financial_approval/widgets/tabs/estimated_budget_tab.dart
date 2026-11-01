import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/financial_approval_model.dart';
import '../../providers/financial_approval_provider.dart';
import '../../services/financial_export_service.dart';
import '../estimated_budget/estimated_budget_actions_bar.dart';
import '../estimated_budget/estimated_budget_category_card.dart';
import '../estimated_budget/estimated_budget_dialogs.dart';
import '../estimated_budget/estimated_budget_form_state.dart';
import '../estimated_budget/estimated_budget_header.dart';
import '../estimated_budget/estimated_budget_submitter.dart';
import '../estimated_budget/estimated_budget_variance_table.dart';

class EstimatedBudgetTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final void Function(int? fileId)? onImportFileChanged;

  const EstimatedBudgetTab({
    super.key,
    this.initialImportFileId,
    this.onImportFileChanged,
  });

  @override
  ConsumerState<EstimatedBudgetTab> createState() => EstimatedBudgetTabState();
}

class EstimatedBudgetTabState extends ConsumerState<EstimatedBudgetTab> {
  final formState = EstimatedBudgetFormState();

  int? get selectedImportFileId => formState.selectedImportFileId;

  @override
  void initState() {
    super.initState();
    if (widget.initialImportFileId != null) {
      Future.microtask(() {
        _onBgtImportFileSelected(widget.initialImportFileId);
      });
    }
  }

  @override
  void dispose() {
    formState.dispose();
    super.dispose();
  }

  void loadBudgetForEdit(ImportBudgetModel b) {
    formState.loadBudgetForEdit(context, ref, b, () {
      if (mounted) setState(() {});
    });
  }

  Future<void> loadBudgetForEditAndCheckSync(ImportBudgetModel b) async {
    await formState.loadBudgetForEditAndCheckSync(context, ref, b, () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onBgtImportFileSelected(int? fileId) async {
    await formState.onImportFileSelected(
      context: context,
      ref: ref,
      fileId: fileId,
      onImportFileChanged: widget.onImportFileChanged,
      notify: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _openSearchAndCloneBudgetDialog() {
    final budgets = ref.read(importBudgetsProvider).valueOrNull ?? [];
    EstimatedBudgetDialogs.showSearchAndClone(
      context: context,
      budgets: budgets,
      onSelectBudget: (b) {
        EstimatedBudgetDialogs.showCloneReview(
          context: context,
          ref: ref,
          budget: b,
          onCloned: loadBudgetForEdit,
        );
      },
    );
  }

  void _onRefresh() {
    ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
    ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
    ref.read(importFilesProvider.notifier).fetchImportFiles();
  }

  void _onReset() {
    setState(() {
      formState.reset();
    });
  }

  Future<void> _saveImportBudget() async {
    await EstimatedBudgetSubmitter.saveImportBudget(
      context: context,
      ref: ref,
      state: formState,
      notify: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _saveAndApproveBudget() async {
    await EstimatedBudgetSubmitter.saveAndApproveBudget(
      context: context,
      ref: ref,
      state: formState,
      notify: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _onExportExcel() async {
    final bgt = formState.lastSavedBudget ?? formState.buildTempBudgetModel();
    final path = await FinancialExportService.exportBudgetToExcel(
      context: context,
      budget: bgt,
      prefill: formState.prefillData,
    );
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          '✅ $path',
          severity: AppSeverity.success,
        ),
      );
    }
  }

  void _onPrintPdf() {
    final bgt = formState.lastSavedBudget ?? formState.buildTempBudgetModel();
    FinancialExportService.printOrSaveBudgetPdf(
      budget: bgt,
      prefill: formState.prefillData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
            _openSearchAndCloneBudgetDialog();
          },
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Form(
                  key: formState.formKey,
                  child: Card(
                    elevation: isDark ? 0 : 2,
                    color: isDark
                        ? AppTheme.darkCardBackground
                        : AppTheme.white,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.cloudWhite),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 14 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EstimatedBudgetHeader(
                            isMobile: isMobile,
                            selectedImportFileId:
                                formState.selectedImportFileId,
                            titleController: formState.titleController,
                            isLoadingPrefill: formState.isLoadingPrefill,
                            onSearchAndClone: _openSearchAndCloneBudgetDialog,
                            onImportFileSelected: _onBgtImportFileSelected,
                          ),
                          const SizedBox(height: 16),
                          EstimatedBudgetVarianceTable(
                            budget: formState.lastSavedBudget,
                            prefill: formState.prefillData,
                            formInvoiceEgp: double.tryParse(
                                formState.invoiceEgpController.text.trim()),
                            formFreightEgp: double.tryParse(
                                formState.freightEgpController.text.trim()),
                            formDutiesEgp: double.tryParse(
                                formState.customsEgpController.text.trim()),
                            formClearanceEgp: double.tryParse(
                                formState.clearanceEgpController.text.trim()),
                            onFillLiveCosts: () =>
                                formState.syncCurrentBudgetWithLiveCosts(
                              context,
                              () {
                                if (mounted) setState(() {});
                              },
                            ),
                            onRecalculateSuccess: (result) {
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 16),
                          EstimatedBudgetCategoryCard(
                            isMobile: isMobile,
                            invoiceCurrency: formState.invoiceCurrency,
                            freightCurrency: formState.freightCurrency,
                            invoiceForeignController:
                                formState.invoiceForeignController,
                            invoiceEgpController:
                                formState.invoiceEgpController,
                            exchangeRateController:
                                formState.exchangeRateController,
                            freightForeignController:
                                formState.freightForeignController,
                            freightEgpController:
                                formState.freightEgpController,
                            freightRateController:
                                formState.freightRateController,
                            customsEgpController:
                                formState.customsEgpController,
                            clearanceEgpController:
                                formState.clearanceEgpController,
                            notesController: formState.notesController,
                            onInvoiceCurrencyChanged: (val) =>
                                formState.onInvoiceCurrencyChanged(
                              context,
                              ref,
                              val,
                              () {
                                if (mounted) setState(() {});
                              },
                            ),
                            onFreightCurrencyChanged: (val) =>
                                formState.onFreightCurrencyChanged(
                              context,
                              ref,
                              val,
                              () {
                                if (mounted) setState(() {});
                              },
                            ),
                            onValuesChanged: () {
                              if (mounted) setState(() {});
                            },
                            validateExchangeRate: (v) =>
                                formState.validateExchangeRate(context, v),
                            validateFreightExchangeRate: (v) =>
                                formState.validateFreightExchangeRate(context, v),
                          ),
                          const SizedBox(height: 20),
                          EstimatedBudgetActionsBar(
                            isEditing: formState.editingBudgetId != null,
                            isSaving: formState.isSaving,
                            onRefresh: _onRefresh,
                            onReset: _onReset,
                            onSaveDraft: _saveImportBudget,
                            onSaveAndApprove: _saveAndApproveBudget,
                            onExportExcel: _onExportExcel,
                            onPrintPdf: _onPrintPdf,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
