import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../widgets/idoc_ui_b.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/live_pulse_badge.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../widgets/search_and_clone_acid_dialog.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/models/supplier_model.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';

class NafezaAcidScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const NafezaAcidScreen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<NafezaAcidScreen> createState() => _NafezaAcidScreenState();
}

class _NafezaAcidScreenState extends ConsumerState<NafezaAcidScreen> {
  // Active Vertical Sub-Tab:
  // 0: 📝 طلب إصدار ACID (Request Form)
  // 1: ⚡ الإدخال الذكي من نافذة (MTS Smart Parser)
  // 2: 🔍 المقارنة والتحقق الجمركي (Discrepancy Matrix)
  // 3: 📋 سجل إصدارات ACID (Registry)
  // 4: ⏳ متتبع الصلاحية والإفراج (Expiry Tracker)
  int _selectedSubTab = 0;

  // Selected Import File
  int? _selectedImportFileId;
  GuideMatchResultModel? _acidGuideMatchResult;

  // Controllers for Tab 0 (ACID Request)
  final _requestFormKey = GlobalKey<FormState>();
  final TextEditingController _acidNumberCtrl = TextEditingController();
  int? _selectedImporterId;
  final TextEditingController _importerNameCtrl = TextEditingController();
  final TextEditingController _importerTaxIdCtrl = TextEditingController();
  final TextEditingController _importerAddressCtrl = TextEditingController();

  int? _selectedSupplierId;
  final TextEditingController _exporterNameCtrl = TextEditingController();
  String _exporterRegType = 'VAT Number';
  final TextEditingController _exporterRegIdCtrl = TextEditingController();
  final TextEditingController _exporterCountryCtrl = TextEditingController();
  final TextEditingController _exporterCountryCodeCtrl = TextEditingController();
  final TextEditingController _exporterAddressCtrl = TextEditingController();
  final TextEditingController _exporterPhoneCtrl = TextEditingController();
  final TextEditingController _cargoxIdCtrl = TextEditingController();

  int? _selectedPoId;
  final TextEditingController _poNoCtrl = TextEditingController();
  final TextEditingController _poDateCtrl = TextEditingController();
  final TextEditingController _proformaNoCtrl = TextEditingController();
  final TextEditingController _proformaDateCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 10));
  String _invoiceType = 'Proforma Invoice';

  final TextEditingController _polCtrl = TextEditingController();
  final TextEditingController _podCtrl = TextEditingController();

  int? _selectedBrokerId;
  final TextEditingController _brokerNameCtrl = TextEditingController();
  final TextEditingController _brokerPhoneCtrl = TextEditingController();

  final TextEditingController _requestedDateCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 10));

  // Controllers for Tab 1 (Smart MTS Parser)
  final TextEditingController _rawMtsTextCtrl = TextEditingController();
  Map<String, dynamic>? _parsedMtsData;
  bool _isParsingMts = false;

  // Tab 2 (Comparison Result)
  AcidComparisonResult? _comparisonResult;
  bool _isComparing = false;
  final TextEditingController _discrepancyOverrideReasonCtrl = TextEditingController();

  // Tab 3 (Registry & Final Save)
  String _acidSearchQuery = '';
  final TextEditingController _generatedDateCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 10));
  final TextEditingController _expiryDateCtrl = TextEditingController(
    text: DateTime.now().add(const Duration(days: 90)).toString().substring(0, 10),
  );

  bool _isSaving = false;
  int? _editingAcidSessionId;
  String? _editingAcidCode;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(NafezaAcidScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() => _selectedSubTab = widget.initialSubTab);
    }
    if (oldWidget.initialImportFileId != widget.initialImportFileId) {
      _onImportFileChanged(widget.initialImportFileId);
    }
  }

  void _refreshData() {
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(importCompaniesProvider).isLoading) {
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
    }
    if (!ref.read(suppliersProvider).isLoading) {
      ref.read(suppliersProvider.notifier).fetchSuppliers();
    }
    if (!ref.read(partnersProvider).isLoading) {
      ref.read(partnersProvider.notifier).fetchPartners();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
    if (!ref.read(acidSessionsProvider).isLoading) {
      ref.read(acidSessionsProvider.notifier).fetchAcidSessions();
    }
    if (!ref.read(acidTrackerProvider).isLoading) {
      ref.read(acidTrackerProvider.notifier).fetchAcidTracker();
    }
  }

  @override
  void dispose() {
    _acidNumberCtrl.dispose();
    _importerNameCtrl.dispose();
    _importerTaxIdCtrl.dispose();
    _importerAddressCtrl.dispose();
    _exporterNameCtrl.dispose();
    _exporterRegIdCtrl.dispose();
    _exporterCountryCtrl.dispose();
    _exporterCountryCodeCtrl.dispose();
    _exporterAddressCtrl.dispose();
    _exporterPhoneCtrl.dispose();
    _cargoxIdCtrl.dispose();
    _poNoCtrl.dispose();
    _poDateCtrl.dispose();
    _proformaNoCtrl.dispose();
    _proformaDateCtrl.dispose();
    _polCtrl.dispose();
    _podCtrl.dispose();
    _brokerNameCtrl.dispose();
    _brokerPhoneCtrl.dispose();
    _requestedDateCtrl.dispose();
    _rawMtsTextCtrl.dispose();
    _discrepancyOverrideReasonCtrl.dispose();
    _generatedDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onImportFileChanged(int? fileId) {
    setState(() => _selectedImportFileId = fileId);
    if (fileId == null) {
      setState(() {
        _editingAcidSessionId = null;
        _editingAcidCode = null;
      });
      return;
    }

    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) return;

    // Check if an existing ACID session exists for this import file
    final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    final existingSession = sessions.where((s) => s.importFileId == fileId && s.isActive).firstOrNull;
    if (existingSession != null) {
      _editingAcidSessionId = existingSession.acidId;
      _editingAcidCode = existingSession.acidCode;
      if (existingSession.acidNumber.isNotEmpty && existingSession.acidNumber != 'PENDING') {
        _acidNumberCtrl.text = existingSession.acidNumber;
      }
    } else {
      _editingAcidSessionId = null;
      _editingAcidCode = null;
    }

    // Importer
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final matchedComp = companies.where((c) => c.companyId == file.companyId).firstOrNull;
    if (matchedComp != null) {
      _selectedImporterId = matchedComp.companyId;
      _importerNameCtrl.text = matchedComp.importerName;
      _importerTaxIdCtrl.text = matchedComp.vatId;
      _importerAddressCtrl.text = matchedComp.address;
    } else {
      _importerNameCtrl.text = file.companyName;
    }

    // Exporter
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final matchedSupp = suppliers.where((s) => s.supplierId == file.supplierId).firstOrNull;
    if (matchedSupp != null) {
      _selectedSupplierId = matchedSupp.supplierId;
      _exporterNameCtrl.text = matchedSupp.companyName;
      _exporterCountryCtrl.text = matchedSupp.foreignExporterCountry;
      _exporterCountryCodeCtrl.text = matchedSupp.foreignExporterCountryCode;
      _exporterAddressCtrl.text = matchedSupp.address;
      _exporterPhoneCtrl.text = matchedSupp.phone ?? '';
      _cargoxIdCtrl.text = matchedSupp.cargoxPlatformId ?? '';
      _exporterRegIdCtrl.text = matchedSupp.foreignExporterId;
      _exporterRegType = matchedSupp.registrationType.isNotEmpty ? matchedSupp.registrationType : 'Company Registration Number';
    } else {
      _exporterNameCtrl.text = file.supplierName;
    }

    // Broker
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final matchedBroker = partners.where((p) => p.providerId == file.brokerId).firstOrNull;
    if (matchedBroker != null) {
      _selectedBrokerId = matchedBroker.providerId;
      _brokerNameCtrl.text = matchedBroker.partnerName;
      _brokerPhoneCtrl.text = matchedBroker.phone ?? '';
    }

    // PO & Proforma
    final pos = ref.read(purchaseOrdersProvider).purchaseOrders;
    final matchedPo = pos.where((p) => p.importFileId == fileId).firstOrNull;
    if (matchedPo != null) {
      _selectedPoId = matchedPo.poId;
      _poDateCtrl.text = matchedPo.orderDate != null ? matchedPo.orderDate!.toIso8601String().substring(0, 10) : '';
    } else {
      _selectedPoId = null;
      _poDateCtrl.text = '';
    }

    if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
      _poNoCtrl.text = file.poNumber!.trim();
    } else if (matchedPo != null) {
      _poNoCtrl.text = (matchedPo.poReference != null && matchedPo.poReference!.trim().isNotEmpty)
          ? matchedPo.poReference!.trim()
          : matchedPo.poNumber;
    } else {
      _poNoCtrl.text = '';
    }

    if (file.piNumber != null && file.piNumber!.trim().isNotEmpty) {
      _proformaNoCtrl.text = file.piNumber!.trim();
    } else if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
      _proformaNoCtrl.text = file.poNumber!.trim();
    } else if (matchedPo != null && matchedPo.proformaInvoiceNumber != null && matchedPo.proformaInvoiceNumber!.isNotEmpty) {
      _proformaNoCtrl.text = matchedPo.proformaInvoiceNumber!;
    } else {
      _proformaNoCtrl.text = '';
    }

    if (_polCtrl.text.isEmpty || _polCtrl.text == 'Shanghai Port (CNSHA)') {
      _polCtrl.text = 'CHANGSHU';
    }
    if (_podCtrl.text.isEmpty || _podCtrl.text == 'Alexandria Port (EG ALX)') {
      _podCtrl.text = 'Alexandria';
    }
    _loadAcidGuide(file);
  }

  Future<void> _loadAcidGuide(dynamic file) async {
    try {
      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: file.supplierName,
        hsCode: file.hsCode,
        productCategory: file.productCategory,
        portOfDischarge: file.portOfDischarge,
        shippingLine: file.shippingLine,
        incoterm: file.incotermCode,
        importFileReference: file.importFileCode,
      );
      if (mounted) {
        setState(() => _acidGuideMatchResult = res);
      }
    } catch (_) {}
  }

  void _openSearchAndCloneDialog() {
    final acidSessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SearchAndCloneAcidDialog(
            sessions: acidSessions,
            onSelectSession: _onCloneAcidSelected,
          ),
        ),
      ),
    );
  }

  void _onCloneAcidSelected(AcidRegistrationModel session) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CloneEntityReviewDialog(
            entityType: l.idocBAcidCloneEntity,
            sourceCode: session.acidNumber.isNotEmpty ? session.acidNumber : session.acidCode,
            sourceTitle: session.importerName,
            suggestedNewCode: 'ACID-EG-2026-DRAFT',
            copiedFieldsSummary: {
              l.idocBAcidCloneFieldImporter: session.importerName,
              l.idocBAcidCloneFieldExporter: session.exporterName,
              l.idocBAcidCloneFieldCountry: session.exporterCountry,
              l.idocBAcidCloneFieldProforma: session.proformaInvoiceNo,
              l.idocBAcidCloneFieldPorts: '${session.polName} → ${session.podName}',
            },
            mandatorilyResetFields: [
              l.idocBAcidCloneReset1,
              l.idocBAcidCloneReset2,
              l.idocBAcidCloneReset3,
              l.idocBAcidCloneReset4,
            ],
            allowCopyLineItems: false,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              setState(() {
                _editingAcidSessionId = null;
                _editingAcidCode = null;
                _selectedSubTab = 0;
                _selectedImportFileId = session.importFileId;
                _acidNumberCtrl.text = 'ACID-EG-2026-';
                _selectedImporterId = session.importerId;
                _importerNameCtrl.text = session.importerName;
                _importerTaxIdCtrl.text = session.importerTaxId;
                _importerAddressCtrl.text = session.importerAddress ?? '';
                _selectedSupplierId = session.supplierId;
                _exporterNameCtrl.text = session.exporterName;
                _exporterCountryCtrl.text = session.exporterCountry;
                _exporterAddressCtrl.text = session.exporterAddress ?? '';
                _exporterPhoneCtrl.text = session.exporterPhone ?? '';
                _cargoxIdCtrl.text = session.cargoxId ?? '';
                _exporterRegIdCtrl.text = session.exporterRegId;
                _exporterRegType = session.exporterRegType ?? 'VAT Number';
                _selectedPoId = session.poId;
                _poNoCtrl.text = session.poNumber ?? '';
                // Business reference: stored suffix is English in every UI language.
                _proformaNoCtrl.text = '${session.proformaInvoiceNo}${TableRowCloneHelper.copySuffix}';
                _proformaDateCtrl.text = session.proformaInvoiceDate ?? DateTime.now().toString().substring(0, 10);
                _invoiceType = session.invoiceType ?? 'Proforma Invoice';
                _polCtrl.text = session.polName;
                _podCtrl.text = session.podName;
                _selectedBrokerId = session.customsBrokerId;
                _brokerNameCtrl.text = session.customsBrokerName ?? '';
                _brokerPhoneCtrl.text = session.customsBrokerPhone ?? '';
                _requestedDateCtrl.text = DateTime.now().toString().substring(0, 10);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.cloneAcidSuccess),
                  backgroundColor: AppTheme.wcagEmerald,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openImportRawTextFromPreviousDialog() {
    final acidSessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SearchAndCloneAcidDialog(
            sessions: acidSessions,
            onSelectSession: (session) {
              final acidNum = session.acidNumber.isNotEmpty && session.acidNumber != 'PENDING'
                  ? session.acidNumber
                  : '';

              final rawReconstructed = '''MTS Notification
Dear ${session.exporterName},

Kindly be informed that an Advance Cargo Information request (ACI) has been approved for shipping:
[ACID: $acidNum]
Requested: ${session.requestedDate ?? ''}   Generated: ${session.generatedDate ?? ''}   Expires: ${session.expiryDate ?? ''}

Egyptian Importer
Egyptian Importer Name: ${session.importerName}
Egyptian Importer Tax ID: ${session.importerTaxId}
Address: ${session.importerAddress ?? ''}

Foreign Exporter
Foreign Exporter Name: ${session.exporterName}
Foreign Exporter ID: ${session.exporterRegId}
Registration Type: ${session.exporterRegType ?? 'Company Registration Number'}
Country of Export: ${session.exporterCountry}

Proforma Invoice No.: ${session.proformaInvoiceNo}
Port of Loading: ${session.polName}
Port of Discharge: ${session.podName}
CargoX Platform ID: ${session.cargoxId ?? ''}''';

              setState(() {
                _rawMtsTextCtrl.text = rawReconstructed;
                if (session.importFileId != null && _selectedImportFileId == null) {
                  _onImportFileChanged(session.importFileId);
                }
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.rawTextImportedSuccess),
                  backgroundColor: AppTheme.wcagEmerald,
                  behavior: SnackBarBehavior.floating,
                ),
              );

              _parseMtsText();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acidSessions = ref.watch(acidSessionsProvider).valueOrNull ?? [];
    final trackerSummary = ref.watch(acidTrackerProvider).valueOrNull;
    final trackerItems = trackerSummary?.items ?? [];

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.assignment_turned_in_outlined,
        titleEn: 'ACID Request Form',
        titleAr: 'طلب إصدار الرقم المبدئي',
      ),
      const VerticalNavTabItem(
        icon: Icons.smart_toy_outlined,
        titleEn: 'MTS Smart AI Parser',
        titleAr: 'الإدخال الذكي من نافذة',
      ),
      VerticalNavTabItem(
        icon: Icons.rule_folder_outlined,
        titleEn: 'Discrepancy Matrix',
        titleAr: 'المقارنة والتحقق الجمركي',
        badge: _comparisonResult != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _comparisonResult!.allMatched ? AppTheme.emerald.withValues(alpha: 0.2) : AppTheme.crimson.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _comparisonResult!.allMatched ? context.l10n.matchedStatus : context.l10n.discrepancyStatus,
                  style: TextStyle(
                    color: _comparisonResult!.allMatched ? AppTheme.emerald : AppTheme.crimson,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
      VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'ACID Issuance Registry',
        titleAr: 'سجل إصدارات ACID',
        badge: acidSessions.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${acidSessions.length}',
                  style: const TextStyle(color: AppTheme.cobalt, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
      VerticalNavTabItem(
        icon: Icons.timer_outlined,
        titleEn: 'Expiry & Release Tracker',
        titleAr: 'متتبع الصلاحية والإفراج',
        badge: trackerItems.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${trackerItems.length}',
                  style: const TextStyle(color: AppTheme.orange, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'PHASE-2: STEP_05',
      titleEn: 'Nafeza Advance Cargo Information (ACID)',
      titleAr: 'منظومة نافذة والتسجيل المسبق للشحنات',
      headerIcon: Icons.qr_code_scanner_outlined,
      headerColor: AppTheme.charcoal,
      tabs: tabs,
      selectedIndex: _selectedSubTab,
      onTabSelected: (index) {
        setState(() => _selectedSubTab = index);
        if (index == 3) {
          ref.read(acidSessionsProvider.notifier).fetchAcidSessions();
        } else if (index == 4) {
          ref.read(acidTrackerProvider.notifier).fetchAcidTracker();
        }
      },
      selectedImportFileId: _selectedImportFileId,
      onShipmentStatusChanged: _refreshData,
      headerActions: [
        IdocBUi.fit(AppButton(key: const Key('searchAndCloneAcidBtn'), label: context.l10n.searchAndCloneAcidBtn, onPressed: _openSearchAndCloneDialog, variant: AppButtonVariant.secondary, size: AppButtonSize.small, icon: Icons.copy_all)),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppTheme.cloudWhite),
          tooltip: context.l10n.refresh,
          onPressed: _refreshData,
        ),
      ],
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openSearchAndCloneDialog,
        },
        child: Focus(
          autofocus: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: _buildCurrentSubTabContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return _buildAcidRequestTab();
      case 1:
        return _buildSmartMtsParserTab();
      case 2:
        return _buildDiscrepancyMatrixTab();
      case 3:
        return _buildAcidSessionsRegistryTab();
      case 4:
        return _buildExpiryTrackerTab();
      default:
        return _buildAcidRequestTab();
    }
  }

  // --- SUB-VIEW 0: ACID REQUEST FORM ---
  Widget _buildAcidRequestTab() {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importCompanies = ref.watch(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final partners = ref.watch(partnersProvider).valueOrNull ?? [];
    final brokers = partners.where((p) => p.partnerType.contains('Broker') || p.partnerType.contains('مخلص')).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Form(
          key: _requestFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Smart Experience Guide Alert Banner
              if (_acidGuideMatchResult != null && _acidGuideMatchResult!.matchedEntries.isNotEmpty)
                ExperienceGuideAlertBanner(
                  matchResult: _acidGuideMatchResult!,
                  supplier: _exporterNameCtrl.text,
                  portOfDischarge: _podCtrl.text,
                  portOfLoading: _polCtrl.text,
                ),

              // Informational Alert
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cobaltLight : AppTheme.infoBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.5) : AppTheme.cobaltBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.wcagCobalt, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.acidInfoBanner,
                        style: TextStyle(
                          color: isDark ? AppTheme.darkHyperlink : AppTheme.infoForeground,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Edit Mode Banner
              if (_editingAcidSessionId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.orangeLight : AppTheme.warningBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppTheme.wcagOrange : AppTheme.orange, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: AppTheme.orange, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CopyableText(
                              '${context.l10n.activeEditModeBanner}: ${_editingAcidCode ?? ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.orange : AppTheme.warningForeground,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.acidSessionLoadedForEdit(_editingAcidCode ?? ''),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IdocBUi.fit(AppButton(label: context.l10n.cancelEdit, onPressed: () {
                          setState(() {
                            _editingAcidSessionId = null;
                            _editingAcidCode = null;
                          });
                        }, variant: AppButtonVariant.secondary, icon: Icons.close)),
                    ],
                  ),
                ),
              ],

              // File Selector Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecorationOf(context),
                child: SearchableDropdownField<int>(
                  labelText: context.l10n.selectImportFileAcidLabel,
                  hintText: context.l10n.searchFileOrSupplierHint,
                  value: _selectedImportFileId,
                  isRequired: true,
                  items: importFiles.map((f) => SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName} (${f.companyName})',
                  )).toList(),
                  onChanged: _onImportFileChanged,
                ),
              ),
              const SizedBox(height: 20),

              // Importer & Exporter Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.importerAndExporterSection,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    const Divider(height: 24),
                    if (isMobile) ...[
                      // Mobile Stacked Importer & Exporter
                      _buildImporterSection(importCompanies),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildExporterSection(suppliers),
                    ] else ...[
                      // Desktop Side-by-Side Importer & Exporter
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildImporterSection(importCompanies)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildExporterSection(suppliers)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Invoice, Ports & Broker Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.proformaPortsBrokerSection,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    const Divider(height: 24),
                    if (isMobile) ...[
                      TextFormField(
                        controller: _proformaNoCtrl,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.proformaInvoiceNoLabel} *',
                          prefixIcon: const Icon(Icons.receipt_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? context.l10n.proformaInvoiceNoLabel : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _proformaDateCtrl,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.proformaInvoiceDateLabel} *',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdownField<String>(
                        value: _invoiceType,
                        labelText: context.l10n.invoiceTypeLabel,
                        items: [
                          SearchableDropdownItem(value: 'Proforma Invoice', label: context.l10n.proformaInvoiceLabel),
                          SearchableDropdownItem(value: 'Commercial Invoice', label: context.l10n.commercialInvoiceLabel),
                        ],
                        onChanged: (val) => setState(() => _invoiceType = val ?? 'Proforma Invoice'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _polCtrl,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.portOfLoadingLabel} *',
                          prefixIcon: const Icon(Icons.directions_boat_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? context.l10n.portOfLoadingLabel : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _podCtrl,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.portOfDischargeLabel} *',
                          prefixIcon: const Icon(Icons.anchor),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? context.l10n.portOfDischargeLabel : null,
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdownField<int>(
                        labelText: context.l10n.customsBrokerResponsibleLabel,
                        hintText: context.l10n.searchFileOrSupplierHint,
                        value: _selectedBrokerId,
                        items: brokers.map((b) => SearchableDropdownItem<int>(
                          value: b.providerId ?? 0,
                          label: '${b.partnerName} (${b.partnerCode})',
                        )).toList(),
                        onChanged: (val) {
                          setState(() => _selectedBrokerId = val);
                          final b = brokers.where((brk) => brk.providerId == val).firstOrNull;
                          if (b != null) {
                            _brokerNameCtrl.text = b.partnerName;
                            _brokerPhoneCtrl.text = b.phone ?? '';
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _brokerPhoneCtrl,
                        decoration: InputDecoration(
                          labelText: context.l10n.brokerPhoneLabel,
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _requestedDateCtrl,
                        decoration: InputDecoration(
                          labelText: '${context.l10n.acidRequestDateLabel} *',
                          prefixIcon: const Icon(Icons.event_available),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _proformaNoCtrl,
                              decoration: InputDecoration(
                                labelText: '${context.l10n.proformaInvoiceNoLabel} *',
                                prefixIcon: const Icon(Icons.receipt_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? context.l10n.proformaInvoiceNoLabel : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _proformaDateCtrl,
                              decoration: InputDecoration(
                                labelText: '${context.l10n.proformaInvoiceDateLabel} *',
                                prefixIcon: const Icon(Icons.calendar_today_outlined),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: _invoiceType,
                              labelText: context.l10n.invoiceTypeLabel,
                              items: [
                                SearchableDropdownItem(value: 'Proforma Invoice', label: context.l10n.proformaInvoiceLabel),
                                SearchableDropdownItem(value: 'Commercial Invoice', label: context.l10n.commercialInvoiceLabel),
                              ],
                              onChanged: (val) => setState(() => _invoiceType = val ?? 'Proforma Invoice'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _polCtrl,
                              decoration: InputDecoration(
                                labelText: '${context.l10n.portOfLoadingLabel} *',
                                prefixIcon: const Icon(Icons.directions_boat_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? context.l10n.portOfLoadingLabel : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _podCtrl,
                              decoration: InputDecoration(
                                labelText: '${context.l10n.portOfDischargeLabel} *',
                                prefixIcon: const Icon(Icons.anchor),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? context.l10n.portOfDischargeLabel : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SearchableDropdownField<int>(
                              labelText: context.l10n.customsBrokerResponsibleLabel,
                              hintText: context.l10n.searchFileOrSupplierHint,
                              value: _selectedBrokerId,
                              items: brokers.map((b) => SearchableDropdownItem<int>(
                                value: b.providerId ?? 0,
                                label: '${b.partnerName} (${b.partnerCode})',
                              )).toList(),
                              onChanged: (val) {
                                setState(() => _selectedBrokerId = val);
                                final b = brokers.where((brk) => brk.providerId == val).firstOrNull;
                                if (b != null) {
                                  _brokerNameCtrl.text = b.partnerName;
                                  _brokerPhoneCtrl.text = b.phone ?? '';
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _brokerPhoneCtrl,
                              decoration: InputDecoration(
                                labelText: context.l10n.brokerPhoneLabel,
                                prefixIcon: const Icon(Icons.phone_outlined),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _requestedDateCtrl,
                              decoration: InputDecoration(
                                labelText: '${context.l10n.acidRequestDateLabel} *',
                                prefixIcon: const Icon(Icons.event_available),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Submit & Action Buttons
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        IdocBUi.fit(AppButton(key: const Key('saveAcidRequestSubmitBtn'), label: _isSaving
                                ? context.l10n.loading
                                : (_editingAcidSessionId != null ? context.l10n.updateAcidRequestButton : context.l10n.saveAcidRequestButton), onPressed: _isSaving ? null : _saveAcidRequest, icon: Icons.save, isLoading: _isSaving)),
                        IdocBUi.fit(AppButton(label: context.l10n.goToSmartParserButton, onPressed: () => setState(() => _selectedSubTab = 1), variant: AppButtonVariant.secondary, icon: Icons.smart_toy_outlined)),
                        IdocBUi.fit(AppButton(key: const Key('subtab0SearchAndCloneBtn'), label: context.l10n.searchAndCloneAcidBtn, onPressed: _openSearchAndCloneDialog, variant: AppButtonVariant.secondary, icon: Icons.copy_all)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live Generated Broker Message Preview Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.emeraldLight : AppTheme.successBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppTheme.wcagEmerald.withValues(alpha: 0.5) : AppTheme.emeraldBorder, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mark_email_read_outlined, color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.brokerDispatchMessageTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.brokerDispatchMessageSub,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IdocBUi.fit(AppButton(label: context.l10n.copyArabicWhatsApp, onPressed: () {
                            CopyHelper.copy(context, _buildWhatsAppMessage(), customMessage: context.l10n.whatsAppMessageCopied);
                          }, variant: AppButtonVariant.success, icon: Icons.copy)),
                        IdocBUi.fit(AppButton(label: context.l10n.copyEnglishRequest, onPressed: () {
                            CopyHelper.copy(context, _buildEnglishRequestMessage(), customMessage: context.l10n.acidRequestCopied);
                          }, icon: Icons.language)),
                        IdocBUi.fit(AppButton(label: context.l10n.emailTemplateButton, onPressed: () {
                            CopyHelper.copy(context, _buildEmailMessage(), customMessage: context.l10n.emailTemplateCopied);
                          }, variant: AppButtonVariant.secondary, icon: Icons.email_outlined)),
                      ],
                    ),
                    const Divider(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.emeraldBorder),
                      ),
                      child: SelectableText(
                        Localizations.localeOf(context).languageCode == 'en' ? _buildEnglishRequestMessage() : _buildWhatsAppMessage(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImporterSection(List<dynamic> importCompanies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🏢 ${context.l10n.importerSectionTitle}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        SearchableDropdownField<int>(
          labelText: context.l10n.importerSectionTitle,
          hintText: context.l10n.searchFileOrSupplierHint,
          value: _selectedImporterId,
          isRequired: true,
          items: importCompanies.map((c) => SearchableDropdownItem<int>(
            value: c.companyId ?? 0,
            label: '${c.importerName} (${c.importerId})',
          )).toList(),
          onChanged: (val) {
            setState(() => _selectedImporterId = val);
            final c = importCompanies.where((comp) => comp.companyId == val).firstOrNull;
            if (c != null) {
              _importerNameCtrl.text = c.importerName;
              _importerTaxIdCtrl.text = c.vatId;
              _importerAddressCtrl.text = c.address;
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _importerTaxIdCtrl,
          decoration: InputDecoration(
            labelText: '${context.l10n.importerTaxIdLabel} *',
            prefixIcon: const Icon(Icons.badge_outlined),
            border: const OutlineInputBorder(),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? context.l10n.importerTaxIdLabel : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _importerAddressCtrl,
          decoration: InputDecoration(
            labelText: context.l10n.importerAddressLabel,
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildExporterSection(List<dynamic> suppliers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🌍 ${context.l10n.foreignExporterSectionTitle}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        SearchableDropdownField<int>(
          labelText: context.l10n.foreignExporterSectionTitle,
          hintText: context.l10n.searchFileOrSupplierHint,
          value: _selectedSupplierId,
          isRequired: true,
          items: suppliers.map((s) => SearchableDropdownItem<int>(
            value: s.supplierId ?? 0,
            label: '${s.companyName} (${s.foreignExporterCountry})',
          )).toList(),
          onChanged: (val) {
            setState(() => _selectedSupplierId = val);
            final s = suppliers.where((supp) => supp.supplierId == val).firstOrNull;
            if (s != null) {
              _exporterNameCtrl.text = s.companyName;
              _exporterCountryCtrl.text = s.foreignExporterCountry;
              _exporterAddressCtrl.text = s.address;
              _exporterPhoneCtrl.text = s.phone ?? '';
              _cargoxIdCtrl.text = s.cargoxPlatformId ?? '';
              _exporterRegIdCtrl.text = s.foreignExporterId;
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _exporterRegIdCtrl,
                decoration: InputDecoration(
                  labelText: '${context.l10n.foreignExporterIdLabel} *',
                  helperText: _exporterRegType,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? context.l10n.foreignExporterIdLabel : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SearchableDropdownField<String>(
                value: _exporterRegType,
                labelText: context.l10n.regTypeLabel,
                items: [
                  SearchableDropdownItem(value: 'VAT Number', label: context.l10n.vatRegType),
                  SearchableDropdownItem(value: 'Commercial Register', label: context.l10n.crRegType),
                  SearchableDropdownItem(value: 'Tax ID', label: context.l10n.taxIdRegType),
                  SearchableDropdownItem(value: 'DUNS Number', label: context.l10n.dunsRegType),
                ],
                onChanged: (val) => setState(() => _exporterRegType = val ?? 'VAT Number'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _exporterCountryCtrl,
                decoration: InputDecoration(
                  labelText: '${context.l10n.countryOfOriginExportLabel} *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? context.l10n.countryOfOriginExportLabel : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _cargoxIdCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.cargoxPlatformIdLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- SUB-VIEW 1: SMART MTS PARSER TAB ---
  Widget _buildSmartMtsParserTab() {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.emeraldLight : AppTheme.infoBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.wcagEmerald.withValues(alpha: 0.4) : AppTheme.cobaltBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: isDark ? AppTheme.wcagEmerald : AppTheme.cobalt, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.smartParserInfoBanner,
                      style: TextStyle(
                        color: isDark ? AppTheme.emerald : AppTheme.infoForeground,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // File Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecorationOf(context),
              child: SearchableDropdownField<int>(
                labelText: context.l10n.linkImportFileResult,
                hintText: context.l10n.searchFileOrSupplierHint,
                value: _selectedImportFileId,
                items: importFiles.map((f) => SearchableDropdownItem<int>(
                  value: f.importFileId,
                  label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName}',
                )).toList(),
                onChanged: (val) => _onImportFileChanged(val),
              ),
            ),
            const SizedBox(height: 20),

            // Raw Text Input Box
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              decoration: AppTheme.cardDecorationOf(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.l10n.pasteRawMtsTextTitle}:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (kDebugMode)
                      IdocBUi.fit(AppButton(label: context.l10n.loadSampleMtsTextButton, onPressed: _loadSampleMtsText, variant: AppButtonVariant.secondary, size: AppButtonSize.small, icon: Icons.auto_fix_high)),
                      IdocBUi.fit(AppButton(label: context.l10n.importFromPreviousAcidSessionBtn, onPressed: _openImportRawTextFromPreviousDialog, variant: AppButtonVariant.secondary, size: AppButtonSize.small, icon: Icons.history_edu)),
                      IdocBUi.fit(AppButton(label: context.l10n.pasteFromClipboardButton, onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _rawMtsTextCtrl.text = data!.text!;
                          }
                        }, variant: AppButtonVariant.secondary, icon: Icons.paste)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rawMtsTextCtrl,
                    maxLines: 8,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.mtsNotificationHint,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      IdocBUi.fit(AppButton(label: _isParsingMts ? context.l10n.loading : context.l10n.runSmartParserButton, onPressed: _isParsingMts ? null : _parseMtsText, icon: Icons.bolt, isLoading: _isParsingMts)),
                      IdocBUi.fit(AppButton(label: context.l10n.clearTextButton, onPressed: () => setState(() {
                          _rawMtsTextCtrl.clear();
                          _parsedMtsData = null;
                        }), variant: AppButtonVariant.secondary, icon: Icons.clear_all)),
                    ],
                  ),
                ],
              ),
            ),

            if (_parsedMtsData != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false)
                        ? (isDark ? AppTheme.wcagEmerald : AppTheme.cobaltBorder)
                        : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile) ...[
                      Row(
                        children: [
                          Icon(
                            (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false) ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false)
                                ? (isDark ? AppTheme.wcagEmerald : AppTheme.cobalt)
                                : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false)
                                  ? context.l10n.parsedMtsSuccessTitle
                                  : context.l10n.parsedMtsNoAcidTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false)
                                    ? (isDark ? AppTheme.wcagEmerald : AppTheme.cobalt)
                                    : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      IdocBUi.fit(AppButton(label: context.l10n.goToVerificationButton, onPressed: () {
                          setState(() => _selectedSubTab = 2);
                          if (_selectedImportFileId != null) {
                            _runComparison();
                          }
                        }, icon: Icons.compare_arrows)),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false) ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false)
                                ? (isDark ? AppTheme.wcagEmerald : AppTheme.cobalt)
                                : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false)
                                  ? context.l10n.parsedMtsSuccessTitle
                                  : context.l10n.parsedMtsNoAcidTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: (_parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false)
                                    ? (isDark ? AppTheme.wcagEmerald : AppTheme.cobalt)
                                    : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IdocBUi.fit(AppButton(label: context.l10n.goToVerificationButton, onPressed: () {
                              setState(() => _selectedSubTab = 2);
                              if (_selectedImportFileId != null) {
                                _runComparison();
                              }
                            }, icon: Icons.compare_arrows)),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _buildExtractedField(context.l10n.acidNumberCol, _parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false ? _parsedMtsData!['acid_number']!.toString() : '-'),
                        _buildExtractedField(context.l10n.issueDateCol, _parsedMtsData!['generated_date']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.expiryDateCol, _parsedMtsData!['expiry_date']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.importerCompanyCol, _parsedMtsData!['importer_name']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.importerTaxIdLabel, _parsedMtsData!['importer_tax_id']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.foreignExporterCol, _parsedMtsData!['exporter_name']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.foreignExporterIdLabel, _parsedMtsData!['exporter_reg_id']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.regTypeLabel, _parsedMtsData!['exporter_reg_type']?.toString() ?? 'Company Registration Number'),
                        _buildExtractedField(context.l10n.countryOfOriginExportLabel, _parsedMtsData!['exporter_country']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.cargoxPlatformIdLabel, _parsedMtsData!['cargox_id']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.proformaInvoiceNoLabel, _parsedMtsData!['proforma_invoice_no']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.portOfLoadingLabel, _parsedMtsData!['pol_name']?.toString() ?? '-'),
                        _buildExtractedField(context.l10n.portOfDischargeLabel, _parsedMtsData!['pod_name']?.toString() ?? '-'),
                      ],
                    ),
                    const Divider(height: 24),
                    // Action Buttons Bar
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        IdocBUi.fit(AppButton(label: context.l10n.saveAndCertifyAcidButton, onPressed: _isSaving ? null : () => _saveMtsResultAsAcidSession(isDraft: false), variant: AppButtonVariant.success, icon: Icons.save_as)),
                        IdocBUi.fit(AppButton(label: context.l10n.saveTempDraftButton, onPressed: _isSaving ? null : () => _saveMtsResultAsAcidSession(isDraft: true), icon: Icons.save_outlined)),
                        IdocBUi.fit(AppButton(label: context.l10n.editExtractedDataButton, onPressed: _showEditMtsDataDialog, variant: AppButtonVariant.secondary, icon: Icons.edit)),
                        IdocBUi.fit(AppButton(label: context.l10n.codeSupplierButton, onPressed: _codeSupplierFromMts, icon: Icons.business_outlined)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildExtractedField(String label, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          CopyableText(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB-VIEW 2: DISCREPANCY MATRIX TAB ---
  Widget _buildDiscrepancyMatrixTab() {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File Selector & Compare Trigger
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 16),
              decoration: AppTheme.cardDecorationOf(context),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SearchableDropdownField<int>(
                          labelText: context.l10n.selectImportFileAcidLabel,
                          hintText: context.l10n.searchFileOrSupplierHint,
                          value: _selectedImportFileId,
                          items: importFiles.map((f) => SearchableDropdownItem<int>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName}',
                          )).toList(),
                          onChanged: (val) {
                            _onImportFileChanged(val);
                            if (val != null && _parsedMtsData != null) {
                              _runComparison();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        IdocBUi.fit(AppButton(label: context.l10n.runDiscrepancyMatrixButton, onPressed: _isComparing ? null : _runComparison, icon: Icons.compare_arrows, isLoading: _isComparing)),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<int>(
                            labelText: context.l10n.selectImportFileAcidLabel,
                            hintText: context.l10n.searchFileOrSupplierHint,
                            value: _selectedImportFileId,
                            items: importFiles.map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName}',
                            )).toList(),
                            onChanged: (val) {
                              _onImportFileChanged(val);
                              if (val != null && _parsedMtsData != null) {
                                _runComparison();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        IdocBUi.fit(AppButton(label: context.l10n.runDiscrepancyMatrixButton, onPressed: _isComparing ? null : _runComparison, icon: Icons.compare_arrows, isLoading: _isComparing)),
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            if (_comparisonResult == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  children: [
                    Icon(Icons.rule_folder_outlined, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.borderStrong),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.emptyComparisonHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_comparisonResult != null) ...[
              // Discrepancy Matrix Table
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile) ...[
                      Row(
                        children: [
                          Icon(
                            _comparisonResult!.allMatched ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: _comparisonResult!.allMatched
                                ? (isDark ? AppTheme.wcagEmerald : AppTheme.emerald)
                                : (isDark ? AppTheme.wcagOrange : AppTheme.crimson),
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _comparisonResult!.allMatched
                                      ? context.l10n.perfectMatchTitle
                                      : context.l10n.discrepancyFoundTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: _comparisonResult!.allMatched
                                        ? (isDark ? AppTheme.wcagEmerald : AppTheme.successForeground)
                                        : (AppTheme.crimson),
                                  ),
                                ),
                                Text(
                                  '${context.l10n.matchingStatusCol}: ${_comparisonResult!.matchPercentage.toStringAsFixed(1)}% (${_comparisonResult!.matchedCount} / ${_comparisonResult!.totalComparedFields})',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      IdocBUi.fit(AppButton(label: context.l10n.copyDiscrepancyReportBtn, onPressed: _copyDiscrepancyReportToClipboard, variant: AppButtonVariant.secondary, size: AppButtonSize.small, icon: Icons.copy)),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            _comparisonResult!.allMatched ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: _comparisonResult!.allMatched
                                ? (isDark ? AppTheme.wcagEmerald : AppTheme.emerald)
                                : (isDark ? AppTheme.wcagOrange : AppTheme.crimson),
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _comparisonResult!.allMatched
                                      ? context.l10n.perfectMatchTitle
                                      : context.l10n.discrepancyFoundTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: _comparisonResult!.allMatched
                                        ? (isDark ? AppTheme.wcagEmerald : AppTheme.successForeground)
                                        : (AppTheme.crimson),
                                  ),
                                ),
                                Text(
                                  '${context.l10n.matchingStatusCol}: ${_comparisonResult!.matchPercentage.toStringAsFixed(1)}% (${_comparisonResult!.matchedCount} / ${_comparisonResult!.totalComparedFields})',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IdocBUi.fit(AppButton(label: context.l10n.copyDiscrepancyReportBtn, onPressed: _copyDiscrepancyReportToClipboard, variant: AppButtonVariant.secondary, size: AppButtonSize.small, icon: Icons.copy)),
                        ],
                      ),
                    ],
                    const Divider(height: 24),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth < 650 ? 650 : constraints.maxWidth - (isMobile ? 28 : 40),
                        ),
                        child: Table(
                          border: TableBorder.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.border,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(1.5),
                            1: FlexColumnWidth(2),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    context.l10n.customsFieldCol,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    context.l10n.requestedValueCol,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    context.l10n.generatedValueCol,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    context.l10n.matchingStatusCol,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ..._comparisonResult!.items.map((item) {
                              return TableRow(
                                decoration: BoxDecoration(
                                  color: item.isMatched
                                      ? (isDark ? AppTheme.darkCardBackground : AppTheme.surface)
                                      : (isDark ? AppTheme.crimsonLight : AppTheme.dangerBackground.withValues(alpha: 0.5)),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      context.l10n.isArabic ? item.labelAr : item.labelEn,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CopyableText(
                                      item.requestedValue,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CopyableText(
                                      item.generatedValue,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.isMatched ? Icons.check_circle : Icons.cancel,
                                          size: 16,
                                          color: item.isMatched
                                              ? (isDark ? AppTheme.wcagEmerald : AppTheme.emerald)
                                              : (AppTheme.crimson),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.isMatched ? context.l10n.matchedStatus : context.l10n.discrepancyStatus,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: item.isMatched
                                                  ? (isDark ? AppTheme.wcagEmerald : AppTheme.emerald)
                                                  : (AppTheme.crimson),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Approval & Override
                    if (!_comparisonResult!.allMatched) ...[
                      Text(
                        context.l10n.discrepancyOverrideJustificationLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.crimson,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _discrepancyOverrideReasonCtrl,
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        decoration: InputDecoration(
                          hintText: context.l10n.discrepancyOverrideReasonHint,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    IdocBUi.fit(AppButton(label: _isSaving ? context.l10n.loading : context.l10n.verifyAndCertifyAcidButton, onPressed: _isSaving ? null : _saveVerifiedAcid, variant: AppButtonVariant.success, icon: Icons.verified, isLoading: _isSaving)),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // --- SUB-VIEW 3: ACID REGISTRY TAB ---
  Widget _buildAcidSessionsRegistryTab() {
    final acidSessions = ref.watch(acidSessionsProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = acidSessions.where((s) {
      if (_acidSearchQuery.isEmpty) return true;
      return s.acidNumber.toLowerCase().contains(_acidSearchQuery.toLowerCase()) ||
          (s.importFileCode != null && s.importFileCode!.toLowerCase().contains(_acidSearchQuery.toLowerCase())) ||
          s.exporterName.toLowerCase().contains(_acidSearchQuery.toLowerCase());
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('acidRegistrySearchField'),
                    style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    decoration: InputDecoration(
                      hintText: context.l10n.searchAcidRegistryHint,
                      hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                      prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    ),
                    onChanged: (val) => setState(() => _acidSearchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IdocBUi.fit(AppButton(key: const Key('acidRegistryNewRequestBtn'), label: context.l10n.newAcidRequestButton, onPressed: () => setState(() => _selectedSubTab = 0), icon: Icons.add)),
                      IdocBUi.fit(AppButton(key: const Key('acidRegistryCopyBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'نسخ الجدول' : 'Copy Table', onPressed: () => _copyAcidRegistryAsTsv(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.copy)),
                      IdocBUi.fit(AppButton(key: const Key('acidRegistryExcelBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير Excel' : 'Export Excel', onPressed: () => _exportAcidRegistryToExcel(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.table_chart)),
                      IdocBUi.fit(AppButton(key: const Key('acidRegistryPdfBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير PDF' : 'Export PDF', onPressed: () => _exportAcidRegistryToPdf(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                    ],
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('acidRegistrySearchField'),
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      decoration: InputDecoration(
                        hintText: context.l10n.searchAcidRegistryHint,
                        hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                        prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      ),
                      onChanged: (val) => setState(() => _acidSearchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IdocBUi.fit(AppButton(key: const Key('acidRegistryCopyBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'نسخ الجدول' : 'Copy Table', onPressed: () => _copyAcidRegistryAsTsv(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.copy)),
                  const SizedBox(width: 8),
                  IdocBUi.fit(AppButton(key: const Key('acidRegistryExcelBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير Excel' : 'Export Excel', onPressed: () => _exportAcidRegistryToExcel(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.table_chart)),
                  const SizedBox(width: 8),
                  IdocBUi.fit(AppButton(key: const Key('acidRegistryPdfBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير PDF' : 'Export PDF', onPressed: () => _exportAcidRegistryToPdf(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                  const SizedBox(width: 14),
                  IdocBUi.fit(AppButton(key: const Key('acidRegistryNewRequestBtn'), label: context.l10n.newAcidRequestButton, onPressed: () => setState(() => _selectedSubTab = 0), icon: Icons.add)),
                ],
              ),
            ],
            const SizedBox(height: 16),

            if (filtered.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.borderStrong),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.noAcidsFound,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                decoration: AppTheme.cardDecorationOf(context),
                child: SelectionArea(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < 750 ? 750 : constraints.maxWidth - (isMobile ? 28 : 40),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
                      columns: [
                        DataColumn(label: Text(context.l10n.actionCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.acidNumberCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.importFile, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.foreignExporterCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.importerCompanyCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.issueDateCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.expiryDateCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.validityStatusCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      ],
                      rows: filtered.map((s) {
                        final dateStr = s.generatedDate ?? s.requestedDate ?? '';
                        final expStr = s.expiryDate ?? '';
                        final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
                        final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
                        final poLabel = (s.poNumber != null && s.poNumber!.trim().isNotEmpty)
                            ? s.poNumber!.trim()
                            : (matchedFile?.poNumber ?? s.proformaInvoiceNo);
                        final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
                        final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
                        final statusLabel = isIssued
                            ? context.l10n.issuedAndValidStatus
                            : (isDraft ? context.l10n.tempDraftStatus : context.l10n.underReviewStatus);
                        final rowSummary = [
                          s.acidNumber,
                          fileLabel,
                          (poLabel.isNotEmpty && poLabel != '-') ? poLabel : '',
                          s.exporterName,
                          s.importerName,
                          dateStr.isNotEmpty ? dateStr.substring(0, min(10, dateStr.length)) : '-',
                          expStr.isNotEmpty ? expStr.substring(0, min(10, expStr.length)) : '-',
                          statusLabel,
                        ].join('\t');

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_note, color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt, size: 22),
                                    tooltip: context.l10n.edit,
                                    onPressed: () => _loadSessionForEdit(s),
                                  ),
                                  IconButton(
                                    key: Key('cloneRowBtn_${s.acidId}'),
                                    icon: Icon(Icons.copy_all, color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald, size: 20),
                                    tooltip: context.l10n.cloneAcidRecordTooltip,
                                    onPressed: () => _onCloneAcidSelected(s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                                    tooltip: context.l10n.delete,
                                    onPressed: () => _confirmDeleteAcidSession(s),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: s.acidNumber,
                                rowSummary: rowSummary,
                                child: Text(
                                  s.acidNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: fileLabel,
                                rowSummary: rowSummary,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                                      ),
                                    ),
                                    if (poLabel.isNotEmpty && poLabel != '-')
                                      Text(
                                        '${context.l10n.poLabelPrefix}: $poLabel',
                                        style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: s.exporterName,
                                rowSummary: rowSummary,
                                child: Text(
                                  s.exporterName,
                                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: s.importerName,
                                rowSummary: rowSummary,
                                child: Text(
                                  s.importerName,
                                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: dateStr.isNotEmpty ? dateStr.substring(0, min(10, dateStr.length)) : '-',
                                rowSummary: rowSummary,
                                child: Text(
                                  dateStr.isNotEmpty ? dateStr.substring(0, min(10, dateStr.length)) : '-',
                                  style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: expStr.isNotEmpty ? expStr.substring(0, min(10, expStr.length)) : '-',
                                rowSummary: rowSummary,
                                child: Text(
                                  expStr.isNotEmpty ? expStr.substring(0, min(10, expStr.length)) : '-',
                                  style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: statusLabel,
                                rowSummary: rowSummary,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isIssued
                                        ? (isDark ? AppTheme.emeraldLight : AppTheme.successBackground)
                                        : (isDraft
                                            ? (isDark ? AppTheme.orangeLight : AppTheme.warningBackground)
                                            : (isDark ? AppTheme.darkCardBackground : AppTheme.infoBackground)),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isIssued
                                          ? (isDark ? AppTheme.wcagEmerald.withValues(alpha: 0.5) : AppTheme.emeraldBorder)
                                          : (isDraft
                                              ? (isDark ? AppTheme.wcagOrange.withValues(alpha: 0.5) : AppTheme.orange)
                                              : (isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.5) : AppTheme.cobaltBorder)),
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isIssued
                                          ? (isDark ? AppTheme.wcagEmerald : AppTheme.successForeground)
                                          : (isDraft
                                              ? (isDark ? AppTheme.wcagOrange : AppTheme.warningForeground)
                                              : (isDark ? AppTheme.wcagCobalt : AppTheme.infoForeground)),
                                    ),
                                  ),
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
            ],
          ],
        );
      },
    );
  }

  // --- SUB-VIEW 4: EXPIRY TRACKER TAB ---
  Widget _buildExpiryTrackerTab() {
    final trackerSummary = ref.watch(acidTrackerProvider).valueOrNull;
    final trackerItems = trackerSummary?.items ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = trackerItems.where((t) {
      if (_acidSearchQuery.isEmpty) return true;
      return t.acidNumber.toLowerCase().contains(_acidSearchQuery.toLowerCase()) ||
          (t.importFileCode != null && t.importFileCode!.toLowerCase().contains(_acidSearchQuery.toLowerCase())) ||
          t.supplierName.toLowerCase().contains(_acidSearchQuery.toLowerCase());
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards (Responsive: 2x2 grid on mobile, 1x4 row on desktop/tablet)
            if (isMobile) ...[
              Row(
                children: [
                  _buildTrackerCard(
                    title: context.l10n.totalAcidsCard,
                    count: trackerSummary?.totalAcidsCount ?? trackerItems.length,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    icon: Icons.qr_code,
                  ),
                  const SizedBox(width: 10),
                  _buildTrackerCard(
                    title: context.l10n.validAcidsCard,
                    count: trackerSummary?.validCount ?? trackerItems.where((t) => t.status != 'Expired' && t.daysRemaining > 14).length,
                    color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTrackerCard(
                    title: context.l10n.expiringSoonAcidsCard,
                    count: trackerSummary?.expiringSoonCount ?? trackerItems.where((t) => t.status != 'Expired' && t.daysRemaining <= 14 && t.daysRemaining > 0).length,
                    color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
                    icon: Icons.warning_amber,
                  ),
                  const SizedBox(width: 10),
                  _buildTrackerCard(
                    title: context.l10n.expiredAcidsCard,
                    count: trackerSummary?.expiredCount ?? trackerItems.where((t) => t.status == 'Expired' || t.daysRemaining <= 0).length,
                    color: isDark ? AppTheme.wcagCrimson : AppTheme.crimson,
                    icon: Icons.cancel_outlined,
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  _buildTrackerCard(
                    title: context.l10n.totalAcidsCard,
                    count: trackerSummary?.totalAcidsCount ?? trackerItems.length,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    icon: Icons.qr_code,
                  ),
                  const SizedBox(width: 14),
                  _buildTrackerCard(
                    title: context.l10n.validAcidsCard,
                    count: trackerSummary?.validCount ?? trackerItems.where((t) => t.status != 'Expired' && t.daysRemaining > 14).length,
                    color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(width: 14),
                  _buildTrackerCard(
                    title: context.l10n.expiringSoonAcidsCard,
                    count: trackerSummary?.expiringSoonCount ?? trackerItems.where((t) => t.status != 'Expired' && t.daysRemaining <= 14 && t.daysRemaining > 0).length,
                    color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
                    icon: Icons.warning_amber,
                  ),
                  const SizedBox(width: 14),
                  _buildTrackerCard(
                    title: context.l10n.expiredAcidsCard,
                    count: trackerSummary?.expiredCount ?? trackerItems.where((t) => t.status == 'Expired' || t.daysRemaining <= 0).length,
                    color: isDark ? AppTheme.wcagCrimson : AppTheme.crimson,
                    icon: Icons.cancel_outlined,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),

            // Search Bar & Export Actions
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('acidExpiryTrackerSearchField'),
                    style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    decoration: InputDecoration(
                      hintText: context.l10n.searchExpiryTrackerHint,
                      hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                      prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    ),
                    onChanged: (val) => setState(() => _acidSearchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IdocBUi.fit(AppButton(key: const Key('acidExpiryCopyBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'نسخ الجدول' : 'Copy Table', onPressed: () => _copyAcidExpiryAsTsv(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.copy)),
                      IdocBUi.fit(AppButton(key: const Key('acidExpiryExcelBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير Excel' : 'Export Excel', onPressed: () => _exportAcidExpiryToExcel(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.table_chart)),
                      IdocBUi.fit(AppButton(key: const Key('acidExpiryPdfBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير PDF' : 'Export PDF', onPressed: () => _exportAcidExpiryToPdf(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                    ],
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('acidExpiryTrackerSearchField'),
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      decoration: InputDecoration(
                        hintText: context.l10n.searchExpiryTrackerHint,
                        hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                        prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      ),
                      onChanged: (val) => setState(() => _acidSearchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IdocBUi.fit(AppButton(key: const Key('acidExpiryCopyBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'نسخ الجدول' : 'Copy Table', onPressed: () => _copyAcidExpiryAsTsv(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.copy)),
                  const SizedBox(width: 8),
                  IdocBUi.fit(AppButton(key: const Key('acidExpiryExcelBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير Excel' : 'Export Excel', onPressed: () => _exportAcidExpiryToExcel(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.table_chart)),
                  const SizedBox(width: 8),
                  IdocBUi.fit(AppButton(key: const Key('acidExpiryPdfBtn'), label: Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير PDF' : 'Export PDF', onPressed: () => _exportAcidExpiryToPdf(filtered, importFiles), variant: AppButtonVariant.secondary, icon: Icons.picture_as_pdf)),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Tracker Table / Empty State
            if (filtered.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.borderStrong),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.noAcidsFound,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                decoration: AppTheme.cardDecorationOf(context),
                child: SelectionArea(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < 750 ? 750 : constraints.maxWidth - (isMobile ? 28 : 40),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
                      columns: [
                        DataColumn(label: Text(context.l10n.actionCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.acidNumberCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.importFile, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.foreignExporterCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.expiryDateCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.daysRemainingCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                        DataColumn(label: Text(context.l10n.validityStatusCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      ],
                      rows: filtered.map((t) {
                        final days = t.daysRemaining;
                        final isExp = t.status == 'Expired' || days <= 0;
                        final isWarning = !isExp && days <= 14;
                        final expDate = t.acidExpiryDate ?? '';
                        final matchedFile = importFiles.where((f) => f.importFileId == t.importFileId).firstOrNull;
                        final fileLabel = matchedFile?.displayName ?? t.importFileCode ?? '-';
                        final poLabel = (matchedFile?.poNumber != null && matchedFile!.poNumber!.isNotEmpty)
                            ? matchedFile.poNumber!
                            : '';
                        final statusLabel = isExp ? context.l10n.expiredStatusBadge : isWarning ? context.l10n.expiringSoonStatusBadge : context.l10n.validStatusBadge;
                        final rowSummary = [
                          t.acidNumber,
                          fileLabel,
                          poLabel,
                          t.supplierName,
                          expDate.length >= 10 ? expDate.substring(0, 10) : expDate,
                          '$days',
                          statusLabel,
                        ].join('\t');

                        return DataRow(
                          cells: [
                            DataCell(
                              IconButton(
                                key: Key('cloneTrackerRowBtn_${t.acidNumber}'),
                                icon: Icon(Icons.copy_all, color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald, size: 20),
                                tooltip: context.l10n.cloneAcidRecordTooltip,
                                onPressed: () => _onCloneTrackerItem(t),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: t.acidNumber,
                                rowSummary: rowSummary,
                                child: Text(t.acidNumber, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt)),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: fileLabel,
                                rowSummary: rowSummary,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fileLabel, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                    if (poLabel.isNotEmpty)
                                      Text('${context.l10n.poLabelPrefix}: $poLabel', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: t.supplierName,
                                rowSummary: rowSummary,
                                child: Text(t.supplierName, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: expDate.length >= 10 ? expDate.substring(0, 10) : expDate,
                                rowSummary: rowSummary,
                                child: Text(expDate.length >= 10 ? expDate.substring(0, 10) : expDate, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal)),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: '$days',
                                rowSummary: rowSummary,
                                child: Text(
                                  '$days',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isExp
                                        ? (AppTheme.crimson)
                                        : isWarning
                                            ? (isDark ? AppTheme.wcagOrange : AppTheme.orange)
                                            : (isDark ? AppTheme.wcagEmerald : AppTheme.emerald),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: statusLabel,
                                rowSummary: rowSummary,
                                child: LivePulseBadge.acid(
                                  daysRemaining: days,
                                  isCustomsReleased: t.isCustomsReleased,
                                  customLabel: statusLabel,
                                  size: PulseBadgeSize.compact,
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
            ],
          ],
        );
      },
    );
  }

  void _onCloneTrackerItem(AcidTrackerItemModel item) {
    final acidSessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    AcidRegistrationModel? session = acidSessions.where((s) =>
        (item.acidSessionId != null && s.acidId == item.acidSessionId) ||
        (s.acidNumber.isNotEmpty && s.acidNumber == item.acidNumber) ||
        (item.importFileId != null && s.importFileId == item.importFileId)).firstOrNull;

    session ??= AcidRegistrationModel(
      acidId: item.acidSessionId ?? 0,
      acidCode: item.acidCode ?? 'ACID-REG-2026',
      acidNumber: item.acidNumber,
      importFileId: item.importFileId,
      importFileCode: item.importFileCode,
      poNumber: item.poNumber,
      importerId: 1,
      importerName: item.importerName.isNotEmpty ? item.importerName : 'مستورد',
      importerTaxId: '100-200-300',
      supplierId: 1,
      exporterName: item.supplierName.isNotEmpty ? item.supplierName : 'مورد أجنبي',
      exporterCountry: 'China',
      exporterCountryCode: 'CN',
      exporterRegId: 'CN91310000',
      proformaInvoiceNo: item.piNumber ?? 'PI-2026-001',
      polName: 'CHANGSHU',
      podName: 'Alexandria',
      customsBrokerName: item.customsBrokerName,
      status: item.status,
      createdAt: item.acidIssueDate ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    _onCloneAcidSelected(session);
  }

  Widget _buildTrackerCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppTheme.darkBorder : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  CopyableText(
                    '$count',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? (color == AppTheme.charcoal ? AppTheme.darkTextPrimary : color) : color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---
  Future<void> _saveAcidRequest() async {
    if (!_requestFormKey.currentState!.validate()) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectImportFileFirst), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'import_file_id': _selectedImportFileId,
        'importer_id': _selectedImporterId,
        'importer_name': _importerNameCtrl.text.trim(),
        'importer_tax_id': _importerTaxIdCtrl.text.trim(),
        'importer_address': _importerAddressCtrl.text.trim(),
        'supplier_id': _selectedSupplierId,
        'exporter_name': _exporterNameCtrl.text.trim(),
        'exporter_reg_type': _exporterRegType,
        'exporter_reg_id': _exporterRegIdCtrl.text.trim(),
        'exporter_country': _exporterCountryCtrl.text.trim(),
        'exporter_country_code': _exporterCountryCodeCtrl.text.trim(),
        'exporter_address': _exporterAddressCtrl.text.trim(),
        'exporter_phone': _exporterPhoneCtrl.text.trim(),
        'cargox_id': _cargoxIdCtrl.text.trim(),
        'po_id': _selectedPoId,
        'po_number': _poNoCtrl.text.trim(),
        'proforma_invoice_no': _proformaNoCtrl.text.trim(),
        'proforma_invoice_date': _proformaDateCtrl.text.trim(),
        'invoice_type': _invoiceType,
        'pol_name': _polCtrl.text.trim(),
        'pod_name': _podCtrl.text.trim(),
        'customs_broker_id': _selectedBrokerId,
        'customs_broker_name': _brokerNameCtrl.text.trim(),
        'customs_broker_phone': _brokerPhoneCtrl.text.trim(),
        'requested_date': _requestedDateCtrl.text.trim(),
      };

      // Check if session exists or is in edit mode
      final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final existing = sessions.where((s) => s.importFileId == _selectedImportFileId && s.isActive).firstOrNull;
      final targetAcidId = _editingAcidSessionId ?? existing?.acidId;

      if (targetAcidId != null) {
        await ref.read(acidSessionsProvider.notifier).updateAcidSession(targetAcidId, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.acidRequestUpdatedSuccess(existing?.acidCode ?? _editingAcidCode ?? '')),
              backgroundColor: AppTheme.emerald,
            ),
          );
          setState(() {
            _editingAcidSessionId = targetAcidId;
            _selectedSubTab = 1;
          });
        }
      } else {
        await ref.read(acidSessionsProvider.notifier).createAcidSession(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.acidRequestSavedSuccess), backgroundColor: AppTheme.emerald),
          );
          setState(() => _selectedSubTab = 1);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.errorSavingAcid, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Debug-only demo helper (Q6): neutral placeholder data, never real parties.
  void _loadSampleMtsText() {
    if (!kDebugMode) return;
    setState(() {
      _rawMtsTextCtrl.text = '''MTS Notification
Dear Sample Exporter Co.,Ltd,

Kindly be informed that an Advance Cargo Information request (ACI) has been approved for shipping:
[ACID: 0000000000000000000]
Requested: 01-Jan-2026 10:00:00 AM   Generated: 01-Jan-2026 10:00:10 AM   Expires: 01-Jul-2026 10:00:10 AM

Egyptian Importer
Egyptian Importer Name: Sample Importer Co.
Egyptian Importer Tax ID: 000000000
Address: Sample address

Foreign Exporter
Foreign Exporter Name: Sample Exporter Co.,Ltd
Foreign Exporter ID: 000000000000000000
Registration Type: Company Registration Number
Country of Export: CHINA

Proforma Invoice No.: SAMPLE-001
Port of Loading: SAMPLE PORT
Port of Discharge: Alexandria
CargoX Platform ID: 00000000-0000-0000-0000-000000000000''';
    });
    _parseMtsText();
  }

  Future<void> _parseMtsText() async {
    final raw = _rawMtsTextCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pasteMtsTextFirst), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    // Check if user pasted only the legal email disclaimer
    if (raw.contains('MTS EMAIL NOTICE This Electronic Mail') &&
        !raw.contains('ACID') &&
        !RegExp(r'\d{19}').hasMatch(raw)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 26),
              const SizedBox(width: 8),
              Text(context.l10n.mtsNoticeDisclaimerAlertTitle),
            ],
          ),
          content: Text(
            context.l10n.mtsNoticeDisclaimerAlertContent,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            IdocBUi.fit(AppButton(label: context.l10n.close, onPressed: () => Navigator.pop(ctx), variant: AppButtonVariant.secondary)),
            if (kDebugMode)
            IdocBUi.fit(AppButton(label: context.l10n.loadSampleMtsAndTest, onPressed: () {
                Navigator.pop(ctx);
                _loadSampleMtsText();
              }, icon: Icons.auto_fix_high)),
          ],
        ),
      );
      return;
    }

    setState(() => _isParsingMts = true);
    try {
      final responseData = await ref.read(acidSessionsProvider.notifier).parseAcidText(raw, importFileId: _selectedImportFileId);
      final Map<String, dynamic> parsedFields = (responseData['parsed_data'] != null && responseData['parsed_data'] is Map)
          ? Map<String, dynamic>.from(responseData['parsed_data'] as Map)
          : Map<String, dynamic>.from(responseData);
      
      setState(() => _parsedMtsData = parsedFields);
      
      // Auto-scroll to results card
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });

      if (mounted) {
        final acidFound = (parsedFields['acid_number'] != null && parsedFields['acid_number'].toString().trim().isNotEmpty);
        if (acidFound) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.acidExtractedSuccess(parsedFields['acid_number']?.toString() ?? '')),
              backgroundColor: AppTheme.emerald,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.orange, size: 26),
                  const SizedBox(width: 8),
                  Text(context.l10n.mtsNoticeNoAcidAlertTitle),
                ],
              ),
              content: Text(
                context.l10n.mtsNoticeNoAcidAlertContent,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              actions: [
                IdocBUi.fit(AppButton(label: context.l10n.close, onPressed: () => Navigator.pop(ctx), variant: AppButtonVariant.secondary)),
                if (kDebugMode)
                IdocBUi.fit(AppButton(label: context.l10n.loadSampleMtsAndExtract, onPressed: () {
                    Navigator.pop(ctx);
                    _loadSampleMtsText();
                  }, icon: Icons.auto_fix_high)),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.errorParsingMts, error: e);
      }
    } finally {
      if (mounted) setState(() => _isParsingMts = false);
    }
  }

  void _copyDiscrepancyReportToClipboard() {
    if (_comparisonResult == null) return;

    final isAr = context.l10n.isArabic;
    final l = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln('📋 ${l.idocBAcidReportTitle}');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('${l.idocBAcidReportOverallStatus}: ${_comparisonResult!.allMatched ? '${l.idocBAcidReportFullyMatched} ✅' : '${l.idocBAcidReportDiscrepancies} ⚠️'}');
    buffer.writeln('${l.idocBAcidReportMatchPercentage}: ${_comparisonResult!.matchPercentage.toStringAsFixed(1)}% (${_comparisonResult!.matchedCount}/${_comparisonResult!.totalComparedFields})');
    buffer.writeln('--------------------------------------------------');

    for (final item in _comparisonResult!.items) {
      final label = isAr ? item.labelAr : item.labelEn;
      final status = item.isMatched ? '✅' : '❌';
      buffer.writeln('$status $label:');
      buffer.writeln('   - ${l.idocBAcidReportRequested}: ${item.requestedValue}');
      buffer.writeln('   - ${l.idocBAcidReportGenerated}: ${item.generatedValue}');
    }

    if (!_comparisonResult!.allMatched && _discrepancyOverrideReasonCtrl.text.trim().isNotEmpty) {
      buffer.writeln('--------------------------------------------------');
      buffer.writeln('${l.idocBAcidReportOverride}: ${_discrepancyOverrideReasonCtrl.text.trim()}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.discrepancyReportCopiedSuccess),
        backgroundColor: AppTheme.wcagEmerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runComparison() async {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectImportFileToVerify), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final comp = companies.where((c) => c.companyId == file?.companyId).firstOrNull;
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final supp = suppliers.where((s) => s.supplierId == file?.supplierId).firstOrNull;
    final pos = ref.read(purchaseOrdersProvider).purchaseOrders;
    final po = pos.where((p) => p.importFileId == _selectedImportFileId).firstOrNull;

    setState(() => _isComparing = true);
    try {
      final requestedData = {
        'import_file_id': _selectedImportFileId,
        'importer_name': _importerNameCtrl.text.isNotEmpty ? _importerNameCtrl.text : (comp?.importerName ?? file?.companyName ?? ''),
        'importer_tax_id': _importerTaxIdCtrl.text.isNotEmpty ? _importerTaxIdCtrl.text : (comp?.vatId ?? ''),
        'exporter_name': _exporterNameCtrl.text.isNotEmpty ? _exporterNameCtrl.text : (supp?.companyName ?? file?.supplierName ?? ''),
        'exporter_reg_type': _exporterRegType.isNotEmpty ? _exporterRegType : (supp?.registrationType ?? ''),
        'exporter_reg_id': _exporterRegIdCtrl.text.isNotEmpty ? _exporterRegIdCtrl.text : (supp?.foreignExporterId ?? ''),
        'exporter_country': _exporterCountryCtrl.text.isNotEmpty ? _exporterCountryCtrl.text : (supp?.foreignExporterCountry ?? ''),
        'exporter_country_code': _exporterCountryCodeCtrl.text.isNotEmpty ? _exporterCountryCodeCtrl.text : (supp?.foreignExporterCountryCode ?? ''),
        'proforma_invoice_no': _proformaNoCtrl.text.isNotEmpty ? _proformaNoCtrl.text : (file?.piNumber ?? (file?.poNumber ?? (po != null ? po.poNumber : ''))),
        'pol_name': _polCtrl.text,
        'pod_name': _podCtrl.text,
        'cargox_id': _cargoxIdCtrl.text.isNotEmpty ? _cargoxIdCtrl.text : (supp?.cargoxPlatformId ?? ''),
      };
      final generatedData = _parsedMtsData ?? {};

      final res = await ref.read(acidSessionsProvider.notifier).compareAcid(requestedData, generatedData);
      setState(() => _comparisonResult = res);
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.errorCustomsComparison, error: e);
      }
    } finally {
      if (mounted) setState(() => _isComparing = false);
    }
  }

  Future<void> _saveVerifiedAcid() async {
    if (_selectedImportFileId == null) return;
    final acidToSave = (_parsedMtsData?['acid_number'] ?? _acidNumberCtrl.text).toString().trim();
    if (acidToSave.isEmpty || acidToSave == 'ACID-EG-2026-') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.idocBAcidRequired), backgroundColor: AppTheme.crimson),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final payload = {
        'import_file_id': _selectedImportFileId,
        'acid_number': _parsedMtsData?['acid_number'] ?? _acidNumberCtrl.text.trim(),
        'generated_date': _parsedMtsData?['generated_date'] ?? _generatedDateCtrl.text.trim(),
        'expiry_date': _parsedMtsData?['expiry_date'] ?? _expiryDateCtrl.text.trim(),
        'importer_name': _importerNameCtrl.text.trim(),
        'importer_tax_id': _importerTaxIdCtrl.text.trim(),
        'exporter_name': _exporterNameCtrl.text.trim(),
        'exporter_reg_id': _exporterRegIdCtrl.text.trim(),
        'exporter_country': _exporterCountryCtrl.text.trim(),
        'po_number': _poNoCtrl.text.trim(),
        'proforma_invoice_no': _proformaNoCtrl.text.trim(),
        'pol_name': _polCtrl.text.trim(),
        'pod_name': _podCtrl.text.trim(),
        'status': 'Issued',
        'is_verified': true,
        'discrepancy_override_reason': _discrepancyOverrideReasonCtrl.text.trim(),
      };

      final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final existing = sessions.where((s) => s.importFileId == _selectedImportFileId && s.isActive).firstOrNull;
      final targetAcidId = _editingAcidSessionId ?? existing?.acidId;

      if (targetAcidId != null) {
        await ref.read(acidSessionsProvider.notifier).updateAcidSession(targetAcidId, payload);
      } else {
        await ref.read(acidSessionsProvider.notifier).createAcidSession(payload);
      }

      await ref.read(importFilesProvider.notifier).fetchImportFiles();
      await ref.read(acidTrackerProvider.notifier).fetchAcidTracker();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.acidCertifiedSuccess), backgroundColor: AppTheme.emerald),
        );
        setState(() => _selectedSubTab = 3);
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.errorCertifyingAcid, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _loadSessionForEdit(AcidRegistrationModel session) {
    setState(() {
      _selectedImportFileId = session.importFileId;
      _editingAcidSessionId = session.acidId;
      _editingAcidCode = session.acidCode;
      _selectedImporterId = session.importerId;
      _importerNameCtrl.text = session.importerName;
      _importerTaxIdCtrl.text = session.importerTaxId;
      _importerAddressCtrl.text = session.importerAddress ?? '';
      _selectedSupplierId = session.supplierId;
      _exporterNameCtrl.text = session.exporterName;
      _exporterRegIdCtrl.text = session.exporterRegId;
      _exporterCountryCtrl.text = session.exporterCountry;
      _exporterCountryCodeCtrl.text = session.exporterCountryCode ?? '';
      _exporterAddressCtrl.text = session.exporterAddress ?? '';
      _exporterPhoneCtrl.text = session.exporterPhone ?? '';
      _exporterRegType = session.exporterRegType ?? 'Company Registration Number';
      _cargoxIdCtrl.text = session.cargoxId ?? '';
      _poNoCtrl.text = session.poNumber ?? '';
      _proformaNoCtrl.text = session.proformaInvoiceNo;
      _polCtrl.text = session.polName;
      _podCtrl.text = session.podName;
      _brokerNameCtrl.text = session.customsBrokerName ?? '';
      _brokerPhoneCtrl.text = session.customsBrokerPhone ?? '';
      _requestedDateCtrl.text = session.requestedDate ?? '';
      _selectedSubTab = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.acidSessionLoadedForEdit(session.acidCode)), backgroundColor: AppTheme.cobalt),
    );
  }

  void _confirmDeleteAcidSession(AcidRegistrationModel session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 24),
            const SizedBox(width: 8),
            Text(context.l10n.confirmSoftDelete, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CopyableText('ACID (${session.acidCode}) — (${session.acidNumber})'),
            const SizedBox(height: 10),
            Text(context.l10n.confirmSoftDelete, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          IdocBUi.fit(AppButton(label: context.l10n.cancel, onPressed: () => Navigator.pop(ctx), variant: AppButtonVariant.secondary)),
          IdocBUi.fit(AppButton(label: context.l10n.delete, onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(acidSessionsProvider.notifier).softDeleteAcidSession(session.acidId);
                await ref.read(importFilesProvider.notifier).fetchImportFiles();
                await ref.read(acidTrackerProvider.notifier).fetchAcidTracker();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.acidSessionDeletedSuccess(session.acidCode)),
                      backgroundColor: AppTheme.charcoal,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  showErrorDetailsDialog(context, title: context.l10n.errorDeletingAcid, error: e);
                }
              }
            }, variant: AppButtonVariant.danger, icon: Icons.delete_forever)),
        ],
      ),
    );
  }

  Future<void> _saveMtsResultAsAcidSession({bool isDraft = false}) async {
    if (_parsedMtsData == null) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectImportFileFirst), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final acidNum = _parsedMtsData!['acid_number']?.toString().trim() ?? '';
      final payload = {
        'import_file_id': _selectedImportFileId,
        'importer_id': _selectedImporterId,
        'importer_name': _parsedMtsData!['importer_name']?.toString().trim() ?? _importerNameCtrl.text.trim(),
        'importer_tax_id': _parsedMtsData!['importer_tax_id']?.toString().trim() ?? _importerTaxIdCtrl.text.trim(),
        'importer_address': _parsedMtsData!['importer_address']?.toString().trim() ?? _importerAddressCtrl.text.trim(),
        'supplier_id': _selectedSupplierId,
        'exporter_name': _parsedMtsData!['exporter_name']?.toString().trim() ?? _exporterNameCtrl.text.trim(),
        'exporter_reg_type': _parsedMtsData!['exporter_reg_type']?.toString().trim() ?? 'Company Registration Number',
        'exporter_reg_id': _parsedMtsData!['exporter_reg_id']?.toString().trim() ?? _exporterRegIdCtrl.text.trim(),
        'exporter_country': _parsedMtsData!['exporter_country']?.toString().trim() ?? _exporterCountryCtrl.text.trim(),
        'exporter_country_code': _parsedMtsData!['exporter_country_code']?.toString().trim() ?? _exporterCountryCodeCtrl.text.trim(),
        'exporter_address': _parsedMtsData!['exporter_address']?.toString().trim() ?? _exporterAddressCtrl.text.trim(),
        'exporter_phone': _parsedMtsData!['exporter_phone']?.toString().trim() ?? _exporterPhoneCtrl.text.trim(),
        'cargox_id': _parsedMtsData!['cargox_id']?.toString().trim() ?? _cargoxIdCtrl.text.trim(),
        'po_id': _selectedPoId,
        'po_number': _poNoCtrl.text.trim(),
        'proforma_invoice_no': _parsedMtsData!['proforma_invoice_no']?.toString().trim() ?? _proformaNoCtrl.text.trim(),
        'proforma_invoice_date': _parsedMtsData!['proforma_invoice_date']?.toString().trim() ?? _proformaDateCtrl.text.trim(),
        'invoice_date': _parsedMtsData!['invoice_date']?.toString().trim(),
        'invoice_type': _parsedMtsData!['invoice_type']?.toString().trim() ?? _invoiceType,
        'pol_name': _parsedMtsData!['pol_name']?.toString().trim() ?? _polCtrl.text.trim(),
        'pod_name': _parsedMtsData!['pod_name']?.toString().trim() ?? _podCtrl.text.trim(),
        'customs_broker_id': _selectedBrokerId,
        'customs_broker_name': _brokerNameCtrl.text.trim(),
        'customs_broker_phone': _brokerPhoneCtrl.text.trim(),
        'requested_date': _parsedMtsData!['requested_date']?.toString().trim() ?? _requestedDateCtrl.text.trim(),
        'generated_date': _parsedMtsData!['generated_date']?.toString().trim(),
        'expiry_date': _parsedMtsData!['expiry_date']?.toString().trim(),
        'acid_number': acidNum.isNotEmpty ? acidNum : 'PENDING',
        'raw_nafeza_text': _rawMtsTextCtrl.text.trim(),
        'status': isDraft ? 'DRAFT' : (acidNum.isNotEmpty ? 'Issued' : 'Pending Issue'),
      };

      // Check if session exists or is in edit mode
      final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final existing = sessions.where((s) => s.importFileId == _selectedImportFileId && s.isActive).firstOrNull;
      final targetAcidId = _editingAcidSessionId ?? existing?.acidId;

      if (targetAcidId != null) {
        await ref.read(acidSessionsProvider.notifier).updateAcidSession(targetAcidId, payload);
      } else {
        await ref.read(acidSessionsProvider.notifier).createAcidSession(payload);
      }

      await ref.read(importFilesProvider.notifier).fetchImportFiles();
      await ref.read(acidTrackerProvider.notifier).fetchAcidTracker();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDraft
                ? context.l10n.acidRequestSavedSuccess
                : context.l10n.acidCertifiedSuccess),
            backgroundColor: isDraft ? AppTheme.charcoal : AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: isDraft ? context.l10n.errorSavingDraft : context.l10n.errorSavingAcid, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showEditMtsDataDialog() {
    if (_parsedMtsData == null) return;

    final acidCtrl = TextEditingController(text: _parsedMtsData!['acid_number']?.toString() ?? '');
    final genDateCtrl = TextEditingController(text: _parsedMtsData!['generated_date']?.toString() ?? '');
    final expDateCtrl = TextEditingController(text: _parsedMtsData!['expiry_date']?.toString() ?? '');
    final reqDateCtrl = TextEditingController(text: _parsedMtsData!['requested_date']?.toString() ?? '');
    final impNameCtrl = TextEditingController(text: _parsedMtsData!['importer_name']?.toString() ?? '');
    final impTaxCtrl = TextEditingController(text: _parsedMtsData!['importer_tax_id']?.toString() ?? '');
    final impAddrCtrl = TextEditingController(text: _parsedMtsData!['importer_address']?.toString() ?? '');
    final expNameCtrl = TextEditingController(text: _parsedMtsData!['exporter_name']?.toString() ?? '');
    final expRegIdCtrl = TextEditingController(text: _parsedMtsData!['exporter_reg_id']?.toString() ?? '');
    final expCountryCtrl = TextEditingController(text: _parsedMtsData!['exporter_country']?.toString() ?? '');
    final cargoxCtrl = TextEditingController(text: _parsedMtsData!['cargox_id']?.toString() ?? '');
    final piCtrl = TextEditingController(text: _parsedMtsData!['proforma_invoice_no']?.toString() ?? '');
    final polCtrl = TextEditingController(text: _parsedMtsData!['pol_name']?.toString() ?? '');
    final podCtrl = TextEditingController(text: _parsedMtsData!['pod_name']?.toString() ?? '');
    String regType = _parsedMtsData!['exporter_reg_type']?.toString() ?? 'Company Registration Number';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 700,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: AppTheme.charcoal,
                    borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(16), topEnd: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: AppTheme.white, size: 22),
                      const SizedBox(width: 10),
                      Text(context.l10n.editExtractedDataButton, style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: acidCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(labelText: '${context.l10n.acidNumberCol} *', prefixIcon: const Icon(Icons.qr_code), border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: reqDateCtrl,
                                decoration: InputDecoration(labelText: context.l10n.acidRequestDateLabel, prefixIcon: const Icon(Icons.event_available), border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: genDateCtrl,
                                decoration: InputDecoration(labelText: context.l10n.issueDateCol, prefixIcon: const Icon(Icons.calendar_today), border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: expDateCtrl,
                                decoration: InputDecoration(labelText: context.l10n.expiryDateCol, prefixIcon: const Icon(Icons.event_busy), border: const OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: impNameCtrl,
                                decoration: InputDecoration(labelText: context.l10n.importerCompanyCol, prefixIcon: const Icon(Icons.business), border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: impTaxCtrl,
                                decoration: InputDecoration(labelText: context.l10n.importerTaxIdLabel, prefixIcon: const Icon(Icons.badge), border: const OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: expNameCtrl,
                                decoration: InputDecoration(labelText: context.l10n.foreignExporterCol, prefixIcon: const Icon(Icons.public), border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: expRegIdCtrl,
                                decoration: InputDecoration(labelText: context.l10n.foreignExporterIdLabel, prefixIcon: const Icon(Icons.confirmation_number), border: const OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: SearchableDropdownField<String>(
                                labelText: context.l10n.regTypeLabel,
                                value: regType,
                                items: [
                                  SearchableDropdownItem(value: 'Company Registration Number', label: context.l10n.companyRegNumberType),
                                  SearchableDropdownItem(value: 'Foreign Exporter Number (Nafeza)', label: context.l10n.foreignExporterNafezaType),
                                  SearchableDropdownItem(value: 'Factory Registration', label: context.l10n.factoryRegType),
                                  SearchableDropdownItem(value: 'VAT Number', label: context.l10n.vatRegType),
                                  SearchableDropdownItem(value: 'Tax Number', label: context.l10n.taxIdRegType),
                                  SearchableDropdownItem(value: 'Commercial Register', label: context.l10n.crRegType),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => regType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: expCountryCtrl,
                                decoration: InputDecoration(labelText: context.l10n.countryOfOriginExportLabel, prefixIcon: const Icon(Icons.flag), border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: cargoxCtrl,
                                decoration: InputDecoration(labelText: context.l10n.cargoxPlatformIdLabel, prefixIcon: const Icon(Icons.token), border: const OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: piCtrl,
                                decoration: InputDecoration(labelText: context.l10n.proformaInvoiceNoLabel, prefixIcon: const Icon(Icons.receipt), border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: polCtrl,
                                decoration: InputDecoration(labelText: context.l10n.portOfLoadingLabel, prefixIcon: const Icon(Icons.sailing), border: const OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: podCtrl,
                                decoration: InputDecoration(labelText: context.l10n.portOfDischargeLabel, prefixIcon: const Icon(Icons.anchor), border: const OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.surfaceAlt, border: Border(top: BorderSide(color: AppTheme.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IdocBUi.fit(AppButton(label: context.l10n.cancel, onPressed: () => Navigator.pop(dialogCtx), variant: AppButtonVariant.secondary)),
                      const SizedBox(width: 12),
                      IdocBUi.fit(AppButton(label: context.l10n.save, onPressed: () {
                          setState(() {
                            _parsedMtsData!['acid_number'] = acidCtrl.text.trim();
                            _parsedMtsData!['requested_date'] = reqDateCtrl.text.trim();
                            _parsedMtsData!['generated_date'] = genDateCtrl.text.trim();
                            _parsedMtsData!['expiry_date'] = expDateCtrl.text.trim();
                            _parsedMtsData!['importer_name'] = impNameCtrl.text.trim();
                            _parsedMtsData!['importer_tax_id'] = impTaxCtrl.text.trim();
                            _parsedMtsData!['importer_address'] = impAddrCtrl.text.trim();
                            _parsedMtsData!['exporter_name'] = expNameCtrl.text.trim();
                            _parsedMtsData!['exporter_reg_id'] = expRegIdCtrl.text.trim();
                            _parsedMtsData!['exporter_country'] = expCountryCtrl.text.trim();
                            _parsedMtsData!['exporter_reg_type'] = regType;
                            _parsedMtsData!['cargox_id'] = cargoxCtrl.text.trim();
                            _parsedMtsData!['proforma_invoice_no'] = piCtrl.text.trim();
                            _parsedMtsData!['pol_name'] = polCtrl.text.trim();
                            _parsedMtsData!['pod_name'] = podCtrl.text.trim();
                          });
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.mtsExtractedDataUpdated), backgroundColor: AppTheme.emerald),
                          );
                        }, variant: AppButtonVariant.success, icon: Icons.check)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _codeSupplierFromMts() async {
    if (_parsedMtsData == null) return;
    final expName = _parsedMtsData!['exporter_name']?.toString().trim() ?? '';
    if (expName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.foreignSupplierNotInData), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    try {
      final existingSuppliers = ref.read(suppliersProvider).valueOrNull ?? [];
      final existing = existingSuppliers.where((s) => s.companyName.toLowerCase() == expName.toLowerCase() || s.foreignExporterId == (_parsedMtsData!['exporter_reg_id']?.toString().trim() ?? '')).firstOrNull;

      final supplier = SupplierModel(
        supplierId: existing?.supplierId,
        supplierCode: existing?.supplierCode ?? 'SUP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        companyName: expName,
        supplierType: 'Manufacturer',
        registrationType: _parsedMtsData!['exporter_reg_type']?.toString().trim() ?? 'Company Registration Number',
        foreignExporterId: _parsedMtsData!['exporter_reg_id']?.toString().trim() ?? (existing?.foreignExporterId ?? 'EXP-SUP-001'),
        cargoxPlatformId: _parsedMtsData!['cargox_id']?.toString().trim() ?? existing?.cargoxPlatformId,
        foreignExporterCountry: _parsedMtsData!['exporter_country']?.toString().trim() ?? (existing?.foreignExporterCountry ?? 'China'),
        foreignExporterCountryCode: _parsedMtsData!['exporter_country_code']?.toString().trim() ?? (existing?.foreignExporterCountryCode ?? 'CN'),
        address: _parsedMtsData!['exporter_address']?.toString().trim() ?? (existing?.address ?? 'No.16 Kangsheng Road, Changshu, China'),
        phone: _parsedMtsData!['exporter_phone']?.toString().trim() ?? existing?.phone,
        isActive: true,
      );

      String? err;
      if (existing != null && existing.supplierId != null) {
        err = await ref.read(suppliersProvider.notifier).updateSupplier(existing.supplierId!, supplier);
      } else {
        err = await ref.read(suppliersProvider.notifier).createSupplier(supplier);
      }

      if (err != null) {
        if (mounted) {
          showErrorDetailsDialog(context, title: context.l10n.errorCodingSupplier, error: err);
        }
        return;
      }

      await ref.read(suppliersProvider.notifier).fetchSuppliers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.supplierCodedSuccess(expName)),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.errorCodingSupplier, error: e);
      }
    }
  }

  String _buildWhatsAppMessage() {
    final impName = _importerNameCtrl.text.trim().isNotEmpty ? _importerNameCtrl.text.trim() : '-';
    final impTax = _importerTaxIdCtrl.text.trim().isNotEmpty ? _importerTaxIdCtrl.text.trim() : '-';
    final impAddr = _importerAddressCtrl.text.trim().isNotEmpty ? _importerAddressCtrl.text.trim() : '-';
    final expName = _exporterNameCtrl.text.trim().isNotEmpty ? _exporterNameCtrl.text.trim() : '-';
    final expId = _exporterRegIdCtrl.text.trim().isNotEmpty ? _exporterRegIdCtrl.text.trim() : '-';
    final expCountry = _exporterCountryCtrl.text.trim().isNotEmpty ? _exporterCountryCtrl.text.trim() : '-';
    final expAddr = _exporterAddressCtrl.text.trim().isNotEmpty ? _exporterAddressCtrl.text.trim() : '-';
    final expPhone = _exporterPhoneCtrl.text.trim().isNotEmpty ? _exporterPhoneCtrl.text.trim() : '-';
    final cargox = _cargoxIdCtrl.text.trim().isNotEmpty ? _cargoxIdCtrl.text.trim() : '-';
    final piNo = _proformaNoCtrl.text.trim().isNotEmpty ? _proformaNoCtrl.text.trim() : '-';
    final piDate = _proformaDateCtrl.text.trim().isNotEmpty ? _proformaDateCtrl.text.trim() : '-';
    final poNo = _poNoCtrl.text.trim().isNotEmpty ? _poNoCtrl.text.trim() : '-';
    final pol = _polCtrl.text.trim().isNotEmpty ? _polCtrl.text.trim() : '-';
    final pod = _podCtrl.text.trim().isNotEmpty ? _podCtrl.text.trim() : '-';
    final reqDate = _requestedDateCtrl.text.trim().isNotEmpty ? _requestedDateCtrl.text.trim() : '-';

    return '''📋 *طلب استخراج رقم ACID جديد*
━━━━━━━━━━━━━━━━━━━━
🏢 *المستورد المصري:* $impName
🔢 *البطاقة الضريبية:* $impTax
📍 *العنوان المسجل:* $impAddr

🌍 *المصدر الأجنبي:* $expName
🆔 *المعرف الضريبي / نوعه:* $expId ($_exporterRegType)
🌐 *دولة المنشأ / التصدير:* $expCountry
📍 *عنوان المصدر:* $expAddr
📞 *هاتف المصدر:* $expPhone
🔑 *حساب كارجو إكس (CargoX ID):* $cargox

📄 *رقم الفاتورة المبدئية:* $piNo
📅 *تاريخ الفاتورة المبدئية:* $piDate
📑 *نوع الفاتورة:* $_invoiceType
📦 *أمر الشراء (PO):* $poNo
🚢 *ميناء الشحن (POL):* $pol
⚓ *ميناء الوصول (POD):* $pod
📅 *تاريخ تقديم الطلب:* $reqDate
━━━━━━━━━━━━━━━━━━━━
⚠️ *ملاحظة:* يرجى مراجعة الفاتورة المبدئية وسرعة موافاتنا برقم الـ ACID فور صدوره مع خالص الشكر.''';
  }

  String _buildEmailMessage() {
    final impName = _importerNameCtrl.text.trim().isNotEmpty ? _importerNameCtrl.text.trim() : 'Import';
    final piNo = _proformaNoCtrl.text.trim().isNotEmpty ? _proformaNoCtrl.text.trim() : '';
    final broker = _brokerNameCtrl.text.trim().isNotEmpty ? _brokerNameCtrl.text.trim() : 'مكتب التخليص الجمركي';

    return '''الموضوع: طلب إصدار رقم ACID - شحنة $impName - فاتورة $piNo

السيد المخلص الجمركي المحترم / $broker
تحية طيبة وبعد،،،

يرجى التكرم ببدء إجراءات طلب واستخراج رقم القيد الجمركي المبدئي (ACID) عبر منظومة نافذة للشحنة الموضحة بياناتها أدناه:

1. بيانات المستورد المصري:
   - اسم المستورد: ${_importerNameCtrl.text.trim()}
   - الرقم الضريبي: ${_importerTaxIdCtrl.text.trim()}
   - العنوان: ${_importerAddressCtrl.text.trim()}

2. بيانات المصدر الأجنبي:
   - اسم المصدر: ${_exporterNameCtrl.text.trim()}
   - نوع التسجيل والمعرف: ${_exporterRegIdCtrl.text.trim()} ($_exporterRegType)
   - دولة المنشأ: ${_exporterCountryCtrl.text.trim()}
   - عنوان المصدر: ${_exporterAddressCtrl.text.trim()}
   - هاتف المصدر: ${_exporterPhoneCtrl.text.trim()}
   - كود كارجو إكس (CargoX): ${_cargoxIdCtrl.text.trim()}

3. بيانات الفاتورة والشحن:
   - رقم الفاتورة المبدئية: ${_proformaNoCtrl.text.trim()}
   - تاريخ الفاتورة المبدئية: ${_proformaDateCtrl.text.trim()}
   - أمر الشراء: ${_poNoCtrl.text.trim()}
   - ميناء الشحن: ${_polCtrl.text.trim()}
   - ميناء الوصول: ${_podCtrl.text.trim()}

تجدون برفقه الفاتورة المبدئية للاطلاع والبدء في الإجراءات.
شاكرين لكم حسن تعاونكم الدائم.

قسم الاستيراد والتخليص الجمركي
Sorour Logistics ERP System''';
  }

  String _buildEnglishRequestMessage() {
    final impName = _importerNameCtrl.text.trim().isNotEmpty ? _importerNameCtrl.text.trim() : '-';
    final impTax = _importerTaxIdCtrl.text.trim().isNotEmpty ? _importerTaxIdCtrl.text.trim() : '-';
    final impAddr = _importerAddressCtrl.text.trim().isNotEmpty ? _importerAddressCtrl.text.trim() : '-';
    final expName = _exporterNameCtrl.text.trim().isNotEmpty ? _exporterNameCtrl.text.trim() : '-';
    final expId = _exporterRegIdCtrl.text.trim().isNotEmpty ? _exporterRegIdCtrl.text.trim() : '-';
    final expCountry = _exporterCountryCtrl.text.trim().isNotEmpty ? _exporterCountryCtrl.text.trim() : '-';
    final expAddr = _exporterAddressCtrl.text.trim().isNotEmpty ? _exporterAddressCtrl.text.trim() : '-';
    final expPhone = _exporterPhoneCtrl.text.trim().isNotEmpty ? _exporterPhoneCtrl.text.trim() : '-';
    final cargox = _cargoxIdCtrl.text.trim().isNotEmpty ? _cargoxIdCtrl.text.trim() : '-';
    final piNo = _proformaNoCtrl.text.trim().isNotEmpty ? _proformaNoCtrl.text.trim() : '-';
    final piDate = _proformaDateCtrl.text.trim().isNotEmpty ? _proformaDateCtrl.text.trim() : '-';
    final poNo = _poNoCtrl.text.trim().isNotEmpty ? _poNoCtrl.text.trim() : '-';
    final pol = _polCtrl.text.trim().isNotEmpty ? _polCtrl.text.trim() : '-';
    final pod = _podCtrl.text.trim().isNotEmpty ? _podCtrl.text.trim() : '-';
    final reqDate = _requestedDateCtrl.text.trim().isNotEmpty ? _requestedDateCtrl.text.trim() : '-';

    return '''📋 *Advance Cargo Information (ACID) Request*
━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏢 *Egyptian Importer:* $impName
🔢 *Tax ID:* $impTax
📍 *Registered Address:* $impAddr

🌍 *Foreign Exporter / Supplier:* $expName
🆔 *Exporter Reg. ID:* $expId ($_exporterRegType)
🌐 *Country of Origin / Export:* $expCountry
📍 *Exporter Address:* $expAddr
📞 *Tel. / Mobile:* $expPhone
🔑 *CargoX Platform ID:* $cargox

📄 *Proforma Invoice No.:* $piNo
📅 *Proforma Invoice Date:* $piDate
📑 *Invoice Type:* $_invoiceType
📦 *Purchase Order (PO):* $poNo
🚢 *Port of Loading (POL):* $pol
⚓ *Port of Discharge (POD):* $pod
📅 *Request Date:* $reqDate
━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ *Important Note:* Please initiate the ACID issuance on the Nafeza (MTS) portal and provide us with the 19-digit ACID number upon generation. Thank you.''';
  }

  Future<void> _exportAcidRegistryToExcel(List<dynamic> list, List<dynamic> importFiles) async {
    final headers = [
      context.l10n.acidNumberCol,
      context.l10n.importFile,
      context.l10n.foreignExporterCol,
      context.l10n.importerCompanyCol,
      context.l10n.issueDateCol,
      context.l10n.expiryDateCol,
      context.l10n.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued
          ? context.l10n.issuedAndValidStatus
          : (isDraft ? context.l10n.tempDraftStatus : context.l10n.underReviewStatus);
      return [
        s.acidNumber.isNotEmpty ? s.acidNumber : '-',
        fileLabel,
        s.exporterName,
        s.importerName,
        dateStr,
        expStr,
        statusLabel,
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBAcidRegistryStage,
      importFileNameOrCode: 'ACID_Registry',
    );
  }

  Future<void> _exportAcidRegistryToPdf(List<dynamic> list, List<dynamic> importFiles) async {
    final headers = [
      context.l10n.acidNumberCol,
      context.l10n.importFile,
      context.l10n.foreignExporterCol,
      context.l10n.importerCompanyCol,
      context.l10n.issueDateCol,
      context.l10n.expiryDateCol,
      context.l10n.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued
          ? context.l10n.issuedAndValidStatus
          : (isDraft ? context.l10n.tempDraftStatus : context.l10n.underReviewStatus);
      return [
        s.acidNumber.isNotEmpty ? s.acidNumber : '-',
        fileLabel,
        s.exporterName,
        s.importerName,
        dateStr,
        expStr,
        statusLabel,
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBAcidRegistryStage,
      importFileNameOrCode: 'ACID_Registry',
    );
  }

  void _copyAcidRegistryAsTsv(List<dynamic> list, List<dynamic> importFiles) {
    final headers = [
      context.l10n.acidNumberCol,
      context.l10n.importFile,
      context.l10n.foreignExporterCol,
      context.l10n.importerCompanyCol,
      context.l10n.issueDateCol,
      context.l10n.expiryDateCol,
      context.l10n.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued
          ? context.l10n.issuedAndValidStatus
          : (isDraft ? context.l10n.tempDraftStatus : context.l10n.underReviewStatus);
      return [
        s.acidNumber.isNotEmpty ? s.acidNumber : '-',
        fileLabel,
        s.exporterName,
        s.importerName,
        dateStr,
        expStr,
        statusLabel,
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportAcidExpiryToExcel(List<dynamic> list, List<dynamic> importFiles) async {
    final headers = [
      context.l10n.acidNumberCol,
      context.l10n.importFile,
      context.l10n.foreignExporterCol,
      context.l10n.expiryDateCol,
      context.l10n.daysRemainingCol,
      context.l10n.validityStatusCol,
    ];
    final rows = list.map((t) {
      final days = t.daysRemaining;
      final isExp = t.status == 'Expired' || days <= 0;
      final isWarning = !isExp && days <= 14;
      final matchedFile = importFiles.where((f) => f.importFileId == t.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? t.importFileCode ?? '-';
      final statusLabel = isExp ? context.l10n.expiredStatusBadge : isWarning ? context.l10n.expiringSoonStatusBadge : context.l10n.validStatusBadge;
      return [
        t.acidNumber,
        fileLabel,
        t.supplierName,
        t.acidExpiryDate ?? '-',
        days > 0 ? '$days' : '0',
        statusLabel,
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBAcidExpiryStage,
      importFileNameOrCode: 'ACID_Expiry_Tracker',
    );
  }

  Future<void> _exportAcidExpiryToPdf(List<dynamic> list, List<dynamic> importFiles) async {
    final headers = [
      context.l10n.acidNumberCol,
      context.l10n.importFile,
      context.l10n.foreignExporterCol,
      context.l10n.expiryDateCol,
      context.l10n.daysRemainingCol,
      context.l10n.validityStatusCol,
    ];
    final rows = list.map((t) {
      final days = t.daysRemaining;
      final isExp = t.status == 'Expired' || days <= 0;
      final isWarning = !isExp && days <= 14;
      final matchedFile = importFiles.where((f) => f.importFileId == t.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? t.importFileCode ?? '-';
      final statusLabel = isExp ? context.l10n.expiredStatusBadge : isWarning ? context.l10n.expiringSoonStatusBadge : context.l10n.validStatusBadge;
      return [
        t.acidNumber,
        fileLabel,
        t.supplierName,
        t.acidExpiryDate ?? '-',
        days > 0 ? '$days' : '0',
        statusLabel,
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocBAcidExpiryStage,
      importFileNameOrCode: 'ACID_Expiry_Tracker',
    );
  }

  void _copyAcidExpiryAsTsv(List<dynamic> list, List<dynamic> importFiles) {
    final headers = [
      context.l10n.acidNumberCol,
      context.l10n.importFile,
      context.l10n.foreignExporterCol,
      context.l10n.expiryDateCol,
      context.l10n.daysRemainingCol,
      context.l10n.validityStatusCol,
    ];
    final rows = list.map((t) {
      final days = t.daysRemaining;
      final isExp = t.status == 'Expired' || days <= 0;
      final isWarning = !isExp && days <= 14;
      final matchedFile = importFiles.where((f) => f.importFileId == t.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? t.importFileCode ?? '-';
      final statusLabel = isExp ? context.l10n.expiredStatusBadge : isWarning ? context.l10n.expiringSoonStatusBadge : context.l10n.validStatusBadge;
      return [
        t.acidNumber,
        fileLabel,
        t.supplierName,
        t.acidExpiryDate ?? '-',
        days > 0 ? '$days' : '0',
        statusLabel,
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }
}
