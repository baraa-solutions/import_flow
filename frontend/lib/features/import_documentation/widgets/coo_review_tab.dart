import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/import_doc_stepper.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'coo_review/coo_review_checklist_card.dart';
import 'coo_review/coo_review_controllers.dart';
import 'coo_review/coo_review_dialogs.dart';
import 'coo_review/coo_review_header.dart';
import 'coo_review/coo_review_registry_card.dart';
import 'coo_review/coo_review_service.dart';
import 'coo_review/coo_review_verification_card.dart';
import 'coo_review/coo_review_workflow_service.dart';

class COOReviewTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const COOReviewTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<COOReviewTab> createState() => COOReviewTabState();
}

class COOReviewTabState extends ConsumerState<COOReviewTab> {
  void openSearchAndCloneDialog([List<CertificateOfOriginReviewModel>? reviews]) => _openSearchAndCloneCooDialog(reviews);

  int _activeStep = 0; // 0: Requirements, 1: Smart Input, 2: Discrepancy Matrix, 3: Registry
  int? _selectedImportFileId, _filterImportFileId;
  String _selectedStatusFilter = 'ALL', _certType = 'EUR.1';
  bool _isSavingDraft = false, _isCertifying = false, _isLoading = false, _isManualChoiceRequired = false;

  final CooReviewControllers _controllers = CooReviewControllers();
  late final CooReviewWorkflowService _workflow = CooReviewWorkflowService(ref);

  Map<String, dynamic>? _comparisonResult, _activeDraftTemplate;
  String? _pickedFileName, _activeAcidNumber, _activeExemptionNotes, _recommendationAlert;
  List<String> _allowedCertTypes = [];

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(importFilesProvider).isLoading) await ref.read(importFilesProvider.notifier).fetchImportFiles();
      if (!ref.read(cooReviewsProvider).isLoading) await ref.read(cooReviewsProvider.notifier).fetchCOOReviews();
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
        setState(() => _selectedImportFileId = files.first.importFileId);
      }
      if (_selectedImportFileId != null) _loadSnapshot(_selectedImportFileId!);
    });
  }

  @override
  void didUpdateWidget(covariant COOReviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      setState(() => _selectedImportFileId = widget.initialImportFileId);
      _loadSnapshot(_selectedImportFileId!);
    }
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  void _openSearchAndCloneCooDialog([List<CertificateOfOriginReviewModel>? reviews]) {
    final list = reviews ?? ref.read(cooReviewsProvider).valueOrNull ?? [];
    CooReviewDialogs.openSearchAndCloneCooDialog(context: context, reviews: list, onSelectReview: _cloneCOOReview);
  }

  void _cloneCOOReview(CertificateOfOriginReviewModel session) {
    CooReviewDialogs.cloneCOOReview(
      context: context,
      session: session,
      onConfirmClone: (newCode, suggestedCode) {
        setState(() {
          _activeDraftTemplate = null;
          _comparisonResult = null;
          _selectedImportFileId = session.importFileId ?? _selectedImportFileId;
          _certType = session.certificateType;
          _controllers.applyClonedSession(session: session, newCode: newCode, suggestedCode: suggestedCode);
          _activeStep = 1;
        });
        if (_selectedImportFileId != null) _loadSnapshot(_selectedImportFileId!);
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.cloneCooSuccess, severity: AppSeverity.success));
      },
    );
  }

  void _loadSnapshot(int fileId) {
    final files = ref.read(importFilesProvider).value ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file != null) _controllers.applyImportFileSnapshot(file);
    _fetchAndApplyDraft(fileId);
  }

  void _onFileChanged(int? v) {
    if (v != null) {
      setState(() => _selectedImportFileId = v);
      _loadSnapshot(v);
    }
  }

  void _onCertTypeChanged(String v) {
    setState(() => _certType = v);
    if (_selectedImportFileId != null) _fetchAndApplyDraft(_selectedImportFileId!, overrideCertType: v);
  }

  Future<void> _fetchAndApplyDraft(int fileId, {String? overrideCertType}) async {
    setState(() => _isLoading = true);
    final res = await _workflow.fetchAndApplyDraft(fileId: fileId, controllers: _controllers, overrideCertType: overrideCertType);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res != null) {
          if (res['certType'] != null) _certType = res['certType'] as String;
          _recommendationAlert = res['recommendationAlert'] as String?;
          _isManualChoiceRequired = res['isManualChoiceRequired'] as bool? ?? false;
          _allowedCertTypes = res['allowedCertTypes'] as List<String>? ?? [];
          _activeDraftTemplate = res['template'] as Map<String, dynamic>?;
          _activeAcidNumber = res['acidNumber'] as String? ?? '';
          _activeExemptionNotes = res['exemptionNotes'] as String?;
        }
      });
    }
  }

  Future<void> _generateOfficialDraft() async {
    setState(() => _isLoading = true);
    await _workflow.generateOfficialDraft(
      context: context,
      fileId: _selectedImportFileId,
      certType: _certType,
      controllers: _controllers,
      onRefresh: () => _selectedImportFileId != null ? _fetchAndApplyDraft(_selectedImportFileId!) : null,
      onAutofilled: (tpl, acid, ex) {
        setState(() {
          _activeDraftTemplate = tpl;
          _activeAcidNumber = acid;
          _activeExemptionNotes = ex;
          _activeStep = 1;
        });
      },
    );
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _extractFromOcrText() async {
    setState(() => _isLoading = true);
    await _workflow.extractFromOcrText(context: context, fileId: _selectedImportFileId, certType: _certType, controllers: _controllers);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _runComparison() async {
    setState(() => _isLoading = true);
    final res = await _workflow.runComparison(context: context, fileId: _selectedImportFileId, certType: _certType, controllers: _controllers);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res != null) {
          _comparisonResult = res;
          _activeStep = 2;
        }
      });
    }
  }

  Future<void> _saveReview({bool isDraft = false}) async {
    setState(() {
      _isLoading = true;
      _isSavingDraft = isDraft;
      _isCertifying = !isDraft;
    });
    final ok = await _workflow.saveReview(context: context, fileId: _selectedImportFileId, certType: _certType, comparisonResult: _comparisonResult, controllers: _controllers, isDraft: isDraft);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSavingDraft = false;
        _isCertifying = false;
        if (ok) _activeStep = 3;
      });
    }
  }

  Future<void> _saveDraftInput() async {
    if (_comparisonResult == null) await _runComparison();
    if (_comparisonResult != null) await _saveReview(isDraft: true);
  }

  void _loadSessionIntoEditor(CertificateOfOriginReviewModel session) {
    setState(() {
      _selectedImportFileId = session.importFileId ?? _selectedImportFileId;
      _certType = session.certificateType;
      _comparisonResult = _controllers.loadSessionIntoEditor(session);
      _activeStep = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.idocBCooRestored(session.cooReviewCode), severity: AppSeverity.info));
  }

  Future<void> _deleteCOODraftSession(CertificateOfOriginReviewModel session) async {
    final ok = await CooReviewDialogs.confirmDeleteCOODraft(context: context, reviewCode: session.cooReviewCode);
    if (ok) {
      await CooReviewService.deleteReview(ref, session.cooReviewId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, context.l10n.idocBCooDeleted, severity: AppSeverity.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    if (_selectedImportFileId == null && importFiles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedImportFileId == null && importFiles.isNotEmpty) {
          final firstId = importFiles.first.importFileId;
          setState(() => _selectedImportFileId = firstId);
          _loadSnapshot(firstId);
        }
      });
    }

    final steps = [
      ImportDocStep(label: context.l10n.cooStage1Requirements, icon: Icons.description),
      ImportDocStep(label: context.l10n.cooStage2DraftInput, icon: Icons.file_upload),
      ImportDocStep(label: context.l10n.cooStage3DiscrepancyMatrix, icon: Icons.fact_check),
      ImportDocStep(label: context.l10n.cooStage4Registry, icon: Icons.history_edu),
    ];

    return SelectionArea(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
            final reviews = ref.read(cooReviewsProvider).valueOrNull ?? [];
            _openSearchAndCloneCooDialog(reviews);
          },
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              ImportDocStepper(steps: steps, currentStep: _activeStep, onStepTapped: (i) => setState(() => _activeStep = i)),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(importFiles),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(List<dynamic> importFiles) {
    switch (_activeStep) {
      case 0:
        return CooReviewHeader(
          selectedImportFileId: _selectedImportFileId,
          certType: _certType,
          originCountry: _controllers.originCountry.text,
          activeDraftTemplate: _activeDraftTemplate,
          activeAcidNumber: _activeAcidNumber,
          activeExemptionNotes: _activeExemptionNotes,
          recommendationAlert: _recommendationAlert,
          isManualChoiceRequired: _isManualChoiceRequired,
          allowedCertTypes: _allowedCertTypes,
          importFiles: importFiles,
          onFileChanged: _onFileChanged,
          onCertTypeChanged: _onCertTypeChanged,
          onRefresh: () => _selectedImportFileId != null ? _fetchAndApplyDraft(_selectedImportFileId!) : null,
          onGenerateOfficialDraft: _generateOfficialDraft,
          onNextStep: () => setState(() => _activeStep = 1),
          onGoToRegistry: () => setState(() => _activeStep = 3),
        );

      case 1:
        return CooReviewChecklistCard(
          selectedImportFileId: _selectedImportFileId,
          certType: _certType,
          importFiles: importFiles,
          controllers: _controllers,
          pickedFileName: _pickedFileName,
          isLoading: _isLoading,
          isSavingDraft: _isSavingDraft,
          onFileChanged: _onFileChanged,
          onCertTypeChanged: (v) => setState(() => _certType = v),
          onSaveDraft: (_isLoading || _selectedImportFileId == null) ? null : _saveDraftInput,
          onRunComparison: (_isLoading || _selectedImportFileId == null) ? null : _runComparison,
          onExtractFromOcrText: (_isLoading || _selectedImportFileId == null) ? null : _extractFromOcrText,
          onDataExtracted: (res) => setState(() {
            _pickedFileName = res.filename;
            _controllers.applyExtractedFields(res.extractedFields);
          }),
        );

      case 2:
        return CooReviewVerificationCard(
          selectedImportFileId: _selectedImportFileId,
          comparisonResult: _comparisonResult,
          activeDraftTemplate: _activeDraftTemplate,
          certType: _certType,
          activeAcidNumber: _activeAcidNumber,
          activeExemptionNotes: _activeExemptionNotes,
          overrideReasonCtrl: _controllers.overrideReason,
          isLoading: _isLoading,
          isSavingDraft: _isSavingDraft,
          isCertifying: _isCertifying,
          onBackToStep1: () => setState(() => _activeStep = 1),
          onSaveDraft: () => _saveReview(isDraft: true),
          onCertify: () => _saveReview(isDraft: false),
          onSaveWithJustification: () => _saveReview(isDraft: false),
          onSaveDraftJustification: () => _saveReview(isDraft: true),
          onReturnToEdit: () => setState(() => _activeStep = 1),
          onOverrideReasonChanged: () => setState(() {}),
        );

      case 3:
        return CooReviewRegistryCard(
          importFiles: importFiles,
          selectedStatusFilter: _selectedStatusFilter,
          filterImportFileId: _filterImportFileId,
          registrySearchCtrl: _controllers.registrySearch,
          onStatusFilterChanged: (v) => setState(() => _selectedStatusFilter = v),
          onFileFilterChanged: (v) => setState(() => _filterImportFileId = v),
          onSearchChanged: () => setState(() {}),
          onSearchAndClone: _openSearchAndCloneCooDialog,
          onNewDraft: () => setState(() => _activeStep = 0),
          onCloneReview: _cloneCOOReview,
          onLoadSessionIntoEditor: _loadSessionIntoEditor,
          onDeleteDraft: _deleteCOODraftSession,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
