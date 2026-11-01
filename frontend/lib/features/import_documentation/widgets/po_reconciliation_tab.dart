import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/import_documentation_model.dart';
import '../models/po_reconciliation_session_model.dart';
import '../providers/import_documentation_provider.dart';
import 'po_reconciliation/po_reconciliation_actions_bar.dart';
import 'po_reconciliation/po_reconciliation_clone_helper.dart';
import 'po_reconciliation/po_reconciliation_dialogs.dart';
import 'po_reconciliation/po_reconciliation_extraction_handler.dart';
import 'po_reconciliation/po_reconciliation_history_section.dart';
import 'po_reconciliation/po_reconciliation_items_table.dart';
import 'po_reconciliation/po_reconciliation_localizer.dart';
import 'po_reconciliation/po_reconciliation_packing_table.dart';
import 'po_reconciliation/po_reconciliation_po_loader.dart';
import 'po_reconciliation/po_reconciliation_service.dart';
import 'po_reconciliation/po_reconciliation_smart_extraction_card.dart';
import 'po_reconciliation/po_reconciliation_summary_card.dart';
import 'po_reconciliation/po_reconciliation_table_exporter.dart';
import 'po_reconciliation/po_reconciliation_toolbar.dart';

typedef PoReconciliationTab = POReconciliationTab;

/// Coordinator widget for Screen 21: PO & Packing List 3-Way Reconciliation.
class POReconciliationTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const POReconciliationTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<POReconciliationTab> createState() => POReconciliationTabState();
}

class POReconciliationTabState extends ConsumerState<POReconciliationTab> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _mainScrollController = ScrollController();

  int? _selectedImportFileId;
  final TextEditingController _finalInvNumberCtrl = TextEditingController();
  final TextEditingController _finalPLNumberCtrl = TextEditingController();

  List<POReconciliationItemModel> _invoiceItems = [];
  List<POReconciliationItemModel> _packingItems = [];
  bool _isSubmitting = false;
  bool _isSavingSession = false;

  int? _activeSessionId;
  String? _activeSessionCode;
  Map<String, dynamic>? _extractedReconciliationData;

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() async {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      ref.read(poReconciliationSessionsProvider.notifier).fetchSessions();
      if (_selectedImportFileId != null && mounted) {
        final sessionsList = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
        final existing = sessionsList.where((s) => s.importFileId == _selectedImportFileId && s.isActive).firstOrNull;
        if (existing != null) {
          _loadSessionIntoEditor(existing);
        } else {
          _loadPOItems(_selectedImportFileId!);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant POReconciliationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
      _loadPOItems(_selectedImportFileId!);
    }
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _finalInvNumberCtrl.dispose();
    _finalPLNumberCtrl.dispose();
    super.dispose();
  }

  void _applyExtractedDataToTables() {
    if (_extractedReconciliationData == null) return;
    final applied = PoReconciliationExtractionHandler.applyExtractedData(
      extractedData: _extractedReconciliationData!,
      currentInvoiceNumber: _finalInvNumberCtrl.text,
    );
    setState(() {
      if (applied.finalInvoiceNumber != null) _finalInvNumberCtrl.text = applied.finalInvoiceNumber!;
      if (applied.finalPackingListNumber != null) _finalPLNumberCtrl.text = applied.finalPackingListNumber!;
      if (applied.invoiceItems != null) _invoiceItems = applied.invoiceItems!;
      if (applied.packingItems != null) _packingItems = applied.packingItems!;
    });
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.poRecApplyExtractedSuccess, severity: AppSeverity.info));
  }

  void _loadPOItems(int importFileId) {
    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final loaded = PoReconciliationPoLoader.loadPOItems(allPOs.where((po) => po.importFileId == importFileId).toList());
    setState(() {
      _invoiceItems = loaded.invoiceItems;
      _packingItems = loaded.packingItems;
    });
  }

  void _resetFormState() {
    _activeSessionId = null;
    _activeSessionCode = null;
    _finalInvNumberCtrl.clear();
    _finalPLNumberCtrl.clear();
    _invoiceItems = [];
    _packingItems = [];
    _extractedReconciliationData = null;
  }

  Future<void> _handleImportFileChanged(int fileId) async {
    final existing = await PoReconciliationDialogs.promptExistingSessionIfAny(context: context, ref: ref, fileId: fileId);
    if (existing != null) {
      _loadSessionIntoEditor(existing);
      return;
    }
    setState(() {
      _selectedImportFileId = fileId;
      _resetFormState();
      _selectedImportFileId = fileId;
    });
    _loadPOItems(fileId);
  }

  Future<void> _saveReconciliationSession() async {
    setState(() => _isSavingSession = true);
    final saved = await PoReconciliationService.handleSave(
      context: context,
      ref: ref,
      formKey: _formKey,
      selectedImportFileId: _selectedImportFileId,
      activeSessionId: _activeSessionId,
      finalInvoiceNumber: _finalInvNumberCtrl.text,
      finalPackingListNumber: _finalPLNumberCtrl.text,
      invoiceItems: _invoiceItems,
      packingItems: _packingItems,
      extractedData: _extractedReconciliationData,
      formatSessionDate: (d) => PoReconciliationLocalizer.formatSessionDate(context, d),
    );
    if (mounted) {
      setState(() {
        if (saved != null) {
          _activeSessionId = saved.sessionId;
          _activeSessionCode = saved.sessionCode;
        }
        _isSavingSession = false;
      });
    }
  }

  Future<void> _submitCertification() async {
    setState(() => _isSubmitting = true);
    final success = await PoReconciliationService.handleCertification(
      context: context,
      ref: ref,
      formKey: _formKey,
      selectedImportFileId: _selectedImportFileId,
      finalInvoiceNumber: _finalInvNumberCtrl.text,
      finalPackingListNumber: _finalPLNumberCtrl.text,
      invoiceItems: _invoiceItems,
      packingItems: _packingItems,
    );
    if (success) await _saveReconciliationSession();
    if (mounted) setState(() => _isSubmitting = false);
  }

  void _loadSessionIntoEditor(POReconciliationSessionModel session) {
    setState(() {
      _activeSessionId = session.sessionId;
      _activeSessionCode = session.sessionCode;
      _selectedImportFileId = session.importFileId;
      _finalInvNumberCtrl.text = session.finalInvoiceNumber ?? '';
      _finalPLNumberCtrl.text = session.finalPackingListNumber ?? '';
      _invoiceItems = PoReconciliationExtractionHandler.parseSessionItems(session.reconciledInvoiceItems);
      _packingItems = PoReconciliationExtractionHandler.parseSessionItems(session.reconciledPackingItems);
      _extractedReconciliationData = PoReconciliationExtractionHandler.buildExtractedDataFromSession(session);
    });
    final totalGw = _packingItems.fold<double>(0.0, (s, i) => s + i.initialGrossWeightKg);
    if (totalGw < 100.0 && _selectedImportFileId != null) _loadPOItems(_selectedImportFileId!);
    if (_mainScrollController.hasClients) _mainScrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.poRecSessionLoadedInEditor(session.sessionCode), severity: AppSeverity.info));
  }

  void openSearchAndCloneDialog() {
    PoReconciliationCloneHelper.openSearchAndCloneDialog(
      context: context,
      ref: ref,
      onSelectSession: _cloneSession,
    );
  }

  void _cloneSession(POReconciliationSessionModel sourceSession) {
    PoReconciliationCloneHelper.showCloneReviewDialog(
      context: context,
      sourceSession: sourceSession,
      onConfirm: (session, {required String newCode, bool copyLineItems = true}) {
        setState(() {
          _activeSessionId = null;
          _activeSessionCode = newCode;
          _selectedImportFileId = session.importFileId;
          _finalInvNumberCtrl.text = session.finalInvoiceNumber != null ? '${session.finalInvoiceNumber}${TableRowCloneHelper.copyCodeSuffix}' : '';
          _finalPLNumberCtrl.text = session.finalPackingListNumber != null ? '${session.finalPackingListNumber}${TableRowCloneHelper.copyCodeSuffix}' : '';
          if (copyLineItems) {
            _invoiceItems = PoReconciliationExtractionHandler.parseSessionItems(session.reconciledInvoiceItems);
            _packingItems = PoReconciliationExtractionHandler.parseSessionItems(session.reconciledPackingItems);
          }
          _extractedReconciliationData = PoReconciliationExtractionHandler.buildExtractedDataFromSession(session, isDraft: true);
        });
        if (_mainScrollController.hasClients) _mainScrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.clonePoReconSuccess, severity: AppSeverity.info));
      },
    );
  }

  void _cloneInvoiceItem(POReconciliationItemModel item) {
    setState(() => _invoiceItems = PoReconciliationCloneHelper.cloneItemInList(_invoiceItems, item));
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.idocAItemClonedSuccessfully(item.itemCode), severity: AppSeverity.success));
  }

  void _clonePackingItem(POReconciliationItemModel item) {
    setState(() => _packingItems = PoReconciliationCloneHelper.cloneItemInList(_packingItems, item));
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.idocAPackageClonedSuccessfully(item.itemCode), severity: AppSeverity.success));
  }

  void _updateInvoiceQuantity(int idx, double parsed) {
    setState(() => _invoiceItems[idx] = PoReconciliationCloneHelper.updateItemQty(_invoiceItems[idx], parsed));
  }

  void _updateInvoicePrice(int idx, double parsed) {
    setState(() => _invoiceItems[idx] = PoReconciliationCloneHelper.updateItemPrice(_invoiceItems[idx], parsed));
  }

  void _updatePackingItem(int idx, POReconciliationItemModel Function(POReconciliationItemModel) update) {
    setState(() => _packingItems[idx] = update(_packingItems[idx]));
  }

  @override
  Widget build(BuildContext context) {
    final density = ref.watch(displayDensityProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final sessionsList = ref.watch(poReconciliationSessionsProvider).valueOrNull ?? [];
    final selectedFile = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
    final linkedPO = allPOs.where((po) => po.importFileId == _selectedImportFileId).firstOrNull;

    final rawCurr = _extractedReconciliationData?['extracted_invoice_data']?['currency']?.toString() ??
        linkedPO?.currencyCode ?? selectedFile?.estimatedCostCurrency ?? 'USD';
    final currencyStr = rawCurr == 'USD' ? r'$' : (rawCurr == 'EUR' ? 'EUR' : rawCurr);

    final totalAmount = _invoiceItems.fold(0.0, (s, i) => s + (i.finalQuantity * (i.finalUnitPrice > 0 ? i.finalUnitPrice : i.unitPrice)));
    final totalPackages = _packingItems.fold(0.0, (s, i) => s + i.finalPackagesCount);
    final totalGross = _packingItems.fold(0.0, (s, i) => s + i.finalGrossWeightKg);
    final totalNet = _packingItems.fold(0.0, (s, i) => s + i.finalNetWeightKg);
    final totalCbm = _packingItems.fold(0.0, (s, i) => s + i.finalCbm);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () => openSearchAndCloneDialog(),
      },
      child: Focus(
        autofocus: true,
        child: SingleChildScrollView(
          controller: _mainScrollController,
          padding: density.contentPadding,
          child: SelectionArea(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoReconciliationToolbar(
                    selectedImportFileId: _selectedImportFileId,
                    importFiles: importFiles,
                    finalInvNumberCtrl: _finalInvNumberCtrl,
                    finalPLNumberCtrl: _finalPLNumberCtrl,
                    activeSessionId: _activeSessionId,
                    activeSessionCode: _activeSessionCode,
                    sessionsList: sessionsList,
                    onImportFileChanged: (val) {
                      if (val == null) {
                        setState(() {
                          _selectedImportFileId = null;
                          _resetFormState();
                        });
                        return;
                      }
                      _handleImportFileChanged(val);
                    },
                    onSearchAndClone: openSearchAndCloneDialog,
                    formatSessionDate: (d) => PoReconciliationLocalizer.formatSessionDate(context, d),
                  ),
                  const SizedBox(height: 20),
                  PoReconciliationSmartExtractionCard(
                    importFileId: _selectedImportFileId,
                    finalInvoiceNumber: _finalInvNumberCtrl.text,
                    invoiceItems: _invoiceItems,
                    packingItems: _packingItems,
                    extractedData: _extractedReconciliationData,
                    onExtracted: (res) => setState(() => _extractedReconciliationData = res),
                    onApplyExtractedToTables: _applyExtractedDataToTables,
                    density: density,
                  ),
                  const SizedBox(height: 20),
                  PoReconciliationSummaryCard(
                    totalAmount: totalAmount,
                    totalPackages: totalPackages,
                    totalGrossWeight: totalGross,
                    totalNetWeight: totalNet,
                    totalCbm: totalCbm,
                    currencyStr: currencyStr,
                    extractedData: _extractedReconciliationData,
                  ),
                  const SizedBox(height: 20),
                  PoReconciliationItemsTable(
                    invoiceItems: _invoiceItems,
                    currencyStr: currencyStr,
                    density: density,
                    onCloneItem: _cloneInvoiceItem,
                    onQuantityChanged: _updateInvoiceQuantity,
                    onPriceChanged: _updateInvoicePrice,
                    onHsCodeChanged: (idx, val) => setState(() => _invoiceItems[idx] = _invoiceItems[idx].copyWith(hsCode: val)),
                    onCopyTable: () => PoReconciliationTableExporter.copyInvoiceItemsTable(context, _invoiceItems),
                    onExportExcel: () => PoReconciliationTableExporter.exportInvoiceItemsToExcel(context, _invoiceItems, _selectedImportFileId),
                    onExportPdf: () => PoReconciliationTableExporter.exportInvoiceItemsToPdf(context, _invoiceItems, _selectedImportFileId),
                    onResetToOriginal: () {
                      if (_selectedImportFileId != null) _loadPOItems(_selectedImportFileId!);
                    },
                  ),
                  const SizedBox(height: 20),
                  PoReconciliationPackingTable(
                    packingItems: _packingItems,
                    density: density,
                    onCloneItem: _clonePackingItem,
                    onPackageTypeChanged: (idx, val) => _updatePackingItem(idx, (i) => i.copyWith(packageType: val)),
                    onPackagesCountChanged: (idx, parsed) => _updatePackingItem(idx, (i) => i.copyWith(finalPackagesCount: parsed)),
                    onGrossWeightChanged: (idx, parsed) => _updatePackingItem(idx, (i) => i.copyWith(finalGrossWeightKg: parsed)),
                    onNetWeightChanged: (idx, parsed) => _updatePackingItem(idx, (i) => i.copyWith(finalNetWeightKg: parsed)),
                    onCbmChanged: (idx, parsed) => _updatePackingItem(idx, (i) => i.copyWith(finalCbm: parsed)),
                    onCopyTable: () => PoReconciliationTableExporter.copyPackingItemsTable(context, _packingItems),
                    onExportExcel: () => PoReconciliationTableExporter.exportPackingItemsToExcel(context, _packingItems, _selectedImportFileId),
                    onExportPdf: () => PoReconciliationTableExporter.exportPackingItemsToPdf(context, _packingItems, _selectedImportFileId),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: PoReconciliationActionsBar(
                      isSavingSession: _isSavingSession,
                      isSubmitting: _isSubmitting,
                      hasActiveSession: _activeSessionId != null,
                      onSaveSession: _saveReconciliationSession,
                      onCertify: _submitCertification,
                      importFileNameOrCode: _selectedImportFileId != null ? 'IMP-$_selectedImportFileId' : null,
                      discrepancyData: _extractedReconciliationData,
                    ),
                  ),
                  const SizedBox(height: 36),
                  PoReconciliationHistorySection(
                    allSessions: sessionsList,
                    importFiles: importFiles,
                    onLoadIntoEditor: _loadSessionIntoEditor,
                    onCloneSession: _cloneSession,
                    onDeleteSession: (sess) => PoReconciliationDialogs.deleteSessionWithConfirmation(context: context, ref: ref, sess: sess),
                    onRefresh: () => ref.read(poReconciliationSessionsProvider.notifier).fetchSessions(),
                    onNewSession: () {
                      setState(() {
                        _activeSessionId = null;
                        _activeSessionCode = null;
                      });
                      if (_mainScrollController.hasClients) {
                        _mainScrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
