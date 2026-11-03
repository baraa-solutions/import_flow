import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/acid_expiry_tracker_strip.dart';
import '../widgets/acid_items_compliance_checklist.dart';
import '../widgets/nafeza_acid/acid_sessions_registry_tab.dart';
import '../widgets/nafeza_acid/nafeza_acid_dialogs.dart';
import '../widgets/nafeza_acid/nafeza_smart_mts_parser_tab.dart';
import '../widgets/nafeza_acid_registration_tab.dart';

/// Nafeza Advance Cargo Information Declaration (ACID) Operations Screen
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
  int _selectedSubTab = 0;
  int? _selectedImportFileId;
  int? _editingAcidSessionId;
  String? _editingAcidCode;
  AcidRegistrationModel? _clonedSessionForTab0;

  final TextEditingController _rawMtsTextCtrl = TextEditingController();
  Map<String, dynamic>? _parsedMtsData;
  AcidComparisonResult? _comparisonResult;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() => _refreshData());
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
    if (!ref.read(importFilesProvider).isLoading) ref.read(importFilesProvider.notifier).fetchImportFiles();
    if (!ref.read(importCompaniesProvider).isLoading) ref.read(importCompaniesProvider.notifier).fetchCompanies();
    if (!ref.read(suppliersProvider).isLoading) ref.read(suppliersProvider.notifier).fetchSuppliers();
    if (!ref.read(partnersProvider).isLoading) ref.read(partnersProvider.notifier).fetchPartners();
    if (!ref.read(purchaseOrdersProvider).isLoading) ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    if (!ref.read(acidSessionsProvider).isLoading) ref.read(acidSessionsProvider.notifier).fetchAcidSessions();
    if (!ref.read(acidTrackerProvider).isLoading) ref.read(acidTrackerProvider.notifier).fetchAcidTracker();
  }

  @override
  void dispose() {
    _rawMtsTextCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openSearchAndCloneDialog() {
    NafezaAcidDialogs.openSearchAndCloneDialog(
      context: context,
      ref: ref,
      onCloneAcidSelected: _onCloneAcidSelected,
    );
  }

  void _onCloneAcidSelected(AcidRegistrationModel session) {
    NafezaAcidDialogs.showCloneAcidReviewDialog(
      context: context,
      session: session,
      onConfirmed: (s) {
        setState(() {
          _editingAcidSessionId = null;
          _editingAcidCode = null;
          _selectedImportFileId = s.importFileId;
          _clonedSessionForTab0 = s;
          _selectedSubTab = 0;
        });
      },
    );
  }

  void _openImportRawTextFromPreviousDialog() {
    NafezaAcidDialogs.openImportRawTextFromPreviousDialog(
      context: context,
      ref: ref,
      onImportText: (text, fileId) {
        setState(() {
          _rawMtsTextCtrl.text = text;
          if (fileId != null && _selectedImportFileId == null) {
            _selectedImportFileId = fileId;
          }
        });
      },
    );
  }

  void _onCloneTrackerItem(AcidTrackerItemModel item) {
    final acidSessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    final session = NafezaAcidDialogs.buildFallbackSessionFromTracker(item, acidSessions);
    _onCloneAcidSelected(session);
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
        return NafezaSmartMtsParserTab(
          selectedImportFileId: _selectedImportFileId,
          onImportFileChanged: (fId) => setState(() => _selectedImportFileId = fId),
          initialParsedData: _parsedMtsData,
          onParsedDataChanged: (d) => setState(() => _parsedMtsData = d),
          onGoToVerification: () => setState(() => _selectedSubTab = 2),
          onOpenImportFromPrevious: _openImportRawTextFromPreviousDialog,
          rawMtsTextController: _rawMtsTextCtrl,
        );
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
        return AcidSessionsRegistryTab(
          onLoadSessionForEdit: (s) {
            setState(() {
              _selectedImportFileId = s.importFileId;
              _editingAcidSessionId = s.acidId;
              _editingAcidCode = s.acidCode;
              _clonedSessionForTab0 = null;
              _selectedSubTab = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(context, context.l10n.acidSessionLoadedForEdit(s.acidCode), severity: AppSeverity.info),
            );
          },
          onCloneAcidSelected: _onCloneAcidSelected,
          onNewRequest: () => setState(() {
            _editingAcidSessionId = null;
            _editingAcidCode = null;
            _clonedSessionForTab0 = null;
            _selectedSubTab = 0;
          }),
        );
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
}
