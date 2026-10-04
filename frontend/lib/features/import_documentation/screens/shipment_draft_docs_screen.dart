import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/coo_review_tab.dart';
import '../widgets/customs_document_approval_tab.dart';
import '../widgets/draft_bl_review_tab.dart';
import '../widgets/inspection_review_tab.dart';
import '../widgets/invoice_bl_matcher_tab.dart';
import '../widgets/po_reconciliation_tab.dart';
import '../widgets/search_and_clone_customs_approval_dialog.dart';
import '../widgets/search_and_clone_po_reconciliation_dialog.dart';
import '../widgets/search_and_clone_draft_bl_dialog.dart';
import '../widgets/search_and_clone_coo_dialog.dart';
import '../../cargo_insurance/screens/cargo_insurance_screen.dart';
import '../widgets/formal_letter_generator_dialog.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';


class ShipmentDraftDocsScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const ShipmentDraftDocsScreen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<ShipmentDraftDocsScreen> createState() => _ShipmentDraftDocsScreenState();
}

class _ShipmentDraftDocsScreenState extends ConsumerState<ShipmentDraftDocsScreen> {
  // Active Vertical Sub-Tab:
  // 0: 🛡️ مركز اعتماد المستندات الجمركية (Docs Customs Approval Hub)
  // 1: 📦 مطابقة الفاتورة والباكينج (PO & Packing Reconciliation)
  // 2: 📄 مسودة بوليصة الشحن (Draft B/L Review & Dual Approval)
  // 3: ⚡ الاستخراج ومطابقة الفاتورة والبوليصة (Smart Invoice vs. B/L Reconciliation)
  // 4: 📜 مسودة شهادة المنشأ و EUR.1 (Draft COO / EUR.1 Review)
  // 5: 🛡️ شهادات الفحص والمطابقة (Inspection & Conformity Review)
  // NOTE: Original Docs Collection & CargoX have been moved to OriginalDocsAndCargoXScreen (Phase 4)
  int _selectedSubTab = 0;
  int? _selectedImportFileId;
  final GlobalKey<CustomsDocumentApprovalTabState> _customsApprovalTabKey = GlobalKey<CustomsDocumentApprovalTabState>();
  final GlobalKey<POReconciliationTabState> _poReconciliationTabKey = GlobalKey<POReconciliationTabState>();
  final GlobalKey<COOReviewTabState> _cooReviewTabKey = GlobalKey<COOReviewTabState>();
  GuideMatchResultModel? _guideMatchResult;

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
  void didUpdateWidget(covariant ShipmentDraftDocsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() {
        _selectedSubTab = widget.initialSubTab;
      });
    }
    if (oldWidget.initialImportFileId != widget.initialImportFileId && widget.initialImportFileId != null) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
      });
      _loadGuideForFile(widget.initialImportFileId);
    }
  }

  Future<void> _refreshData() async {
    if (!ref.read(importFilesProvider).isLoading) {
      await ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    if (!ref.read(shipmentDocumentsProvider).isLoading) {
      ref.read(shipmentDocumentsProvider.notifier).fetchShipmentDocuments();
    }
    if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
      setState(() {
        _selectedImportFileId = files.first.importFileId;
      });
    }
    _loadGuideForFile(_selectedImportFileId);
  }

  Future<void> _loadGuideForFile(int? fileId) async {
    if (fileId == null) {
      if (mounted) setState(() => _guideMatchResult = null);
      return;
    }
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) return;

    try {
      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: file.supplierName,
        hsCode: file.hsCode,
        productCategory: file.productCategory,
        portOfLoading: file.portOfLoading,
        portOfDischarge: file.portOfDischarge,
        incoterm: file.incotermCode,
        importFileReference: file.importFileCode,
      );
      if (mounted) {
        setState(() => _guideMatchResult = res);
      }
    } catch (_) {}
  }

  void _openSearchAndCloneDialog() {
    if (_selectedSubTab == 0) {
      if (_customsApprovalTabKey.currentState != null) {
        _customsApprovalTabKey.currentState!.openSearchAndCloneDialog();
      } else {
        final approvals = ref.read(docsCustomsApprovalProvider).valueOrNull ?? [];
        showDialog(
          context: context,
          builder: (ctx) => SearchAndCloneCustomsApprovalDialog(
            items: approvals,
            onSelectItem: (item) {
              setState(() {
                _selectedSubTab = 0;
                _selectedImportFileId = item.importFileId;
              });
              _loadGuideForFile(item.importFileId);
            },
          ),
        );
      }
      return;
    }
    if (_selectedSubTab == 1) {
      if (_poReconciliationTabKey.currentState != null) {
        _poReconciliationTabKey.currentState!.openSearchAndCloneDialog();
      } else {
        final sessions = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
        showDialog(
          context: context,
          builder: (ctx) => SearchAndClonePoReconciliationDialog(
            sessions: sessions,
            onSelectSession: (s) {
              setState(() {
                _selectedSubTab = 1;
                _selectedImportFileId = s.importFileId;
              });
              _loadGuideForFile(s.importFileId);
            },
          ),
        );
      }
      return;
    }
    if (_selectedSubTab == 4) {
      if (_cooReviewTabKey.currentState != null) {
        _cooReviewTabKey.currentState!.openSearchAndCloneDialog();
      } else {
        final cooReviews = ref.read(cooReviewsProvider).valueOrNull ?? [];
        showDialog(
          context: context,
          builder: (ctx) => SearchAndCloneCooDialog(
            reviews: cooReviews,
            onSelectReview: (r) {
              setState(() {
                _selectedSubTab = 4;
                _selectedImportFileId = r.importFileId ?? _selectedImportFileId;
              });
              _loadGuideForFile(_selectedImportFileId);
            },
          ),
        );
      }
      return;
    }

    final allReviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => SearchAndCloneDraftBlDialog(
        reviews: allReviews,
        onSelectReview: (r) {
          setState(() {
            _selectedSubTab = 2; // Jump to Draft B/L Review Tab
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [

      const VerticalNavTabItem(
        icon: Icons.verified_user,
        titleEn: 'Docs Customs Approval & Rectifications Hub',
        titleAr: 'مركز اعتماد المستندات وتعديلات المورد',
      ),
      const VerticalNavTabItem(
        icon: Icons.fact_check_outlined,
        titleEn: 'PO & Packing Reconciliation',
        titleAr: 'مطابقة الفاتورة وقائمة التعبئة',
      ),
      const VerticalNavTabItem(
        icon: Icons.assignment_turned_in_outlined,
        titleEn: 'Draft B/L Review & Approval',
        titleAr: 'مسودة بوليصة الشحن والاعتماد',
      ),
      const VerticalNavTabItem(
        icon: Icons.auto_awesome,
        titleEn: 'Smart Invoice vs B/L Match',
        titleAr: 'استخراج ومطابقة الفاتورة والبوليصة',
      ),
      const VerticalNavTabItem(
        icon: Icons.flag_circle_outlined,
        titleEn: 'Draft COO & EUR.1 Review',
        titleAr: 'مسودة شهادة المنشأ و EUR.1',
      ),
      const VerticalNavTabItem(
        icon: Icons.security_outlined,
        titleEn: 'Inspection Review',
        titleAr: 'شهادات الفحص والمطابقة',
      ),
      const VerticalNavTabItem(
        icon: Icons.shield_outlined,
        titleEn: 'Cargo Insurance Certificate',
        titleAr: 'وثيقة وشهادة التأمين على البضائع',
      ),
    ];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openSearchAndCloneDialog,
      },
      child: Focus(
        autofocus: true,
        child: VerticalStageScaffold(
          stageCode: 'PHASE-3',
          titleEn: 'Shipment Draft Documents Review',
          titleAr: 'مراجعة وتدقيق مسودات مستندات الشحن — المرحلة 3',
          headerIcon: Icons.folder_open_outlined,
          headerColor: AppTheme.emerald,
          tabs: tabs,
          selectedIndex: _selectedSubTab,
          onTabSelected: (index) => setState(() => _selectedSubTab = index),
          selectedImportFileId: _selectedImportFileId,
          onShipmentStatusChanged: _refreshData,
          topBanner: (_guideMatchResult != null && _guideMatchResult!.matchedEntries.isNotEmpty)
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                  child: ExperienceGuideAlertBanner(
                    matchResult: _guideMatchResult!,
                  ),
                )
              : null,
          headerActions: [
            IconButton(
              key: Key(_selectedSubTab == 0
                  ? 'searchAndCloneCustomsApprovalBtn'
                  : (_selectedSubTab == 1
                      ? 'searchAndClonePoReconBtn'
                      : (_selectedSubTab == 4 ? 'searchAndCloneCooBtn' : 'searchAndCloneDraftBlBtn'))),
              icon: const Icon(Icons.copy_all, color: Colors.white70),
              tooltip: _selectedSubTab == 0
                  ? context.l10n.searchAndCloneCustomsApprovalBtn
                  : (_selectedSubTab == 1
                      ? context.l10n.searchAndClonePoReconBtn
                      : (_selectedSubTab == 4 ? context.l10n.searchAndCloneCooBtn : context.l10n.searchAndCloneDraftBlBtn)),
              onPressed: _openSearchAndCloneDialog,
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.charcoal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => FormalLetterGeneratorDialog.show(context, importFileId: _selectedImportFileId),
              icon: const Icon(Icons.description, size: 16, color: AppTheme.cobalt),
              label: Text(context.l10n.formalLetterDialogTitle),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              tooltip: context.l10n.refresh,
              onPressed: _refreshData,
            ),
          ],
          body: _buildCurrentSubTabContent(),
        ),
      ),
    );
  }

  Widget _buildCurrentSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return CustomsDocumentApprovalTab(
          key: _customsApprovalTabKey,
          initialImportFileId: _selectedImportFileId,
        );
      case 1:
        return POReconciliationTab(
          key: _poReconciliationTabKey,
          initialImportFileId: _selectedImportFileId,
        );
      case 2:
        return DraftBLReviewTab(initialImportFileId: _selectedImportFileId);
      case 3:
        return InvoiceBLMatcherTab(
          selectedImportFileId: _selectedImportFileId,
          onImportFileChanged: (newId) {
            setState(() {
              _selectedImportFileId = newId;
            });
            _loadGuideForFile(newId);
          },
        );
      case 4:
        return COOReviewTab(
          key: _cooReviewTabKey,
          initialImportFileId: _selectedImportFileId,
        );
      case 5:
        return InspectionReviewTab(initialImportFileId: _selectedImportFileId);
      case 6:
        return CargoInsuranceScreen(
          key: ValueKey('cargo_insurance_embedded_$_selectedImportFileId'),
          initialImportFileId: _selectedImportFileId,
          isEmbedded: true,
        );
      default:
        return CustomsDocumentApprovalTab(
          key: _customsApprovalTabKey,
          initialImportFileId: _selectedImportFileId,
        );
    }
  }
}

