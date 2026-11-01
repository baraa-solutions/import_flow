import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/helpers/file_picker_helper.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../providers/import_documentation_provider.dart';
import 'draft_bl_review/draft_bl_clone_dialog.dart';
import 'draft_bl_review/draft_bl_controllers.dart';
import 'draft_bl_review/draft_bl_dialogs.dart';
import 'draft_bl_review/draft_bl_dual_approval_view.dart';
import 'draft_bl_review/draft_bl_final_registry_view.dart';
import 'draft_bl_review/draft_bl_review_sheet_view.dart';
import 'draft_bl_review/draft_bl_revision_view.dart';
import 'draft_bl_review/draft_bl_version_branching_view.dart';
import 'draft_bl_review/draft_bl_workflow_service.dart';
import 'idoc_feedback.dart';
import 'search_and_clone_draft_bl_dialog.dart';

typedef DraftBlReviewTab = DraftBLReviewTab;

/// Coordinator widget for Maritime Draft Bill of Lading (B/L) Review (< 400 lines).
class DraftBLReviewTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const DraftBLReviewTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<DraftBLReviewTab> createState() => _DraftBLReviewTabState();
}

class _DraftBLReviewTabState extends ConsumerState<DraftBLReviewTab> {
  int _activeStep = 0;
  int? _selectedImportFileId;
  final _ctrls = DraftBlControllers();
  late final _workflow = DraftBlWorkflowService(ref);

  bool _isLoading = false;
  bool _isUploadingFile = false;
  bool _isSavingDraft = false;
  bool _isCertifying = false;
  String? _uploadedFileName;
  int? _uploadedFileSize;
  String? _extractionStatus;
  List<dynamic> _missingCriticalFields = [];
  String? _safetyWarning;
  DraftBLComparisonResultModel? _comparisonResult;
  DraftBLReviewModel? _activeSession;

  @override
  void initState() {
    super.initState();
    _ctrls.initUserApprover(ref.read(authProvider).user?.fullName);
    _selectedImportFileId = widget.initialImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(importFilesProvider).isLoading) {
        await ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
        setState(() => _selectedImportFileId = files.first.importFileId);
      }
      if (_selectedImportFileId != null) _runComparison(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant DraftBLReviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
      _runComparison(silent: true);
    }
  }

  @override
  void dispose() {
    _workflow.dispose();
    _ctrls.dispose();
    super.dispose();
  }

  Set<String> _currentUserNames() {
    final u = ref.read(authProvider).user;
    return {u?.fullName ?? '', u?.username ?? ''};
  }

  void _changeImportFile(int? v, {bool clear = false}) {
    if (v != null && v != _selectedImportFileId) {
      setState(() {
        _selectedImportFileId = v;
        if (clear) {
          _ctrls.clearInputs();
          _comparisonResult = null;
          _activeSession = null;
        }
      });
      _runComparison(silent: false);
    }
  }

  Future<void> _runComparison({bool silent = false}) async {
    if (_selectedImportFileId == null) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.selectImportFileFirst, severity: AppSeverity.info));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(draftBLReviewsProvider.notifier).compareDraftBL(
            _selectedImportFileId!,
            _ctrls.toDraftFields(),
            rawText: _ctrls.rawText.text.isNotEmpty ? _ctrls.rawText.text : null,
          );
      setState(() {
        _comparisonResult = res;
        _ctrls.syncComparisonDraftData(res.draftData);
      });
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(
          context,
          res.hasBlockingMismatch ? context.l10n.draftBlComparisonMismatch(res.openDiscrepanciesCount) : context.l10n.draftBlComparisonMatchSuccess,
          severity: res.hasBlockingMismatch ? AppSeverity.warning : AppSeverity.success,
        ));
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.draftBlComparisonError(ApiErrorText.of(context.l10n, e)), severity: AppSeverity.info));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndExtractFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'txt', 'csv'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final fileBytes = FilePickerHelper.getBytes(file);
      if (fileBytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.draftBlFileReadError, severity: AppSeverity.info));
        return;
      }
      setState(() {
        _isUploadingFile = true;
        _uploadedFileName = file.name;
        _uploadedFileSize = file.size;
      });
      final res = await ref.read(draftBLReviewsProvider.notifier).extractDraftBLFromFile(fileBytes, file.name, importFileId: _selectedImportFileId);
      setState(() {
        _ctrls.rawText.text = res['raw_text'] as String? ?? '';
        _extractionStatus = res['extraction_status'] as String? ?? 'EXTRACTION_COMPLETE';
        _missingCriticalFields = res['missing_critical_fields'] as List? ?? [];
        _safetyWarning = res['safety_warning'] as String?;
        _ctrls.syncExtractedFields(res['extracted_fields'] as Map<String, dynamic>? ?? {});
        if (res['comparison_result'] != null) _comparisonResult = DraftBLComparisonResultModel.fromJson(res['comparison_result']);
      });
      if (_selectedImportFileId != null && res['comparison_result'] == null) await _runComparison(silent: true);
      if (mounted) {
        final snack = _missingCriticalFields.isNotEmpty ? context.l10n.draftBlExtractedWithCritical(file.name) : context.l10n.draftBlExtractedSuccess(file.name);
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, snack, severity: _missingCriticalFields.isNotEmpty ? AppSeverity.warning : AppSeverity.info));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.draftBlExtractionError(ApiErrorText.of(context.l10n, e)), severity: AppSeverity.info));
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  Future<void> _saveReview({bool isDraft = false}) async {
    if (_comparisonResult == null || _selectedImportFileId == null) {
      if (_selectedImportFileId == null) ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.selectImportFileFirst, severity: AppSeverity.info));
      return;
    }
    if (!isDraft && _comparisonResult!.hasBlockingMismatch) {
      final confirmed = await DraftBlDialogs.confirmBlockingMismatchSave(context, _comparisonResult!.openDiscrepanciesCount);
      if (!confirmed) return;
    }
    setState(() {
      if (isDraft) {
        _isSavingDraft = true;
      } else {
        _isCertifying = true;
      }
      _isLoading = true;
    });
    try {
      final payload = _ctrls.buildSavePayload(importFileId: _selectedImportFileId!, comparisonResult: _comparisonResult, isDraft: isDraft);
      final created = await ref.read(draftBLReviewsProvider.notifier).saveDraftBLReview(payload);
      ref.invalidate(importFilesProvider);
      ref.invalidate(docsCustomsApprovalProvider);
      ref.invalidate(smartTasksProvider);
      ref.invalidate(draftBLReviewsProvider);
      setState(() => _activeSession = created);
      if (mounted) {
        showIdocMessage(context, isDraft ? context.l10n.idocADraftBlSaved(created.blReviewCode) : context.l10n.idocADraftBlSavedForApproval(created.blReviewCode), color: isDraft ? AppTheme.cobalt : AppTheme.emerald);
      }
    } catch (e) {
      if (mounted) showIdocError(context, e, title: context.l10n.idocADraftBlSaveFailed);
    } finally {
      if (mounted) setState(() { _isSavingDraft = false; _isCertifying = false; _isLoading = false; });
    }
  }

  void _updateChecklistRow(int idx, {dynamic draftValue, String? status, String? correction, String? reason, String? respParty}) {
    if (_comparisonResult == null) return;
    setState(() => DraftBlWorkflowService.updateRow(_comparisonResult, idx, draftValue: draftValue, status: status, correction: correction, reason: reason, respParty: respParty));
    _workflow.scheduleChecklistSync(context, activeSession: _activeSession, comparisonResult: _comparisonResult, onSessionUpdated: (u) => setState(() => _activeSession = u));
  }

  void _openSearchAndCloneDialog() {
    final revs = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(child: SearchAndCloneDraftBlDialog(reviews: revs, onSelectReview: _onCloneDraftBlSession)),
    );
  }

  void _onCloneDraftBlSession(DraftBLReviewModel session) {
    DraftBlCloneDialog.show(
      context,
      session: session,
      controllers: _ctrls,
      onCloneCompleted: () async {
        setState(() { _activeSession = null; _activeStep = 0; });
        if (_selectedImportFileId != null) await _runComparison(silent: true);
      },
    );
  }

  Future<void> _handleApproveSingleStep() async {
    if (_activeSession == null) return;
    setState(() => _isLoading = true);
    final updated = await _workflow.approveSingleStep(
      context,
      session: _activeSession!,
      onFinalStageReached: () => setState(() => _activeStep = 4),
    );
    if (mounted) setState(() { if (updated != null) _activeSession = updated; _isLoading = false; });
  }

  Future<void> _handleSubmitApproval(String role, String action) async {
    if (_activeSession == null) await _saveReview();
    if (!mounted || _activeSession == null) return;
    setState(() => _isLoading = true);
    final approver = role == 'importer' ? _ctrls.importerApprover.text.trim() : _ctrls.brokerApprover.text.trim();
    final notes = role == 'importer' ? _ctrls.importerNotes.text.trim() : _ctrls.brokerNotes.text.trim();
    final updated = await _workflow.submitApproval(
      context,
      session: _activeSession!,
      role: role,
      action: action,
      approver: approver,
      notes: notes,
      onFinalStageReached: () => setState(() => _activeStep = 4),
      onRejected: () => setState(() => _activeStep = 1),
    );
    if (mounted) setState(() { if (updated != null) _activeSession = updated; _isLoading = false; });
  }

  void _loadSession(DraftBLReviewModel s) {
    setState(() {
      _selectedImportFileId = s.importFileId;
      _activeSession = s;
      _ctrls.loadFromSession(s);
      _activeStep = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.idocASessionRestoredReview(s.blReviewCode), severity: AppSeverity.info));
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final allReviews = ref.watch(draftBLReviewsProvider).valueOrNull ?? [];
    final l = context.l10n;

    Widget wrapTab(Widget child) => SingleChildScrollView(padding: const EdgeInsets.all(20), child: child);

    return SelectionArea(
      child: AdaptiveTabScaffold(
        selectedIndex: _activeStep,
        onTabSelected: (index) => setState(() => _activeStep = index),
        accentColor: AppTheme.cobalt,
        tabs: [
          AdaptiveTabItem(
            icon: Icons.fact_check,
            label: l.draftBlStage0ReviewSheet,
            content: wrapTab(DraftBlReviewSheetView(
              selectedImportFileId: _selectedImportFileId,
              importFiles: importFiles,
              onSelectImportFile: (v) => _changeImportFile(v, clear: true),
              onRefresh: () => _runComparison(silent: false),
              controllers: _ctrls,
              comparisonResult: _comparisonResult,
              activeSession: _activeSession,
              isLoading: _isLoading,
              isUploadingFile: _isUploadingFile,
              isSavingDraft: _isSavingDraft,
              isCertifying: _isCertifying,
              uploadedFileName: _uploadedFileName,
              uploadedFileSize: _uploadedFileSize,
              extractionStatus: _extractionStatus,
              missingCriticalFields: _missingCriticalFields,
              safetyWarning: _safetyWarning,
              onSearchAndClone: _openSearchAndCloneDialog,
              onSaveDraft: () => _saveReview(isDraft: true),
              onCertify: () => _saveReview(isDraft: false),
              onRequestAmendment: () => setState(() => _activeStep = 1),
              onPickAndExtractFile: _pickAndExtractFile,
              onExtractFromText: () => _runComparison(silent: false),
              onUpdateChecklistRow: _updateChecklistRow,
            )),
          ),
          AdaptiveTabItem(
            icon: Icons.assignment_late,
            label: l.draftBlStage1RevisionReport,
            content: wrapTab(DraftBlRevisionView(
              selectedImportFileId: _selectedImportFileId,
              importFiles: importFiles,
              onSelectImportFile: _changeImportFile,
              checklist: _comparisonResult?.checklist ?? [],
              correctionRequestLetter: _comparisonResult?.correctionRequestLetter,
              onProceedToVersionHistory: () => setState(() => _activeStep = 2),
              onBackToSelectFile: () => setState(() => _activeStep = 0),
            )),
          ),
          AdaptiveTabItem(
            icon: Icons.history,
            label: l.draftBlStage2VersionBranching,
            content: wrapTab(DraftBlVersionBranchingView(
              selectedImportFileId: _selectedImportFileId,
              importFiles: importFiles,
              onSelectImportFile: _changeImportFile,
              activeSession: _activeSession,
              comparisonResult: _comparisonResult,
              onProceedToDualApproval: () => setState(() => _activeStep = 3),
              onBackToSelectFile: () => setState(() => _activeStep = 0),
            )),
          ),
          AdaptiveTabItem(
            icon: Icons.verified_user,
            label: l.draftBlStage3DualApproval,
            content: wrapTab(DraftBlDualApprovalView(
              selectedImportFileId: _selectedImportFileId,
              importFiles: importFiles,
              onSelectImportFile: _changeImportFile,
              activeSession: _activeSession,
              comparisonResult: _comparisonResult,
              currentUserNames: _currentUserNames(),
              importerApproverCtrl: _ctrls.importerApprover,
              importerNotesCtrl: _ctrls.importerNotes,
              brokerApproverCtrl: _ctrls.brokerApprover,
              brokerNotesCtrl: _ctrls.brokerNotes,
              isLoading: _isLoading,
              onApproveSingleStep: _handleApproveSingleStep,
              onSubmitApproval: _handleSubmitApproval,
              onBackToSelectFile: () => setState(() => _activeStep = 0),
            )),
          ),
          AdaptiveTabItem(
            icon: Icons.inventory_2,
            label: l.draftBlStage4FinalRegistry,
            content: wrapTab(DraftBlFinalRegistryView(
              allReviews: allReviews,
              importFiles: importFiles,
              onOpenSearchAndClone: _openSearchAndCloneDialog,
              onRefreshRegistry: () {
                ref.invalidate(draftBLReviewsProvider);
                ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.draftBlRegistryUpdatedSuccess, severity: AppSeverity.info));
              },
              onCloneSession: _onCloneDraftBlSession,
              onLoadSessionIntoEditor: _loadSession,
              onDeleteSession: (s) => ref.read(draftBLReviewsProvider.notifier).deleteDraftBLReview(s.blReviewId),
            )),
          ),
        ],
      ),
    );
  }
}
