import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../import_documentation/providers/import_documentation_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../models/cargox_model.dart';
import '../providers/cargox_provider.dart';
import '../services/cargox_export_service.dart';
import '../widgets/standard_invoice_hub_tab.dart';
import '../../import_documentation/widgets/smart_invoice_bl_extractor_dialog.dart';


class CargoXHubScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;
  final bool isEmbedded;

  const CargoXHubScreen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<CargoXHubScreen> createState() => _CargoXHubScreenState();
}

class _CargoXHubScreenState extends ConsumerState<CargoXHubScreen> {
  int _selectedSubTab = 0;
  int? _selectedImportFileId;

  // Form State for Tab 0 (Create Envelope)
  final _envelopeFormKey = GlobalKey<FormState>();
  final TextEditingController _acidNumberCtrl = TextEditingController();
  final TextEditingController _importerNameCtrl = TextEditingController();
  final TextEditingController _importerTaxCtrl = TextEditingController();
  final TextEditingController _supplierNameCtrl = TextEditingController();
  final TextEditingController _supplierCargoXIdCtrl = TextEditingController();
  final TextEditingController _blNumberCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  int? _selectedCompanyId;
  int? _selectedSupplierId;
  bool _isSavingEnvelope = false;

  // Attached Documents State for Creation
  List<Map<String, dynamic>> _attachedDocs = [];

  // Tab 1: Filter & Search
  String _searchQuery = '';
  String _statusFilter = 'All';

  DigitalManifestModel? _activeDigitalManifest;
  bool _isLoadingManifest = false;

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _selectedImportFileId = widget.initialImportFileId;

    _initDefaultAttachedDocs();

    Future.microtask(() {
      _refreshData();
      if (_selectedImportFileId != null) {
        _onImportFileSelected(_selectedImportFileId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CargoXHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubTab != oldWidget.initialSubTab) {
      setState(() => _selectedSubTab = widget.initialSubTab);
    }
    if (widget.initialImportFileId != null && widget.initialImportFileId != _selectedImportFileId) {
      setState(() => _selectedImportFileId = widget.initialImportFileId);
      _onImportFileSelected(widget.initialImportFileId);
    }
  }

  String _localizeDocType(BuildContext context, String? docType) {
    if (docType == null) return '—';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (docType.contains('Commercial Invoice') || docType.contains('فاتورة تجارية')) {
      return isAr ? context.l10n.cargoxDocTypeCommercialInvoice : 'Commercial Invoice';
    }
    if (docType.contains('Packing List') || docType.contains('قائمة التعبئة')) {
      return isAr ? context.l10n.cargoxDocTypePackingList : 'Packing List';
    }
    if (docType.contains('B/L') || docType.contains('بوليصة')) {
      return isAr ? context.l10n.cargoxDocTypeDraftBl : 'Draft Bill of Lading';
    }
    if (docType.contains('Certificate of Origin') || docType.contains('EUR.1') || docType.contains('شهادة المنشأ')) {
      return isAr ? context.l10n.cargoxDocTypeCooEur1 : 'Certificate of Origin (EUR.1)';
    }
    if (docType.contains('COA') || docType.contains('Analysis') || docType.contains('مخبري')) {
      return isAr ? context.l10n.cargoxDocTypeCoa : 'Certificate of Analysis';
    }
    return docType;
  }

  void _initDefaultAttachedDocs() {
    _attachedDocs = [
      {
        'doc_type': 'Commercial Invoice',
        'doc_number': 'INV-2026-FINAL',
        'file_name': 'Commercial_Invoice_Final.pdf',
        'file_size_kb': 420.0,
        'is_mandatory': true,
        'verified_against_acid': true,
      },
      {
        'doc_type': 'Packing List',
        'doc_number': 'PL-2026-FINAL',
        'file_name': 'Packing_List_Final.pdf',
        'file_size_kb': 310.0,
        'is_mandatory': true,
        'verified_against_acid': true,
      },
      {
        'doc_type': 'Draft B/L',
        'doc_number': 'MEDUST982145',
        'file_name': 'Bill_of_Lading_Official.pdf',
        'file_size_kb': 650.0,
        'is_mandatory': true,
        'verified_against_acid': true,
      },
      {
        'doc_type': 'Certificate of Origin (EUR.1)',
        'doc_number': 'COO-EG-9981',
        'file_name': 'Certificate_of_Origin_EUR1.pdf',
        'file_size_kb': 280.0,
        'is_mandatory': false,
        'verified_against_acid': true,
      },
    ];
  }

  void _refreshData() {
    if (!ref.read(cargoxEnvelopesProvider).isLoading) {
      ref.read(cargoxEnvelopesProvider.notifier).fetchEnvelopes();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(suppliersProvider).isLoading) {
      ref.read(suppliersProvider.notifier).fetchSuppliers();
    }
    if (!ref.read(importCompaniesProvider).isLoading) {
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
    if (!ref.read(draftBLReviewsProvider).isLoading) {
      ref.read(draftBLReviewsProvider.notifier).fetchReviews();
    }
    if (!ref.read(freightBookingProvider).isLoading) {
      ref.read(freightBookingProvider.notifier).fetchBookings();
    }
  }

  @override
  void dispose() {
    _acidNumberCtrl.dispose();
    _importerNameCtrl.dispose();
    _importerTaxCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierCargoXIdCtrl.dispose();
    _blNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onImportFileSelected(int? fileId) {
    setState(() => _selectedImportFileId = fileId);
    if (fileId == null) {
      _acidNumberCtrl.clear();
      _importerNameCtrl.clear();
      _importerTaxCtrl.clear();
      _supplierNameCtrl.clear();
      _supplierCargoXIdCtrl.clear();
      _blNumberCtrl.clear();
      return;
    }

    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) return;

    // 1. Auto-populate ACID Number
    String resolvedAcid = file.acidNumber ?? '';
    _acidNumberCtrl.text = resolvedAcid;

    // 2. Auto-populate Importer Company
    _selectedCompanyId = file.companyId;
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final matchedCompany = companies.where((c) => c.companyId == file.companyId).firstOrNull;
    _importerNameCtrl.text = matchedCompany?.importerName ?? file.companyName;
    if (matchedCompany?.vatId != null && matchedCompany!.vatId.isNotEmpty) {
      _importerTaxCtrl.text = matchedCompany.vatId;
    } else if (matchedCompany?.registrationNumber != null && matchedCompany!.registrationNumber.isNotEmpty) {
      _importerTaxCtrl.text = matchedCompany.registrationNumber;
    }

    // 3. Auto-populate Foreign Exporter (Supplier) & CargoX ID
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final matchedSup = suppliers.where((s) => s.supplierId == file.supplierId).firstOrNull;
    if (matchedSup != null) {
      _selectedSupplierId = matchedSup.supplierId;
      _supplierNameCtrl.text = matchedSup.companyName;
      _supplierCargoXIdCtrl.text = (matchedSup.cargoxPlatformId != null && matchedSup.cargoxPlatformId!.trim().isNotEmpty)
          ? matchedSup.cargoxPlatformId!.trim()
          : (matchedSup.foreignExporterId.isNotEmpty
              ? matchedSup.foreignExporterId.trim()
              : 'CX-${matchedSup.supplierCode}');
    } else {
      _supplierNameCtrl.text = file.supplierName;
      _supplierCargoXIdCtrl.text = 'CX-${file.supplierName.replaceAll(RegExp(r'\s+'), '-').toUpperCase()}';
    }

    // 4. Auto-populate B/L Number (from draftBLReviewsProvider, freightBookingProvider, or file)
    String resolvedBlNumber = '';

    final reviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    final linkedReview = reviews.where((r) => r.importFileId == fileId).firstOrNull;
    if (linkedReview != null) {
      final extractedBl = linkedReview.draftExtractedData?['draft_bl_number'] ??
          linkedReview.draftExtractedData?['bl_number'] ??
          linkedReview.systemDataSnapshot?['draft_bl_number'] ??
          linkedReview.draftBlNumber;
      if (extractedBl != null && extractedBl.toString().trim().isNotEmpty) {
        resolvedBlNumber = extractedBl.toString().trim();
      }
    }

    if (resolvedBlNumber.isEmpty) {
      final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
      final linkedBooking = bookings.where((b) => b.importFileId == fileId).firstOrNull;
      if (linkedBooking != null) {
        resolvedBlNumber = linkedBooking.bookingConfirmationNo ?? linkedBooking.bookingCode;
      }
    }

    if (resolvedBlNumber.isEmpty && file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      resolvedBlNumber = file.customFileNumber!;
    }

    _blNumberCtrl.text = resolvedBlNumber;

    // 5. Update Attached Documents references
    final invRef = file.invoicesData.isNotEmpty
        ? file.invoicesData.first.invoiceNo
        : (file.piNumber != null && file.piNumber!.isNotEmpty ? file.piNumber! : 'INV-${file.importFileCode}');

    setState(() {
      _attachedDocs = [
        {
          'doc_type': 'Commercial Invoice',
          'doc_number': invRef,
          'file_name': 'Commercial_Invoice_${file.importFileCode}.pdf',
          'file_size_kb': 420.0,
          'is_mandatory': true,
          'verified_against_acid': true,
        },
        {
          'doc_type': 'Packing List',
          'doc_number': 'PL-${file.importFileCode}',
          'file_name': 'Packing_List_${file.importFileCode}.pdf',
          'file_size_kb': 310.0,
          'is_mandatory': true,
          'verified_against_acid': true,
        },
        {
          'doc_type': 'Draft B/L',
          'doc_number': resolvedBlNumber.isNotEmpty ? resolvedBlNumber : 'BL-${file.importFileCode}',
          'file_name': 'Bill_of_Lading_${file.importFileCode}.pdf',
          'file_size_kb': 650.0,
          'is_mandatory': true,
          'verified_against_acid': true,
        },
        {
          'doc_type': 'Certificate of Origin (EUR.1)',
          'doc_number': 'COO-${file.importFileCode}',
          'file_name': 'Certificate_of_Origin_${file.importFileCode}.pdf',
          'file_size_kb': 280.0,
          'is_mandatory': false,
          'verified_against_acid': true,
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final envelopesState = ref.watch(cargoxEnvelopesProvider);
    final envelopes = envelopesState.valueOrNull ?? [];

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.table_chart_outlined,
        titleEn: 'Standard Commercial Invoice',
        titleAr: context.l10n.cargoxTabStandardInvoice,
      ),
      VerticalNavTabItem(
        icon: Icons.markunread_mailbox_outlined,
        titleEn: 'Create CargoX Envelope',
        titleAr: context.l10n.cargoxTabCreateEnvelope,
      ),
      VerticalNavTabItem(
        icon: Icons.hub_outlined,
        titleEn: 'Blockchain Envelopes Hub',
        titleAr: context.l10n.cargoxTabTrackingHub,
        badge: envelopes.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${envelopes.length}',
                  style: const TextStyle(color: AppTheme.cobalt, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
      VerticalNavTabItem(
        icon: Icons.description_outlined,
        titleEn: 'ACI Digital Manifest Viewer',
        titleAr: context.l10n.cargoxTabManifestViewer,
      ),
    ];

    final bodyContent = SelectionArea(
      child: IndexedStack(
        index: _selectedSubTab,
        children: [
          StandardInvoiceHubTab(initialImportFileId: _selectedImportFileId),
          _buildCreateEnvelopeTab(),
          _buildEnvelopesTrackingTab(envelopes),
          _buildDigitalManifestViewerTab(envelopes),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.hub_outlined, color: AppTheme.cobalt, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.cargoxEmbeddedTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                  ),
                  const SizedBox(width: 24),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(context.l10n.cargoxSegStandardInvoice, style: const TextStyle(fontSize: 11))),
                      ButtonSegment(value: 1, label: Text(context.l10n.cargoxSegCreateEnvelope, style: const TextStyle(fontSize: 11))),
                      ButtonSegment(value: 2, label: Text(context.l10n.cargoxSegTrackingHub, style: const TextStyle(fontSize: 11))),
                      ButtonSegment(value: 3, label: Text(context.l10n.cargoxSegManifestViewer, style: const TextStyle(fontSize: 11))),
                    ],
                    selected: {_selectedSubTab},
                    onSelectionChanged: (set) => setState(() => _selectedSubTab = set.first),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: bodyContent),
        ],
      );
    }

    return VerticalStageScaffold(
      stageCode: 'PHASE-4: STEP_11',
      titleEn: 'CargoX & ACI Blockchain Dispatch Hub',
      titleAr: context.l10n.cargoxHubTitle,
      headerIcon: Icons.hub_outlined,
      headerColor: AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: _selectedSubTab,
      onTabSelected: (idx) => setState(() => _selectedSubTab = idx),
      selectedImportFileId: _selectedImportFileId,
      onShipmentStatusChanged: _refreshData,
      headerActions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.flatEmerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(context.l10n.cargoxAiDocumentExtractionBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => SmartInvoiceBLExtractorDialog(
                initialImportFileId: _selectedImportFileId,
                initialTabIndex: 0,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          tooltip: context.l10n.cargoxLiveRefreshTooltip,
          onPressed: _refreshData,
        ),
      ],

      body: bodyContent,
    );
  }

  // ── TAB 0: CREATE & SIGN ENVELOPE ───────────────────────────────────────────
  Widget _buildCreateEnvelopeTab() {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _envelopeFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.cobalt.withValues(alpha: 0.12), Colors.blue.shade50],
                  begin: AlignmentDirectional.centerEnd,
                  end: AlignmentDirectional.centerStart,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.cobalt, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.cargoxEnvelopeGenTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.cargoxEnvelopeGenDesc,
                          style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card 1: Main Identification
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.cargoxSection1ShipmentAcid,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SearchableDropdownField<int?>(
                            value: _selectedImportFileId,
                            labelText: context.l10n.cargoxImportFileField,
                            searchHintText: context.l10n.cargoxSearchFileHint,
                            items: [
                              SearchableDropdownItem<int?>(
                                value: null,
                                label: context.l10n.cargoxUnlinkedOption,
                              ),
                              ...importFiles.map((f) => SearchableDropdownItem<int?>(
                                    value: f.importFileId,
                                    label: '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName})',
                                  )),
                            ],
                            onChanged: _onImportFileSelected,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _acidNumberCtrl,
                            decoration: InputDecoration(
                              labelText: context.l10n.cargoxAcidNumberField,
                              prefixIcon: const Icon(Icons.qr_code_2, size: 18),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return context.l10n.required;
                              final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digits.length != 19) return context.l10n.cargoxAcidValidationDigits;
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _blNumberCtrl,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: context.l10n.cargoxBlNumberField,
                              prefixIcon: const Icon(Icons.directions_boat_outlined, size: 18),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _importerNameCtrl,
                            decoration: InputDecoration(
                              labelText: context.l10n.cargoxImporterCompanyField,
                              prefixIcon: const Icon(Icons.business_outlined, size: 18),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? context.l10n.required : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _supplierNameCtrl,
                            decoration: InputDecoration(
                              labelText: context.l10n.cargoxForeignSupplierField,
                              prefixIcon: const Icon(Icons.factory_outlined, size: 18),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? context.l10n.required : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _supplierCargoXIdCtrl,
                            decoration: InputDecoration(
                              labelText: context.l10n.cargoxSupplierCargoxIdField,
                              prefixIcon: const Icon(Icons.fingerprint, size: 18),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? context.l10n.required : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Attached Documents Matrix
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.checklist_rtl_outlined, color: AppTheme.emerald, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.cargoxSection2AttachedDocs,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            icon: const Icon(Icons.restore_page, size: 16),
                            label: Text(context.l10n.cargoxRestoreDefaultDocsBtn, style: const TextStyle(fontSize: 11)),
                            onPressed: () => setState(() => _initDefaultAttachedDocs()),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Documents Table
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(2.2),
                        1: FlexColumnWidth(1.8),
                        2: FlexColumnWidth(2.5),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.5),
                        5: FlexColumnWidth(1.0),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: AppTheme.charcoal),
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.cargoxColDocType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.cargoxColDocNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.cargoxColFileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.cargoxColFileSize, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.cargoxColAcidMatch, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.cargoxColActions, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                          ],
                        ),
                        ..._attachedDocs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final doc = entry.value;
                          final locType = _localizeDocType(context, doc['doc_type']?.toString());
                          final fullRow = '$locType\t${doc['doc_number'] ?? '-'}\t${doc['file_name'] ?? ''}\t${doc['file_size_kb']} KB';

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: CopyableTableCell(
                                  value: locType,
                                  rowSummary: fullRow,
                                  child: Text(locType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: CopyableTableCell(
                                  value: doc['doc_number']?.toString() ?? '-',
                                  rowSummary: fullRow,
                                  child: Text(doc['doc_number'] ?? '-', style: const TextStyle(fontSize: 11.5)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: CopyableTableCell(
                                  value: doc['file_name']?.toString() ?? '',
                                  rowSummary: fullRow,
                                  child: Text(doc['file_name'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: CopyableTableCell(
                                  value: '${doc['file_size_kb']} KB',
                                  rowSummary: fullRow,
                                  child: Text('${doc['file_size_kb']} KB', style: const TextStyle(fontSize: 11.5)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableTableCell(
                                  value: context.l10n.cargoxDocMatchedBadge,
                                  rowSummary: fullRow,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Text(context.l10n.cargoxDocMatchedBadge, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 15, color: AppTheme.cobalt),
                                    tooltip: context.l10n.copy,
                                    onPressed: () {
                                      CopyHelper.copy(context, fullRow, customMessage: context.l10n.cargoxCopiedAttachedDocSuccess(doc['file_name'] ?? locType));
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _attachedDocs.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: AppTheme.charcoal,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(context.l10n.cargoxAddDocToEnvelopeBtn, style: const TextStyle(fontSize: 11.5)),
                      onPressed: _showAddDocumentDialog,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.charcoal,
                    side: const BorderSide(color: AppTheme.cobalt),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18, color: AppTheme.cobalt),
                  label: const Text(
                    'حفظ مؤقت للمظروف (Save Draft)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _isSavingEnvelope ? null : () => _submitCreateEnvelope(isDraft: true),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSavingEnvelope
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.security, size: 20, color: Colors.amber),
                  label: Text(
                    context.l10n.cargoxGenerateAndSignEnvelopeBtn,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _isSavingEnvelope ? null : () => _submitCreateEnvelope(isDraft: false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDocumentDialog() {
    final typeCtrl = TextEditingController(text: 'Certificate of Analysis (COA)');
    final numCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'Analysis_Report.pdf');

    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: Dialog(
          backgroundColor: AppTheme.isDark(ctx) ? AppTheme.darkCardBackground : AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.cargoxAddDocDialogTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(controller: typeCtrl, decoration: InputDecoration(labelText: context.l10n.cargoxDocTypeField, border: const OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: numCtrl, decoration: InputDecoration(labelText: context.l10n.cargoxDocNumberField, border: const OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: nameCtrl, decoration: InputDecoration(labelText: context.l10n.cargoxDocFileNameField, border: const OutlineInputBorder())),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                        onPressed: () {
                          if (typeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
                          setState(() {
                            _attachedDocs.add({
                              'doc_type': typeCtrl.text.trim(),
                              'doc_number': numCtrl.text.trim(),
                              'file_name': nameCtrl.text.trim(),
                              'file_size_kb': 250.0,
                              'is_mandatory': false,
                              'verified_against_acid': true,
                            });
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(context.l10n.cargoxAddDocSubmitBtn, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitCreateEnvelope({bool isDraft = false}) async {
    if (!isDraft && !_envelopeFormKey.currentState!.validate()) return;
    if (!isDraft && _attachedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cargoxAtLeastOneDocError, severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isSavingEnvelope = true);
    try {
      final payload = {
        'import_file_id': _selectedImportFileId,
        'acid_number': _acidNumberCtrl.text.trim().isNotEmpty
            ? _acidNumberCtrl.text.trim()
            : 'DRAFT-${DateTime.now().millisecondsSinceEpoch}',
        'importer_company_id': _selectedCompanyId,
        'importer_company_name': _importerNameCtrl.text.trim(),
        'importer_tax_number': _importerTaxCtrl.text.trim(),
        'supplier_id': _selectedSupplierId,
        'supplier_name': _supplierNameCtrl.text.trim(),
        'supplier_cargox_id': _supplierCargoXIdCtrl.text.trim(),
        'bl_number': _blNumberCtrl.text.trim().isNotEmpty ? _blNumberCtrl.text.trim() : null,
        'notes': _notesCtrl.text.trim(),
        'documents': _attachedDocs,
        'mode': 'MOCK',
        'is_draft': isDraft,
        'status': isDraft ? 'DRAFT' : null,
      };

      final created = await ref.read(cargoxEnvelopesProvider.notifier).createEnvelope(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
              isDraft
                  ? 'تم حفظ مسودة المظروف بنجاح (${created.envelopeCode})'
                  : context.l10n.cargoxEnvelopeCreatedSuccess(created.envelopeCode),
            severity: isDraft ? AppSeverity.info : AppSeverity.success,
          ),
        );
        setState(() => _selectedSubTab = 1);
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.cargoxEnvelopeCreateError, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSavingEnvelope = false);
    }
  }

  // ── TAB 1: BLOCKCHAIN ENVELOPES TRACKING HUB ────────────────────────────────
  Widget _buildEnvelopesTrackingTab(List<CargoXEnvelopeModel> envelopes) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final filtered = envelopes.where((e) {
      final q = _searchQuery.toLowerCase();
      if (q.isNotEmpty) {
        final matches = e.envelopeCode.toLowerCase().contains(q) ||
            e.acidNumber.toLowerCase().contains(q) ||
            e.supplierName.toLowerCase().contains(q) ||
            (e.blNumber != null && e.blNumber!.toLowerCase().contains(q)) ||
            (e.importFileCode != null && e.importFileCode!.toLowerCase().contains(q));
        if (!matches) return false;
      }
      if (_statusFilter != 'All' && e.status != _statusFilter) return false;
      return true;
    }).toList();

    final totalCount = envelopes.length;
    final acceptedCount = envelopes.where((e) => e.status == 'ACCEPTED_BY_CUSTOMS').length;
    final uploadedCount = envelopes.where((e) => e.status == 'UPLOADED_BY_SUPPLIER' || e.status == 'DRAFT').length;
    final verifiedCount = envelopes.where((e) => e.isAcidVerified).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric Cards
          Row(
            children: [
              _buildMetricCard(context.l10n.cargoxMetricTotalEnvelopes, '$totalCount', AppTheme.cobalt, Icons.markunread_mailbox),
              const SizedBox(width: 12),
              _buildMetricCard(context.l10n.cargoxMetricAcceptedCustoms, '$acceptedCount', AppTheme.emerald, Icons.verified),
              const SizedBox(width: 12),
              _buildMetricCard(context.l10n.cargoxMetricInProgress, '$uploadedCount', AppTheme.orange, Icons.hourglass_top),
              const SizedBox(width: 12),
              _buildMetricCard(context.l10n.cargoxMetricAcidVerified, '$verifiedCount', Colors.purple, Icons.check_circle_outline),
            ],
          ),
          const SizedBox(height: 18),

          // Search & Filter Toolbar
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: context.l10n.cargoxSearchEnvelopesHint,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _statusFilter,
                      items: [
                        DropdownMenuItem(value: 'All', child: Text(context.l10n.cargoxFilterAllStatuses)),
                        DropdownMenuItem(value: 'DRAFT', child: Text(context.l10n.cargoxFilterDraft)),
                        DropdownMenuItem(value: 'UPLOADED_BY_SUPPLIER', child: Text(context.l10n.cargoxFilterUploaded)),
                        DropdownMenuItem(value: 'ACCEPTED_BY_CUSTOMS', child: Text(context.l10n.cargoxFilterAccepted)),
                      ],
                      onChanged: (val) => setState(() => _statusFilter = val ?? 'All'),
                    ),
                    const SizedBox(width: 12),
                    // 4 Linked Output Actions (TSV, Excel, PDF, Dossier)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.table_view_outlined, size: 16, color: AppTheme.cobalt),
                      label: Text(context.l10n.cargoxExportTsvBtn, style: const TextStyle(fontSize: 11.5, color: AppTheme.cobalt)),
                      onPressed: filtered.isEmpty
                          ? null
                          : () async {
                              await CargoXExportService.saveEnvelopesTsvToFile(context: context, envelopes: filtered, shipments: importFiles);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                AppTheme.snackBar(context, context.l10n.cargoxCopiedTsvSuccess, severity: AppSeverity.success),
                              );
                            },
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.file_present_outlined, size: 16, color: AppTheme.emerald),
                      label: Text(context.l10n.cargoxExportExcelBtn, style: const TextStyle(fontSize: 11.5, color: AppTheme.emerald)),
                      onPressed: filtered.isEmpty
                          ? null
                          : () async {
                              await CargoXExportService.saveEnvelopesCsvToFile(context: context, envelopes: filtered, shipments: importFiles);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                AppTheme.snackBar(context, context.l10n.cargoxCopiedExcelSuccess, severity: AppSeverity.success),
                              );
                            },
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.purple),
                      label: Text(context.l10n.cargoxPrintPdfBtn, style: const TextStyle(fontSize: 11.5, color: Colors.purple)),
                      onPressed: filtered.isEmpty
                          ? null
                          : () async {
                              await CargoXExportService.printOrSaveEnvelopesPdf(context: context, envelopes: filtered, shipments: importFiles);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                AppTheme.snackBar(context, context.l10n.cargoxExportPdfDialogTitle, severity: AppSeverity.info),
                              );
                            },
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.copy_all_outlined, size: 16, color: AppTheme.charcoal),
                      label: Text(context.l10n.cargoxCopyDossierBtn, style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal)),
                      onPressed: filtered.isEmpty
                          ? null
                          : () {
                              CargoXExportService.copyEnvelopesDossier(context: context, envelopes: filtered, shipments: importFiles);
                            },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: Text(context.l10n.cargoxPrepareNewEnvelopeBtn, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                      onPressed: () => setState(() => _selectedSubTab = 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Envelopes List
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: Center(
                child: Text(context.l10n.cargoxNoEnvelopesFound, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            )
          else
            ...filtered.map((env) => _buildEnvelopeCard(env)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          CopyHelper.copy(
            context,
            '$title: $value',
            customMessage: context.l10n.cargoxCopiedToClipboard,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Icon(Icons.copy, size: 14, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnvelopeCard(CargoXEnvelopeModel env) {
    final isAccepted = env.status == 'ACCEPTED_BY_CUSTOMS';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
      env.importFileCode,
      shipments: importFiles,
      isArabic: isAr,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.markunread_mailbox, color: AppTheme.cobalt, size: 22),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => CopyHelper.copy(context, env.envelopeCode, customMessage: context.l10n.cargoxCopiedEnvelopeSuccess(env.envelopeCode)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              env.envelopeCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                          ],
                        ),
                      ),
                      if (env.importFileCode != null) ...[
                        const SizedBox(width: 10),
                        if (shipmentName != env.importFileCode) ...[
                          Flexible(
                            child: Text(
                              shipmentName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        InkWell(
                          onTap: () => CopyHelper.copy(context, env.importFileCode!, customMessage: context.l10n.cargoxCopiedToClipboard),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(env.importFileCode!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.cobalt),
                      tooltip: context.l10n.cargoxCopyDossierBtn,
                      onPressed: () {
                        final summary = StringBuffer();
                        final resolvedShipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
                          env.importFileCode,
                          shipments: importFiles,
                          isArabic: isAr,
                        );
                        summary.writeln('${context.l10n.cargoxTsvHeaderEnvelopeCode}: ${env.envelopeCode}');
                        summary.writeln('${context.l10n.cargoxTsvHeaderImportFile}: $resolvedShipmentTitle');
                        summary.writeln('${context.l10n.cargoxTsvHeaderAcid}: ${env.acidNumber}');
                        summary.writeln('${context.l10n.cargoxTsvHeaderSupplier}: ${env.supplierName}');
                        summary.writeln('${context.l10n.cargoxTsvHeaderSupplierCargoxId}: ${env.supplierCargoxId}');
                        summary.writeln('${context.l10n.cargoxTsvHeaderBlNumber}: ${env.blNumber ?? "—"}');
                        summary.writeln('${context.l10n.cargoxTsvHeaderStatus}: ${env.status}');
                        if (env.blockchainTxHash != null) summary.writeln('${context.l10n.cargoxTsvHeaderTxHash}: ${env.blockchainTxHash}');
                        if (env.customsConfirmationReceipt != null) summary.writeln('${context.l10n.cargoxTsvHeaderCustomsReceipt}: ${env.customsConfirmationReceipt}');
                        summary.writeln('${context.l10n.cargoxTsvHeaderDocsCount}: ${env.documents.length}');
                        for (final d in env.documents) {
                          summary.writeln('  - ${_localizeDocType(context, d.docType)}: ${d.fileName} (${d.fileSizeKb} KB)');
                        }
                        CopyHelper.copy(context, summary.toString().trim(), customMessage: context.l10n.cargoxCopiedEnvelopeSuccess(env.envelopeCode));
                      },
                    ),
                    const SizedBox(width: 4),
                    AppStatusBadge(
                      label: switch (env.status) {
                        'ACCEPTED_BY_CUSTOMS' => context.l10n.cargoxFilterAccepted,
                        'UPLOADED_BY_SUPPLIER' => context.l10n.cargoxFilterUploaded,
                        'SEALED_AND_TRANSFERRED' => context.l10n.cargoxFilterAccepted,
                        'DRAFT' => context.l10n.cargoxFilterDraft,
                        _ => env.status,
                      },
                      severity: switch (env.status) {
                        'ACCEPTED_BY_CUSTOMS' => AppSeverity.success,
                        'UPLOADED_BY_SUPPLIER' => AppSeverity.info,
                        'SEALED_AND_TRANSFERRED' => AppSeverity.info,
                        'DRAFT' => AppSeverity.warning,
                        _ => AppSeverity.info,
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18),

            // Metadata Grid
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _buildMetaItem(context.l10n.cargoxMetaAcidNumber, env.acidNumber, isCopyable: true),
                _buildMetaItem(context.l10n.cargoxMetaSupplier, env.supplierName),
                _buildMetaItem(context.l10n.cargoxMetaSupplierCargoxId, env.supplierCargoxId),
                _buildMetaItem(context.l10n.cargoxMetaBlNumber, env.blNumber ?? context.l10n.cargoxMetaPendingIssuance),
                if (env.blockchainTxHash != null)
                  _buildMetaItem(context.l10n.cargoxMetaBlockchainTxHash, '${env.blockchainTxHash!.substring(0, 16)}...', isCopyable: true, fullValue: env.blockchainTxHash),
                if (env.customsConfirmationReceipt != null)
                  _buildMetaItem(context.l10n.cargoxMetaCustomsReceipt, env.customsConfirmationReceipt!, isCopyable: true),
              ],
            ),
            const SizedBox(height: 12),

            // Documents chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: env.documents.map((d) {
                final docSummary = '${d.docType}: ${d.fileName} (${d.fileSizeKb} KB)';
                return ActionChip(
                  avatar: const Icon(Icons.attach_file, size: 14, color: AppTheme.cobalt),
                  label: Text('${_localizeDocType(context, d.docType)} (${d.fileName})', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.grey.shade100,
                  padding: const EdgeInsets.all(4),
                  tooltip: context.l10n.copyTooltip,
                  onPressed: () {
                    CopyHelper.copy(context, docSummary, customMessage: context.l10n.cargoxCopiedAttachedDocSuccess(d.fileName));
                  },
                );
              }).toList(),
            ),
            const Divider(height: 18),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.verified_outlined, size: 15, color: Colors.purple),
                  label: Text(context.l10n.cargoxCheckAcidBtn, style: const TextStyle(fontSize: 11, color: Colors.purple)),
                  onPressed: () => _runAcidVerification(env.envelopeId),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.receipt_long, size: 15, color: AppTheme.cobalt),
                  label: Text(context.l10n.cargoxDigitalManifestBtn, style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                  onPressed: () => _viewManifest(env),
                ),
                const SizedBox(width: 8),
                if (!isAccepted)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.send_to_mobile, size: 15, color: Colors.white),
                    label: Text(context.l10n.cargoxSealAndTransferBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _sealAndTransfer(env),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade300)),
                    child: Text(context.l10n.cargoxDeliveredAndAcceptedBadge, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, {bool isCopyable = false, String? fullValue}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
        if (isCopyable) ...[
          const SizedBox(width: 2),
          InkWell(
            onTap: () {
              CopyHelper.copy(
                context,
                fullValue ?? value,
                customMessage: context.l10n.cargoxCopiedToClipboard,
              );
            },
            child: const Icon(Icons.copy, size: 13, color: AppTheme.cobalt),
          ),
        ],
      ],
    );
  }


  Future<void> _runAcidVerification(int envelopeId) async {
    try {
      final report = await ref.read(cargoxEnvelopesProvider.notifier).verifyAcidConsistency(envelopeId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => SelectionArea(
            child: Dialog(
              backgroundColor: AppTheme.isDark(ctx) ? AppTheme.darkCardBackground : AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(report.allMatched ? Icons.verified : Icons.warning_amber, color: report.allMatched ? AppTheme.emerald : Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(context.l10n.cargoxAcidReportDialogTitle(report.envelopeCode), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(context.l10n.cargoxTargetAcidLabel(report.targetAcidNumber), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(context.l10n.cargoxMatchRatioLabel(report.verifiedCount, report.totalDocuments), style: const TextStyle(fontSize: 12)),
                      const Divider(),
                      ...report.items.map((item) => ListTile(
                            dense: true,
                            leading: Icon(item.isMatched ? Icons.check_circle : Icons.cancel, color: item.isMatched ? Colors.green : Colors.red, size: 18),
                            title: Text(item.docType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            subtitle: Text(item.notes ?? '', style: const TextStyle(fontSize: 11)),
                          )),
                      const SizedBox(height: 16),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.close)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.cargoxAcidCheckError, error: e);
      }
    }
  }

  Future<void> _sealAndTransfer(CargoXEnvelopeModel env) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: context.l10n.cargoxConfirmSealTransferTitle,
      message: context.l10n.cargoxConfirmSealTransferContent(env.envelopeCode),
      confirmLabel: context.l10n.cargoxConfirmTransferBtn,
      confirmVariant: AppButtonVariant.primary,
      icon: Icons.security,
    );

    if (confirm != true) return;

    try {
      final res = await ref.read(cargoxEnvelopesProvider.notifier).sealAndTransferToCustoms(
            env.envelopeId,
            blNumber: env.blNumber,
            mode: 'MOCK',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cargoxSealSuccessSnackbar(res['message'], res['customs_confirmation_receipt']),
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.cargoxTransferError, error: e);
      }
    }
  }

  void _viewManifest(CargoXEnvelopeModel env) async {
    setState(() {
      _selectedSubTab = 2;
      _isLoadingManifest = true;
    });

    try {
      final manifest = await ref.read(cargoxEnvelopesProvider.notifier).fetchDigitalManifest(env.envelopeId);
      if (mounted) {
        setState(() {
          _activeDigitalManifest = manifest;
          _isLoadingManifest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingManifest = false);
        showErrorDetailsDialog(context, title: context.l10n.cargoxFetchManifestError, error: e);
      }
    }
  }

  // ── TAB 2: ACI DIGITAL MANIFEST VIEWER ───────────────────────────────────────
  Widget _buildDigitalManifestViewerTab(List<CargoXEnvelopeModel> envelopes) {
    if (_isLoadingManifest) {
      return const AppLoadingState();
    }

    if (_activeDigitalManifest == null && envelopes.isNotEmpty) {
      if (!_isLoadingManifest) {
        Future.microtask(() => _viewManifest(envelopes.first));
      }
      return const AppLoadingState();
    }

    if (_activeDigitalManifest == null) {
      return Center(
        child: Text(context.l10n.cargoxSelectEnvelopeForManifestPrompt),
      );
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(_activeDigitalManifest!.manifestJson);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Control Bar
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.cargoxManifestTitle(_activeDigitalManifest!.envelopeCode, _activeDigitalManifest!.acidNumber),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.copy, size: 15, color: Colors.white),
                    label: Text(context.l10n.cargoxCopyJsonBtn, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    onPressed: () {
                      CopyHelper.copy(
                        context,
                        jsonStr,
                        customMessage: context.l10n.cargoxManifestCopiedToast,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // JSON Code Viewer Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: SelectableText(
              jsonStr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF9CDCFE),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
