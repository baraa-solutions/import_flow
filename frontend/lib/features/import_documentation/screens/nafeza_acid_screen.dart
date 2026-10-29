import 'package:frontend/core/theme/app_theme.dart';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/models/supplier_model.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/acid_expiry_tracker_strip.dart';
import '../widgets/acid_items_compliance_checklist.dart';
import '../widgets/edit_mts_data_dialog.dart';
import '../widgets/nafeza_acid_registration_tab.dart';
import '../widgets/search_and_clone_acid_dialog.dart';

/// Nafeza Advance Cargo Information Declaration (ACID) Operations Screen
///
/// Refactored to Type A Stage Screen architecture:
/// - Stage code badge: `PHASE-1: NAFEZA_ACID`
/// - Root wrapper: [SelectionArea] for complete mouse selection on desktop.
/// - Header actions end with [BackToDashboardButton].
/// - Modular subcomponents:
///   * [NafezaAcidRegistrationTab]: Request form, customs certificate, and foreign supplier.
///   * MTS Smart Parser: Nafeza raw notification parsing.
///   * [AcidItemsComplianceChecklist]: Items compliance and customs comparison matrix.
///   * ACID Issuance Registry: Historical session records and soft deletion.
///   * [AcidExpiryTrackerStrip]: 14-day expiry warnings and validity lifecycle tracking.
/// - Sanitized copying of ACID number exclusively via [CopyHelper.copy].
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
  // 0: ACID Request Form (NafezaAcidRegistrationTab)
  // 1: MTS Smart AI Parser
  // 2: Discrepancy Matrix (AcidItemsComplianceChecklist)
  // 3: ACID Issuance Registry
  // 4: Expiry & Release Tracker (AcidExpiryTrackerStrip)
  int _selectedSubTab = 0;

  // Selected Import File & Active Edit Session
  int? _selectedImportFileId;
  int? _editingAcidSessionId;
  String? _editingAcidCode;
  AcidRegistrationModel? _clonedSessionForTab0;

  // Controllers for Tab 1 (Smart MTS Parser)
  final TextEditingController _rawMtsTextCtrl = TextEditingController();
  Map<String, dynamic>? _parsedMtsData;
  bool _isParsingMts = false;

  // Tab 2 (Comparison Result)
  AcidComparisonResult? _comparisonResult;

  // Tab 3 (Registry & Final Save)
  String _acidSearchQuery = '';
  bool _isSaving = false;
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
      setState(() => _selectedImportFileId = widget.initialImportFileId);
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
    _rawMtsTextCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final acidSessions = ref.watch(acidSessionsProvider).valueOrNull ?? [];
    final trackerSummary = ref.watch(acidTrackerProvider).valueOrNull;
    final trackerItems = trackerSummary?.items ?? [];
    final l = context.l10n;

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
                  _comparisonResult!.allMatched ? l.matchedStatus : l.discrepancyStatus,
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

    return SelectionArea(
      child: VerticalStageScaffold(
        stageCode: 'PHASE-1: NAFEZA_ACID',
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
          AppButton(
            key: const Key('searchAndCloneAcidBtn'),
            label: l.searchAndCloneAcidBtn,
            onPressed: _openSearchAndCloneDialog,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            icon: Icons.copy_all,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.cloudWhite),
            tooltip: l.refresh,
            onPressed: _refreshData,
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
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
      ),
    );
  }

  Widget _buildCurrentSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return NafezaAcidRegistrationTab(
          initialImportFileId: _selectedImportFileId,
          editingAcidSessionId: _editingAcidSessionId,
          editingAcidCode: _editingAcidCode,
          clonedSession: _clonedSessionForTab0,
          onImportFileChanged: (fileId) => setState(() => _selectedImportFileId = fileId),
          onGoToSmartParser: () => setState(() => _selectedSubTab = 1),
          onOpenSearchAndClone: _openSearchAndCloneDialog,
          onSaved: (sessionId, acidCode) {
            setState(() {
              _editingAcidSessionId = sessionId;
              _editingAcidCode = acidCode;
              _selectedSubTab = 1;
            });
          },
          onCancelEdit: () {
            setState(() {
              _editingAcidSessionId = null;
              _editingAcidCode = null;
            });
          },
        );
      case 1:
        return _buildSmartMtsParserTab();
      case 2:
        return AcidItemsComplianceChecklist(
          selectedImportFileId: _selectedImportFileId,
          parsedMtsData: _parsedMtsData,
          comparisonResult: _comparisonResult,
          onImportFileChanged: (fileId) => setState(() => _selectedImportFileId = fileId),
          onComparisonDone: (res) => setState(() => _comparisonResult = res),
          onAcidCertified: () => setState(() => _selectedSubTab = 3),
        );
      case 3:
        return _buildAcidSessionsRegistryTab();
      case 4:
        return AcidExpiryTrackerStrip(
          onCloneTrackerItem: _onCloneTrackerItem,
          onRefresh: _refreshData,
        );
      default:
        return NafezaAcidRegistrationTab(
          initialImportFileId: _selectedImportFileId,
          onGoToSmartParser: () => setState(() => _selectedSubTab = 1),
        );
    }
  }

  // --- SUB-VIEW 1: SMART MTS PARSER TAB ---
  Widget _buildSmartMtsParserTab() {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

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
                      l.smartParserInfoBanner,
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
                labelText: l.linkImportFileResult,
                hintText: l.searchFileOrSupplierHint,
                value: _selectedImportFileId,
                items: importFiles.map((f) => SearchableDropdownItem<int>(
                  value: f.importFileId,
                  label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName}',
                )).toList(),
                onChanged: (val) => setState(() => _selectedImportFileId = val),
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
                    '${l.pasteRawMtsTextTitle}:',
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
                        AppButton(
                          label: l.loadSampleMtsTextButton,
                          onPressed: _loadSampleMtsText,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          icon: Icons.auto_fix_high,
                        ),
                      AppButton(
                        label: l.importFromPreviousAcidSessionBtn,
                        onPressed: _openImportRawTextFromPreviousDialog,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        icon: Icons.history_edu,
                      ),
                      AppButton(
                        label: l.pasteFromClipboardButton,
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _rawMtsTextCtrl.text = data!.text!;
                          }
                        },
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        icon: Icons.paste,
                      ),
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
                      hintText: l.mtsNotificationHint,
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
                      AppButton(
                        label: _isParsingMts ? l.loading : l.runSmartParserButton,
                        onPressed: _isParsingMts ? null : _parseMtsText,
                        icon: Icons.bolt,
                        isLoading: _isParsingMts,
                      ),
                      AppButton(
                        label: l.clearTextButton,
                        onPressed: () => setState(() {
                          _rawMtsTextCtrl.clear();
                          _parsedMtsData = null;
                        }),
                        variant: AppButtonVariant.secondary,
                        icon: Icons.clear_all,
                      ),
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
                                  ? l.parsedMtsSuccessTitle
                                  : l.parsedMtsNoAcidTitle,
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
                      AppButton(
                        label: l.goToVerificationButton,
                        onPressed: () => setState(() => _selectedSubTab = 2),
                        icon: Icons.compare_arrows,
                      ),
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
                                  ? l.parsedMtsSuccessTitle
                                  : l.parsedMtsNoAcidTitle,
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
                          AppButton(
                            label: l.goToVerificationButton,
                            onPressed: () => setState(() => _selectedSubTab = 2),
                            icon: Icons.compare_arrows,
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _buildExtractedField(l.acidNumberCol, _parsedMtsData!['acid_number']?.toString().isNotEmpty ?? false ? _parsedMtsData!['acid_number']!.toString() : '-'),
                        _buildExtractedField(l.issueDateCol, _parsedMtsData!['generated_date']?.toString() ?? '-'),
                        _buildExtractedField(l.expiryDateCol, _parsedMtsData!['expiry_date']?.toString() ?? '-'),
                        _buildExtractedField(l.importerCompanyCol, _parsedMtsData!['importer_name']?.toString() ?? '-'),
                        _buildExtractedField(l.importerTaxIdLabel, _parsedMtsData!['importer_tax_id']?.toString() ?? '-'),
                        _buildExtractedField(l.foreignExporterCol, _parsedMtsData!['exporter_name']?.toString() ?? '-'),
                        _buildExtractedField(l.foreignExporterIdLabel, _parsedMtsData!['exporter_reg_id']?.toString() ?? '-'),
                        _buildExtractedField(l.regTypeLabel, _parsedMtsData!['exporter_reg_type']?.toString() ?? 'Company Registration Number'),
                        _buildExtractedField(l.countryOfOriginExportLabel, _parsedMtsData!['exporter_country']?.toString() ?? '-'),
                        _buildExtractedField(l.cargoxPlatformIdLabel, _parsedMtsData!['cargox_id']?.toString() ?? '-'),
                        _buildExtractedField(l.proformaInvoiceNoLabel, _parsedMtsData!['proforma_invoice_no']?.toString() ?? '-'),
                        _buildExtractedField(l.portOfLoadingLabel, _parsedMtsData!['pol_name']?.toString() ?? '-'),
                        _buildExtractedField(l.portOfDischargeLabel, _parsedMtsData!['pod_name']?.toString() ?? '-'),
                      ],
                    ),
                    const Divider(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        AppButton(
                          label: l.saveAndCertifyAcidButton,
                          onPressed: _isSaving ? null : () => _saveMtsResultAsAcidSession(isDraft: false),
                          variant: AppButtonVariant.success,
                          icon: Icons.save_as,
                        ),
                        AppButton(
                          label: l.saveTempDraftButton,
                          onPressed: _isSaving ? null : () => _saveMtsResultAsAcidSession(isDraft: true),
                          icon: Icons.save_outlined,
                        ),
                        AppButton(
                          label: l.editExtractedDataButton,
                          onPressed: _showEditMtsDataDialog,
                          variant: AppButtonVariant.secondary,
                          icon: Icons.edit,
                        ),
                        AppButton(
                          label: l.codeSupplierButton,
                          onPressed: _codeSupplierFromMts,
                          icon: Icons.business_outlined,
                        ),
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
    return InkWell(
      onTap: () => CopyHelper.copy(context, val),
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
      ),
    );
  }

  // --- SUB-VIEW 3: ACID REGISTRY TAB ---
  Widget _buildAcidSessionsRegistryTab() {
    final acidSessions = ref.watch(acidSessionsProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

    final filtered = acidSessions.where((s) {
      if (_acidSearchQuery.isEmpty) return true;
      final q = _acidSearchQuery.toLowerCase();
      return s.acidNumber.toLowerCase().contains(q) ||
          (s.importFileCode != null && s.importFileCode!.toLowerCase().contains(q)) ||
          s.exporterName.toLowerCase().contains(q);
    }).toList();

    final searchField = TextField(
      key: const Key('acidRegistrySearchField'),
      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
      decoration: InputDecoration(
        hintText: l.searchAcidRegistryHint,
        hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
        prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      ),
      onChanged: (val) => setState(() => _acidSearchQuery = val),
    );

    final actionButtons = [
      AppButton(
        key: const Key('acidRegistryNewRequestBtn'),
        label: l.newAcidRequestButton,
        onPressed: () => setState(() {
          _editingAcidSessionId = null;
          _editingAcidCode = null;
          _clonedSessionForTab0 = null;
          _selectedSubTab = 0;
        }),
        icon: Icons.add,
      ),
      AppButton(
        key: const Key('acidRegistryCopyBtn'),
        label: l.copyTable,
        onPressed: () => _copyAcidRegistryAsTsv(filtered, importFiles),
        variant: AppButtonVariant.secondary,
        icon: Icons.copy,
      ),
      AppButton(
        key: const Key('acidRegistryExcelBtn'),
        label: l.exportExcel,
        onPressed: () => _exportAcidRegistryToExcel(filtered, importFiles),
        variant: AppButtonVariant.secondary,
        icon: Icons.table_chart,
      ),
      AppButton(
        key: const Key('acidRegistryPdfBtn'),
        label: l.exportPdf,
        onPressed: () => _exportAcidRegistryToPdf(filtered, importFiles),
        variant: AppButtonVariant.secondary,
        icon: Icons.picture_as_pdf,
      ),
    ];

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
                  searchField,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actionButtons,
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 8),
                  ...actionButtons.map((btn) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: btn,
                      )),
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
                      l.noAcidsFound,
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
              EnterpriseDataTable<AcidRegistrationModel>(
                data: filtered,
                storageKey: 'nafeza_acid_registry_table',
                columns: [
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'actions',
                    title: l.actionCol,
                    width: 155,
                    isSortable: false,
                    isSearchable: false,
                    cellBuilder: (context, s, index) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.edit_note, color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt, size: 20),
                            tooltip: l.edit,
                            onPressed: () => _loadSessionForEdit(s),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            key: Key('cloneRowBtn_${s.acidId}'),
                            icon: Icon(Icons.copy_all, color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald, size: 20),
                            tooltip: l.cloneAcidRecordTooltip,
                            onPressed: () => _onCloneAcidSelected(s),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                            tooltip: l.delete,
                            onPressed: () => _confirmDeleteAcidSession(s),
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'acid_number',
                    title: l.acidNumberCol,
                    width: 170,
                    isSortable: true,
                    searchValue: (s) => s.acidNumber,
                    exportValue: (s) => s.acidNumber,
                    cellBuilder: (context, s, index) {
                      return InkWell(
                        onTap: () => CopyHelper.copy(context, s.acidNumber),
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          s.acidNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                          ),
                        ),
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'import_file',
                    title: l.importFile,
                    width: 180,
                    isSortable: true,
                    searchValue: (s) {
                      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
                      return matchedFile?.displayName ?? s.importFileCode ?? '-';
                    },
                    exportValue: (s) {
                      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
                      return matchedFile?.displayName ?? s.importFileCode ?? '-';
                    },
                    cellBuilder: (context, s, index) {
                      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
                      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
                      final poLabel = (s.poNumber != null && s.poNumber!.trim().isNotEmpty)
                          ? s.poNumber!.trim()
                          : (matchedFile?.poNumber ?? s.proformaInvoiceNo);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                            ),
                          ),
                          if (poLabel.isNotEmpty && poLabel != '-')
                            Text(
                              '${l.poLabelPrefix}: $poLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                            ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'exporter',
                    title: l.foreignExporterCol,
                    width: 160,
                    isSortable: true,
                    searchValue: (s) => s.exporterName,
                    exportValue: (s) => s.exporterName,
                    cellBuilder: (context, s, index) => Text(
                      s.exporterName,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'importer',
                    title: l.importerCompanyCol,
                    width: 160,
                    isSortable: true,
                    searchValue: (s) => s.importerName,
                    exportValue: (s) => s.importerName,
                    cellBuilder: (context, s, index) => Text(
                      s.importerName,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'issue_date',
                    title: l.issueDateCol,
                    width: 120,
                    isSortable: true,
                    searchValue: (s) => s.generatedDate ?? s.requestedDate ?? '',
                    exportValue: (s) => (s.generatedDate ?? s.requestedDate ?? '').substring(0, min(10, (s.generatedDate ?? s.requestedDate ?? '').length)),
                    cellBuilder: (context, s, index) {
                      final dateStr = s.generatedDate ?? s.requestedDate ?? '';
                      return Text(
                        dateStr.isNotEmpty ? dateStr.substring(0, min(10, dateStr.length)) : '-',
                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'expiry_date',
                    title: l.expiryDateCol,
                    width: 120,
                    isSortable: true,
                    searchValue: (s) => s.expiryDate ?? '',
                    exportValue: (s) => (s.expiryDate ?? '').substring(0, min(10, (s.expiryDate ?? '').length)),
                    cellBuilder: (context, s, index) {
                      final expStr = s.expiryDate ?? '';
                      return Text(
                        expStr.isNotEmpty ? expStr.substring(0, min(10, expStr.length)) : '-',
                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'validity_status',
                    title: l.validityStatusCol,
                    width: 130,
                    isSortable: true,
                    searchValue: (s) {
                      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
                      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
                      return isIssued ? l.issuedAndValidStatus : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
                    },
                    exportValue: (s) {
                      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
                      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
                      return isIssued ? l.issuedAndValidStatus : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
                    },
                    cellBuilder: (context, s, index) {
                      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
                      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
                      final statusLabel = isIssued
                          ? l.issuedAndValidStatus
                          : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
                      final severity = isIssued
                          ? AppSeverity.success
                          : (isDraft ? AppSeverity.warning : AppSeverity.info);
                      return AppStatusBadge(
                        label: statusLabel,
                        severity: severity,
                        size: AppStatusBadgeSize.small,
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  // --- ACTIONS ---
  void _loadSessionForEdit(AcidRegistrationModel session) {
    setState(() {
      _selectedImportFileId = session.importFileId;
      _editingAcidSessionId = session.acidId;
      _editingAcidCode = session.acidCode;
      _clonedSessionForTab0 = null;
      _selectedSubTab = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.acidSessionLoadedForEdit(session.acidCode), severity: AppSeverity.info),
    );
  }

  void _confirmDeleteAcidSession(AcidRegistrationModel session) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 24),
            const SizedBox(width: 8),
            Text(l.confirmSoftDelete, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CopyableText('ACID (${session.acidCode}) — (${session.acidNumber})'),
            const SizedBox(height: 10),
            Text(l.confirmSoftDelete, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          AppButton(
            label: l.cancel,
            onPressed: () => Navigator.pop(ctx),
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: l.delete,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(acidSessionsProvider.notifier).softDeleteAcidSession(session.acidId);
                await ref.read(importFilesProvider.notifier).fetchImportFiles();
                await ref.read(acidTrackerProvider.notifier).fetchAcidTracker();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    AppTheme.snackBar(context, l.acidSessionDeletedSuccess(session.acidCode)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  showErrorDetailsDialog(context, title: l.errorDeletingAcid, error: e);
                }
              }
            },
            variant: AppButtonVariant.danger,
            icon: Icons.delete_forever,
          ),
        ],
      ),
    );
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
                _selectedImportFileId = session.importFileId;
                _clonedSessionForTab0 = session;
                _selectedSubTab = 0;
              });

              ScaffoldMessenger.of(context).showSnackBar(
AppTheme.snackBar(context, l.cloneAcidSuccess, severity: AppSeverity.success),
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
                  _selectedImportFileId = session.importFileId;
                }
              });

              ScaffoldMessenger.of(context).showSnackBar(
AppTheme.snackBar(context, context.l10n.rawTextImportedSuccess, severity: AppSeverity.success),
              );

              _parseMtsText();
            },
          ),
        ),
      ),
    );
  }

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
    final l = context.l10n;
    final raw = _rawMtsTextCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.pasteMtsTextFirst, severity: AppSeverity.danger),
      );
      return;
    }

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
              Text(l.mtsNoticeDisclaimerAlertTitle),
            ],
          ),
          content: Text(
            l.mtsNoticeDisclaimerAlertContent,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            AppButton(
              label: l.close,
              onPressed: () => Navigator.pop(ctx),
              variant: AppButtonVariant.secondary,
            ),
            if (kDebugMode)
              AppButton(
                label: l.loadSampleMtsAndTest,
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadSampleMtsText();
                },
                icon: Icons.auto_fix_high,
              ),
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
AppTheme.snackBar(context, l.acidExtractedSuccess(parsedFields['acid_number']?.toString() ?? ''), severity: AppSeverity.success),
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
                  Text(l.mtsNoticeNoAcidAlertTitle),
                ],
              ),
              content: Text(
                l.mtsNoticeNoAcidAlertContent,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              actions: [
                AppButton(
                  label: l.close,
                  onPressed: () => Navigator.pop(ctx),
                  variant: AppButtonVariant.secondary,
                ),
                if (kDebugMode)
                  AppButton(
                    label: l.loadSampleMtsAndExtract,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _loadSampleMtsText();
                    },
                    icon: Icons.auto_fix_high,
                  ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: l.errorParsingMts, error: e);
      }
    } finally {
      if (mounted) setState(() => _isParsingMts = false);
    }
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

  Future<void> _saveMtsResultAsAcidSession({bool isDraft = false}) async {
    final l = context.l10n;
    if (_parsedMtsData == null) return;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.selectImportFileFirst, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final acidNum = _parsedMtsData!['acid_number']?.toString().trim() ?? '';
      final payload = {
        'import_file_id': _selectedImportFileId,
        'importer_name': _parsedMtsData!['importer_name']?.toString().trim() ?? '',
        'importer_tax_id': _parsedMtsData!['importer_tax_id']?.toString().trim() ?? '',
        'importer_address': _parsedMtsData!['importer_address']?.toString().trim() ?? '',
        'exporter_name': _parsedMtsData!['exporter_name']?.toString().trim() ?? '',
        'exporter_reg_type': _parsedMtsData!['exporter_reg_type']?.toString().trim() ?? 'Company Registration Number',
        'exporter_reg_id': _parsedMtsData!['exporter_reg_id']?.toString().trim() ?? '',
        'exporter_country': _parsedMtsData!['exporter_country']?.toString().trim() ?? '',
        'exporter_country_code': _parsedMtsData!['exporter_country_code']?.toString().trim() ?? '',
        'exporter_address': _parsedMtsData!['exporter_address']?.toString().trim() ?? '',
        'exporter_phone': _parsedMtsData!['exporter_phone']?.toString().trim() ?? '',
        'cargox_id': _parsedMtsData!['cargox_id']?.toString().trim() ?? '',
        'proforma_invoice_no': _parsedMtsData!['proforma_invoice_no']?.toString().trim() ?? '',
        'proforma_invoice_date': _parsedMtsData!['proforma_invoice_date']?.toString().trim() ?? '',
        if (_parsedMtsData!['invoice_date'] != null && _parsedMtsData!['invoice_date'].toString().trim().isNotEmpty)
          'invoice_date': _parsedMtsData!['invoice_date'].toString().trim(),
        'invoice_type': _parsedMtsData!['invoice_type']?.toString().trim() ?? 'Proforma Invoice',
        'pol_name': _parsedMtsData!['pol_name']?.toString().trim() ?? '',
        'pod_name': _parsedMtsData!['pod_name']?.toString().trim() ?? '',
        'requested_date': _parsedMtsData!['requested_date']?.toString().trim() ?? '',
        if (_parsedMtsData!['generated_date'] != null && _parsedMtsData!['generated_date'].toString().trim().isNotEmpty)
          'generated_date': _parsedMtsData!['generated_date'].toString().trim(),
        if (_parsedMtsData!['expiry_date'] != null && _parsedMtsData!['expiry_date'].toString().trim().isNotEmpty)
          'expiry_date': _parsedMtsData!['expiry_date'].toString().trim(),
        'acid_number': acidNum.isNotEmpty ? acidNum : 'PENDING',
        'raw_nafeza_text': _rawMtsTextCtrl.text.trim(),
        'status': isDraft ? 'DRAFT' : (acidNum.isNotEmpty ? 'Issued' : 'Pending Issue'),
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
AppTheme.snackBar(context, isDraft ? l.acidRequestSavedSuccess : l.acidCertifiedSuccess, severity: isDraft ? AppSeverity.info : AppSeverity.success),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: isDraft ? l.errorSavingDraft : l.errorSavingAcid, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showEditMtsDataDialog() {
    if (_parsedMtsData == null) return;
    EditMtsDataDialog.show(
      context,
      initialData: _parsedMtsData!,
      onSaved: (updated) {
        setState(() {
          _parsedMtsData = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.mtsExtractedDataUpdated, severity: AppSeverity.success),
        );
      },
    );
  }

  Future<void> _codeSupplierFromMts() async {
    final l = context.l10n;
    if (_parsedMtsData == null) return;
    final expName = _parsedMtsData!['exporter_name']?.toString().trim() ?? '';
    if (expName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.foreignSupplierNotInData, severity: AppSeverity.danger),
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
          showErrorDetailsDialog(context, title: l.errorCodingSupplier, error: err);
        }
        return;
      }

      await ref.read(suppliersProvider.notifier).fetchSuppliers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
AppTheme.snackBar(context, l.supplierCodedSuccess(expName), severity: AppSeverity.success),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: l.errorCodingSupplier, error: e);
      }
    }
  }

  Future<void> _exportAcidRegistryToExcel(List<dynamic> list, List<dynamic> importFiles) async {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.importerCompanyCol,
      l.issueDateCol,
      l.expiryDateCol,
      l.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued
          ? l.issuedAndValidStatus
          : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
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
      stageName: l.idocBAcidRegistryStage,
      importFileNameOrCode: 'ACID_Registry',
    );
  }

  Future<void> _exportAcidRegistryToPdf(List<dynamic> list, List<dynamic> importFiles) async {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.importerCompanyCol,
      l.issueDateCol,
      l.expiryDateCol,
      l.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued
          ? l.issuedAndValidStatus
          : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
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
      stageName: l.idocBAcidRegistryStage,
      importFileNameOrCode: 'ACID_Registry',
    );
  }

  void _copyAcidRegistryAsTsv(List<dynamic> list, List<dynamic> importFiles) {
    final l = context.l10n;
    final headers = [
      l.acidNumberCol,
      l.importFile,
      l.foreignExporterCol,
      l.importerCompanyCol,
      l.issueDateCol,
      l.expiryDateCol,
      l.validityStatusCol,
    ];
    final rows = list.map((s) {
      final dateStr = s.generatedDate ?? s.requestedDate ?? '-';
      final expStr = s.expiryDate ?? '-';
      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
      final statusLabel = isIssued
          ? l.issuedAndValidStatus
          : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
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
}
