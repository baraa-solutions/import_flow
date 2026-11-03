import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../customs_consultation/providers/customs_consultation_provider.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../financial_approval/providers/financial_approval_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_documentation/providers/import_documentation_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/import_file_model.dart';
import '../providers/import_files_provider.dart';
import 'file_form/import_file_form_actions_bar.dart';
import 'file_form/import_file_form_customs_tab.dart';
import 'file_form/import_file_form_general_tab.dart';
import 'file_form/import_file_form_header.dart';
import 'file_form/import_file_form_shipping_tab.dart';
import 'file_form/import_file_form_submitter.dart';

/// 🚢 Modular Coordinator for Import File Creation & Editing Dialog (< 350 lines).
///
/// Decomposed into dedicated sub-components in `file_form/`:
/// - Header: [ImportFileFormHeader]
/// - Tab 1 (General & Commercial): [ImportFileFormGeneralTab]
/// - Tab 2 (Shipping & Logistics): [ImportFileFormShippingTab]
/// - Tab 3 (Customs & Compliance): [ImportFileFormCustomsTab]
/// - Actions Bar: [ImportFileFormActionsBar]
/// - Submission & Diff Logic: [ImportFileFormSubmitter]
class ImportFileFormDialog extends ConsumerStatefulWidget {
  final ImportFileModel? fileToEdit;
  const ImportFileFormDialog({super.key, this.fileToEdit});

  @override
  ConsumerState<ImportFileFormDialog> createState() => ImportFileFormDialogState();
}

class ImportFileFormDialogState extends ConsumerState<ImportFileFormDialog>
    with SingleTickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  late TabController tabController;

  late TextEditingController customFileIdController;
  late TextEditingController poNoController;
  late TextEditingController piNoController;
  late TextEditingController estimatedCostController;
  late TextEditingController selectedScenarioController;
  late TextEditingController pickupAddressController;
  late TextEditingController polController;
  late TextEditingController podController;
  late TextEditingController targetFreeDaysController;
  late TextEditingController shippingInstructionsNotesController;
  late TextEditingController form4Controller;
  late TextEditingController swiftController;
  late TextEditingController form46Controller;
  late TextEditingController notesController;
  late TextEditingController ownerController;
  late TextEditingController hsCodeController;
  late TextEditingController productCategoryController;

  GuideMatchResultModel? matchedGuidance;
  bool isMatchingGuide = false;

  int? selectedCompanyId;
  String companyName = '';
  int? selectedSupplierId;
  String supplierName = '';
  int? selectedBrokerId;
  String brokerName = '';
  String shipmentMode = 'Sea FCL';
  String incotermCode = 'FOB';
  String priority = 'High';
  String shipmentCategory = 'New Purchase';
  String status = 'Open';
  String serviceTypePreference = 'Direct';
  String initialStartingStep = 'STEP_01';
  DateTime requiredEta = DateTime.now().add(const Duration(days: 30));
  DateTime fileOpeningDate = DateTime.now();
  DateTime cargoReadyDate = DateTime.now().add(const Duration(days: 7));
  String estimatedCostCurrency = 'USD';

  List<InvoiceItemModel> invoices = [];
  List<PackingListItemModel> packingLists = [];
  List<int> selectedProjectIds = [];

  bool isSaving = false;
  bool isDirty = false;

  List<TextEditingController> get _allControllers => [
    customFileIdController, poNoController, piNoController, estimatedCostController,
    selectedScenarioController, pickupAddressController, polController, podController,
    targetFreeDaysController, shippingInstructionsNotesController, form4Controller,
    swiftController, form46Controller, notesController, ownerController,
    hsCodeController, productCategoryController,
  ];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);

    final f = widget.fileToEdit;
    initialStartingStep = f?.initialStartingStep ?? 'STEP_01';
    customFileIdController = TextEditingController(text: f?.customFileNumber ?? '');
    poNoController = TextEditingController(text: f?.poNumber ?? '');
    piNoController = TextEditingController(text: f?.piNumber ?? '');
    estimatedCostController = TextEditingController(
      text: (f?.estimatedCost != null && f!.estimatedCost > 0) ? f.estimatedCost.toString() : '',
    );
    selectedScenarioController = TextEditingController(text: f?.selectedScenario ?? '');
    pickupAddressController = TextEditingController(text: f?.pickupAddress ?? '');
    polController = TextEditingController(text: f?.portOfLoading ?? '');
    podController = TextEditingController(text: f?.portOfDischarge ?? 'El Dekheila Port (non TMT)');
    targetFreeDaysController = TextEditingController(text: (f?.targetFreeDays ?? 21).toString());
    shippingInstructionsNotesController = TextEditingController(text: f?.shippingInstructionsNotes ?? '');
    serviceTypePreference = f?.serviceTypePreference ?? 'Direct';
    form4Controller = TextEditingController(text: f?.form4No ?? '');
    swiftController = TextEditingController(text: f?.swiftNo ?? '');
    form46Controller = TextEditingController(text: f?.form46No ?? '');
    notesController = TextEditingController(text: f?.notes ?? '');

    final initialOwner = (f?.owner != null && f!.owner.isNotEmpty && f.owner != f.companyName)
        ? f.owner
        : (f?.owner != null && f!.owner.isNotEmpty && f.owner != 'Kamal' ? f.owner : '');
    ownerController = TextEditingController(text: initialOwner);
    hsCodeController = TextEditingController(text: f?.hsCode ?? '');
    productCategoryController = TextEditingController(text: f?.productCategory ?? '');

    if (f?.fileOpeningDate != null && f!.fileOpeningDate!.isNotEmpty) {
      fileOpeningDate = DateTime.tryParse(f.fileOpeningDate!) ?? DateTime.now();
    }
    if (f?.cargoReadyDate != null && f!.cargoReadyDate!.isNotEmpty) {
      cargoReadyDate = DateTime.tryParse(f.cargoReadyDate!) ?? DateTime.now().add(const Duration(days: 7));
    }
    estimatedCostCurrency = f?.estimatedCostCurrency ?? 'USD';

    selectedCompanyId = f?.companyId;
    companyName = f?.companyName ?? '';
    selectedSupplierId = f?.supplierId;
    supplierName = f?.supplierName ?? '';
    selectedBrokerId = f?.brokerId;
    brokerName = f?.brokerName ?? '';

    final mode = f?.shipmentMode ?? 'Sea FCL';
    shipmentMode = (mode == 'Sea') ? 'Sea FCL' : mode;

    incotermCode = f?.incotermCode ?? 'FOB';
    priority = f?.priority ?? 'High';
    shipmentCategory = f?.shipmentCategory ?? 'New Purchase';
    status = f?.status ?? 'Open';
    invoices = List.from(f?.invoicesData ?? []);
    packingLists = List.from(f?.packingListsData ?? []);
    selectedProjectIds = List.from(f?.projectIds ?? []);

    for (final c in _allControllers) {
      c.addListener(markDirty);
    }

    Future.microtask(_autoPopulateStageDocuments);
  }

  void markDirty() {
    if (!isDirty && mounted) {
      setState(() => isDirty = true);
    }
  }

  void _autoPopulateStageDocuments() {
    if (widget.fileToEdit == null) return;
    final fileId = widget.fileToEdit!.importFileId;

    if (form4Controller.text.trim().isEmpty) {
      final docs = ref.read(bankingDocumentsProvider).valueOrNull ?? [];
      final match = docs.where((d) => d.importFileId == fileId && d.docType.toLowerCase().contains('form 4') && d.docReferenceNumber.isNotEmpty).firstOrNull;
      if (match != null && mounted) setState(() => form4Controller.text = match.docReferenceNumber);
    }

    if (swiftController.text.trim().isEmpty) {
      final reqs = ref.read(paymentRequestsProvider).valueOrNull ?? [];
      final match = reqs.where((r) => r.importFileId == fileId && r.swiftReferenceNo != null && r.swiftReferenceNo!.isNotEmpty).firstOrNull;
      if (match != null && mounted) setState(() => swiftController.text = match.swiftReferenceNo!);
    }

    if (form46Controller.text.trim().isEmpty) {
      final ccs = ref.read(customsConsultationsProvider).valueOrNull ?? [];
      final match = ccs.where((c) => c.importFileId == fileId && c.consultationCode.isNotEmpty).firstOrNull;
      if (match != null && mounted) setState(() => form46Controller.text = 'DEC46-${match.consultationCode}');
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    for (final c in _allControllers) {
      c.removeListener(markDirty);
      c.dispose();
    }
    super.dispose();
  }

  Future<void> matchGuide() async {
    final hsCode = hsCodeController.text.trim();
    if (hsCode.isEmpty) return;
    setState(() => isMatchingGuide = true);
    try {
      final result = await ref.read(experienceGuideProvider.notifier).matchShipment(
        hsCode: hsCode,
        destinationPort: podController.text.trim().isEmpty ? null : podController.text.trim(),
        shippingLine: selectedScenarioController.text.trim().isEmpty ? null : selectedScenarioController.text.trim(),
        supplier: null,
      );
      if (mounted) setState(() => matchedGuidance = result);
    } catch (_) {
      if (mounted) setState(() => matchedGuidance = null);
    } finally {
      if (mounted) setState(() => isMatchingGuide = false);
    }
  }

  List<String> get currentHsCodes => hsCodeController.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  void removeHsCode(String code) {
    final list = currentHsCodes..remove(code);
    setState(() {
      hsCodeController.text = list.join(', ');
      markDirty();
    });
  }

  void addHsCode(String newCode) {
    final trimmed = newCode.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      final current = hsCodeController.text.trim();
      hsCodeController.text = current.isEmpty ? trimmed : '$current, $trimmed';
      markDirty();
    });
  }

  void resetForm() {
    setState(() {
      selectedCompanyId = null;
      companyName = '';
      selectedSupplierId = null;
      supplierName = '';
      selectedBrokerId = null;
      brokerName = '';
      customFileIdController.clear();
      poNoController.clear();
      piNoController.clear();
      notesController.clear();
      selectedProjectIds.clear();
    });
    markDirty();
  }

  void reloadDependencies() {
    ref.read(importFilesProvider.notifier).fetchImportFiles();
    ref.read(importCompaniesProvider.notifier).fetchCompanies();
    ref.read(suppliersProvider.notifier).fetchSuppliers();
    ref.read(partnersProvider.notifier).fetchPartners();
  }

  Future<void> submit() async {
    setState(() => isSaving = true);
    final success = await ImportFileFormSubmitter.submit(
      context: context,
      ref: ref,
      state: this,
    );
    if (mounted) {
      setState(() => isSaving = false);
      if (success) {
        isDirty = false;
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return UnsavedChangesGuard(
      isDirty: isDirty,
      child: SelectionArea(
        child: AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : null,
          title: ImportFileFormHeader(
            fileToEdit: widget.fileToEdit,
            isDirty: isDirty,
          ),
          content: SizedBox(
            width: 850,
            height: 600,
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      controller: tabController,
                      indicatorColor: AppTheme.cobalt,
                      labelColor: AppTheme.cobalt,
                      unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.info_outline, size: 18),
                          text: isArabic ? 'المعلومات العامة' : 'General Information',
                        ),
                        Tab(
                          icon: const Icon(Icons.local_shipping_outlined, size: 18),
                          text: isArabic ? 'الشحن واللوجستيات' : 'Shipping & Logistics',
                        ),
                        Tab(
                          icon: const Icon(Icons.gavel_outlined, size: 18),
                          text: isArabic ? 'الجمارك والامتثال' : 'Customs & Compliance',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: tabController,
                      children: [
                        ImportFileFormGeneralTab(dialog: this),
                        ImportFileFormShippingTab(dialog: this),
                        ImportFileFormCustomsTab(dialog: this),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ImportFileFormActionsBar(
              isEdit: widget.fileToEdit != null,
              isSaving: isSaving,
              onReload: reloadDependencies,
              onReset: resetForm,
              onSaveDraft: submit,
              onCancel: () => UnsavedChangesGuard.maybePop(context, isDirty: isDirty),
              onSubmit: submit,
            ),
          ],
        ),
      ),
    );
  }
}
