import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../incoterms/providers/incoterms_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/purchase_order_model.dart';
import '../providers/purchase_orders_provider.dart';
import '../services/po_draft_manager.dart';
import '../utils/po_fx_rate.dart';
import '../utils/po_row_id_matcher.dart';
import '../utils/po_row_list.dart';
import 'po_form/po_form_actions.dart';
import 'po_form/po_form_commercial_tab.dart';
import 'po_form/po_form_draft_handler.dart';
import 'po_form/po_form_extractor.dart';
import 'po_form/po_form_packing_tab.dart';
import 'po_form/po_form_preview_helper.dart';
import 'po_form/po_form_state.dart';
import 'po_form/po_form_submitter.dart';
import 'po_form/po_form_title_bar.dart';

/// Coordinator widget for the Purchase Order Creation and Editing Dialog (< 400 lines).
/// Decomposed into sub-components in `po_form/`.
class POFormDialog extends ConsumerStatefulWidget {
  final PurchaseOrderModel? po;
  final Map<String, dynamic>? initialExtractedFields;
  final PurchaseOrderModel? cloneFromPo;
  final int? defaultSupplierId;
  final int? defaultCompanyId;

  const POFormDialog({
    super.key,
    this.po,
    this.initialExtractedFields,
    this.cloneFromPo,
    this.defaultSupplierId,
    this.defaultCompanyId,
  });

  @override
  ConsumerState<POFormDialog> createState() => POFormDialogState();
}

class POFormDialogState extends ConsumerState<POFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController poReferenceCtrl;
  late TextEditingController piCtrl;
  late TextEditingController rateCtrl;
  late TextEditingController notesCtrl;
  String? rateHelperText;

  late DateTime selectedOrderDate;
  int? selectedImportFileId;
  int? selectedProjectId;
  int? selectedCompanyId;
  int? selectedSupplierId;
  int? selectedIncotermId;
  int? selectedCurrencyId;
  String? selectedCountryOfOrigin;
  late String selectedStatus;
  String? selectedPaymentTerms;

  PoRowList<POLineItemModel> itemRows = PoRowList<POLineItemModel>();
  PoRowList<PackingListItemModel> packingRows = PoRowList<PackingListItemModel>();
  PoRowList<POLineItemModel> get dialogItems => itemRows;
  set dialogItems(List<POLineItemModel> rows) => itemRows = PoRowList<POLineItemModel>(rows);
  PoRowList<PackingListItemModel> get dialogPackingItems => packingRows;
  set dialogPackingItems(List<PackingListItemModel> rows) => packingRows = PoRowList<PackingListItemModel>(rows);
  late List<PalletPlanItemModel> dialogPalletItems;

  bool _isSubmitting = false;
  bool isDirectVolumeMode = false;
  bool _isDirty = false;
  DateTime? _lastDraftSavedAt;
  Timer? _autosaveTimer;
  GuideMatchResultModel? poGuideMatchResult;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(projectsProvider.notifier).fetchProjects();
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
      ref.read(suppliersProvider.notifier).fetchSuppliers();
      ref.read(incotermsProvider.notifier).fetchIncoterms();
      ref.read(currenciesProvider.notifier).fetchCurrencies();
      ref.read(customsTariffProvider.notifier).fetchTariffs();
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    });

    final init = PoFormInitialState.create(
      po: widget.po,
      cloneFromPo: widget.cloneFromPo,
      ext: widget.initialExtractedFields,
      defaultCompanyId: widget.defaultCompanyId,
      defaultSupplierId: widget.defaultSupplierId,
    );

    selectedOrderDate = init.orderDate;
    piCtrl = TextEditingController(text: init.piNumber);
    poReferenceCtrl = TextEditingController(text: init.poReference);
    rateCtrl = TextEditingController(text: init.rate);
    notesCtrl = TextEditingController(text: init.notes);
    selectedStatus = init.status;
    selectedPaymentTerms = init.paymentTerms;
    selectedCountryOfOrigin = init.countryOfOrigin;
    selectedCompanyId = init.companyId;
    selectedSupplierId = init.supplierId;
    selectedProjectId = init.projectId;
    selectedImportFileId = init.importFileId;
    selectedIncotermId = init.incotermId;
    selectedCurrencyId = init.currencyId;
    dialogPalletItems = init.palletItems;
    isDirectVolumeMode = init.isDirectVolumeMode;
    dialogItems = init.items;
    dialogPackingItems = init.packingItems;

    poReferenceCtrl.addListener(_markDirty);
    piCtrl.addListener(_markDirty);
    rateCtrl.addListener(_markDirty);
    notesCtrl.addListener(_markDirty);

    _autosaveTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_isDirty && mounted) _performAutosave();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkDraft();
        loadPoGuide();
      }
    });
  }

  void _markDirty() {
    if (!_isDirty && mounted) setState(() => _isDirty = true);
  }

  void updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _performAutosave() async {
    if (!mounted) return;
    await PoFormDraftHandler.performAutosave(
      poId: widget.po?.poId,
      draftData: PoFormDraftHandler.collectDraftData(dialog: this),
      onDraftSaved: (savedAt) => setState(() => _lastDraftSavedAt = savedAt),
    );
  }

  Future<void> _checkDraft() async {
    final draft = await PoFormDraftHandler.checkAndPromptDraft(context: context, poId: widget.po?.poId);
    if (draft != null && mounted) {
      setState(() {
        PoFormDraftHandler.applyDraft(dialog: this, draft: draft);
        _isDirty = true;
        _lastDraftSavedAt = DateTime.tryParse(draft['saved_at'] ?? '');
      });
    }
  }

  void updateExchangeRate(int? currencyId, List<CurrencyModel> currencies) {
    if (currencyId == null) return;
    final curr = currencies.where((c) => c.currencyId == currencyId).firstOrNull;
    if (curr == null) return;
    if (curr.isBaseCurrency || curr.currencyCode == 'EGP') {
      rateCtrl.text = '1.0';
      if (mounted) setState(() => rateHelperText = null);
      return;
    }
    final foundRate = pickCommercialRate(curr.exchangeRates, selectedOrderDate);
    if (foundRate != null && foundRate > 0) {
      rateCtrl.text = foundRate.toString();
      if (mounted) setState(() => rateHelperText = null);
    } else {
      rateCtrl.clear();
      final dateStr = '${selectedOrderDate.year.toString().padLeft(4, '0')}-${selectedOrderDate.month.toString().padLeft(2, '0')}-${selectedOrderDate.day.toString().padLeft(2, '0')}';
      if (mounted) setState(() => rateHelperText = context.l10n.poNoExchangeRateForDate(curr.currencyCode, dateStr));
    }
  }

  Future<void> loadPoGuide() async {
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final supplier = selectedSupplierId != null ? suppliers.where((s) => s.supplierId == selectedSupplierId).firstOrNull : null;
    final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];
    final inco = selectedIncotermId != null ? incoterms.where((i) => i.incotermId == selectedIncotermId).firstOrNull : null;
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = selectedImportFileId != null ? files.where((f) => f.importFileId == selectedImportFileId).firstOrNull : null;
    final firstHs = dialogItems.isNotEmpty ? dialogItems.first.hsCode : null;

    if (supplier == null && selectedCountryOfOrigin == null && firstHs == null && file == null) {
      if (mounted) setState(() => poGuideMatchResult = null);
      return;
    }
    try {
      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: supplier?.companyName,
        countryOfOrigin: selectedCountryOfOrigin,
        incoterm: inco?.incotermCode,
        hsCode: firstHs,
        importFileReference: file?.importFileCode,
      );
      if (mounted) setState(() => poGuideMatchResult = res);
    } catch (_) {}
  }

  void applyExtractedFields(Map<String, dynamic> ext, {required String targetTab}) {
    final res = PoFormExtractor.extract(
      ext: ext,
      targetTab: targetTab,
      companies: ref.read(importCompaniesProvider).valueOrNull ?? [],
      suppliers: ref.read(suppliersProvider).valueOrNull ?? [],
      incoterms: ref.read(incotermsProvider).valueOrNull ?? [],
      currencies: ref.read(currenciesProvider).valueOrNull ?? [],
      tariffs: ref.read(customsTariffProvider).valueOrNull ?? [],
      existingItems: dialogItems,
    );

    setState(() {
      if (res.piNumber != null) piCtrl.text = res.piNumber!;
      if (res.poReference != null) poReferenceCtrl.text = res.poReference!;
      if (res.orderDate != null) selectedOrderDate = res.orderDate!;
      if (res.companyId != null) selectedCompanyId = res.companyId;
      if (res.supplierId != null) selectedSupplierId = res.supplierId;
      if (res.incotermId != null) selectedIncotermId = res.incotermId;
      if (res.currencyId != null) {
        selectedCurrencyId = res.currencyId;
        updateExchangeRate(res.currencyId, ref.read(currenciesProvider).valueOrNull ?? []);
      }
      if (res.countryOfOrigin != null) selectedCountryOfOrigin = res.countryOfOrigin;
      if (res.paymentTerms != null) selectedPaymentTerms = res.paymentTerms;
      if (res.items != null) dialogItems = res.items!;
      if (res.packingItems != null) dialogPackingItems = res.packingItems!;
    });

    final po = widget.po;
    if (po != null && po.poId != null) {
      ref.read(purchaseOrdersProvider.notifier).fetchAllocatedItemIds(po.poId!).then((allocated) {
        if (!mounted) return;
        setState(() {
          if (targetTab == 'all' || targetTab == 'invoice') {
            dialogItems = carryLineItemIds(existing: po.items, extracted: dialogItems, allocatedItemIds: allocated).items;
          }
          if (targetTab == 'all' || targetTab == 'packing') {
            dialogPackingItems = carryPackingItemIds(existing: po.packingListItems, extracted: dialogPackingItems);
          }
        });
      });
    }
  }

  Future<void> _submitForm() async {
    await PoFormSubmitter.submit(
      context: context,
      ref: ref,
      formKey: _formKey,
      existingPo: widget.po,
      poReference: poReferenceCtrl.text,
      piNumber: piCtrl.text,
      countryOfOrigin: selectedCountryOfOrigin,
      importFileId: selectedImportFileId,
      projectId: selectedProjectId,
      companyId: selectedCompanyId,
      supplierId: selectedSupplierId,
      incotermId: selectedIncotermId,
      currencyId: selectedCurrencyId,
      orderDate: selectedOrderDate,
      rate: double.tryParse(rateCtrl.text.trim()) ?? 1.0,
      paymentTerms: selectedPaymentTerms,
      status: selectedStatus,
      rawNotes: notesCtrl.text,
      palletPlanItems: dialogPalletItems,
      isDirectVolumeMode: isDirectVolumeMode,
      items: dialogItems,
      packingItems: dialogPackingItems,
      onSubmittingChanged: (sub) => setState(() => _isSubmitting = sub),
      onSuccess: () {
        _isDirty = false;
        Navigator.pop(context);
      },
    );
  }

  void _showReportPreview() {
    PoFormPreviewHelper.showReport(
      context: context,
      ref: ref,
      po: widget.po,
      piNumber: piCtrl.text,
      orderDate: selectedOrderDate,
      companyId: selectedCompanyId,
      supplierId: selectedSupplierId,
      incotermId: selectedIncotermId,
      currencyId: selectedCurrencyId,
      exchangeRate: double.tryParse(rateCtrl.text.trim()) ?? 1.0,
      countryOfOrigin: selectedCountryOfOrigin,
      paymentTerms: selectedPaymentTerms,
      projectId: selectedProjectId,
      importFileId: selectedImportFileId,
      items: dialogItems,
      packingItems: dialogPackingItems,
      palletPlanItems: dialogPalletItems,
      isDirectVolumeMode: isDirectVolumeMode,
      notes: notesCtrl.text,
      onConfirmSave: _submitForm,
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    poReferenceCtrl.dispose();
    piCtrl.dispose();
    rateCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onDiscard: () => PODraftManager.clearDraft(widget.po?.poId),
      child: DefaultTabController(
        length: 2,
        child: SelectionArea(
          child: AlertDialog(
            titlePadding: EdgeInsets.zero,
            title: POFormTitleBar(
              title: widget.po == null ? l.newPurchaseOrder : '${l.editPurchaseOrder} - ${widget.po!.displayName}',
              lastDraftSavedAt: _lastDraftSavedAt,
              itemsCount: dialogItems.length,
              packingItemsCount: dialogPackingItems.length,
              onClose: () => Navigator.pop(context),
              onDataExtracted: (ext) => applyExtractedFields(ext, targetTab: 'all'),
            ),
            content: SizedBox(
              width: 880,
              height: 540,
              child: Form(
                key: _formKey,
                child: TabBarView(
                  children: [
                    POFormCommercialTab(dialog: this),
                    POFormPackingTab(dialog: this),
                  ],
                ),
              ),
            ),
            actions: [
              POFormActions(
                isEdit: widget.po != null,
                isSubmitting: _isSubmitting,
                onCancel: () => Navigator.pop(context),
                onPreviewReport: _showReportPreview,
                onSubmit: _submitForm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
