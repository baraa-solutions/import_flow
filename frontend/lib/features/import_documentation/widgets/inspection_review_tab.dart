import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/system_messages/coded_item_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/import_doc_stepper.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'inspection_review/inspection_review_controllers.dart';
import 'inspection_review/inspection_review_criteria_card.dart';
import 'inspection_review/inspection_review_dialogs.dart';
import 'inspection_review/inspection_review_findings_table.dart';
import 'inspection_review/inspection_review_header.dart';
import 'inspection_review/inspection_review_registry_card.dart';
import 'inspection_review/inspection_review_workflow_service.dart';

class InspectionReviewTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const InspectionReviewTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<InspectionReviewTab> createState() => _InspectionReviewTabState();
}

class _InspectionReviewTabState extends ConsumerState<InspectionReviewTab> {
  int _activeStep = 0;
  int? _selectedImportFileId;
  String _inspType = 'COC (Certificate of Conformity)';
  String _inspAgency = 'SGS';
  final InspectionReviewControllers _controllers = InspectionReviewControllers();
  late final InspectionReviewWorkflowService _workflow = InspectionReviewWorkflowService(ref);

  bool _isLoading = false;
  Map<String, dynamic>? _comparisonResult;
  String? _pickedFileName;
  Map<String, dynamic>? _activeDraftTemplate;
  String? _activeAcidNumber;
  List<String> _activeStandards = [];

  List<ImportDocStep> _buildSteps(AppLocalizations l10n) => [
        ImportDocStep(label: '1. ${l10n.inspStepRequirements}', icon: Icons.fact_check_outlined),
        ImportDocStep(label: '2. ${l10n.inspStepDraftInput}', icon: Icons.file_upload),
        ImportDocStep(label: '3. ${l10n.inspStepDiscrepancyMatrix}', icon: Icons.rule),
        ImportDocStep(label: '4. ${l10n.inspStepRegistry}', icon: Icons.history),
      ];

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(importFilesProvider).isLoading) await ref.read(importFilesProvider.notifier).fetchImportFiles();
      if (!ref.read(inspectionReviewsProvider).isLoading) await ref.read(inspectionReviewsProvider.notifier).fetchInspectionReviews();
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
        setState(() => _selectedImportFileId = files.first.importFileId);
      }
      if (_selectedImportFileId != null) _loadSnapshot(_selectedImportFileId!);
    });
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InspectionReviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      setState(() => _selectedImportFileId = widget.initialImportFileId);
      _loadSnapshot(_selectedImportFileId!);
    }
  }

  void _loadSnapshot(int fileId) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file != null) _controllers.applyFileSnapshot(file);
    _fetchAndApplyDraft(fileId);
  }

  Future<void> _fetchAndApplyDraft(int fileId) async {
    final res = await _workflow.fetchDraftTemplate(fileId: fileId, agency: _inspAgency, certType: _inspType);
    if (res != null && mounted) {
      setState(() {
        _activeDraftTemplate = res['template'] as Map<String, dynamic>;
        _activeAcidNumber = res['acidNumber'] as String;
        _activeStandards = res['standards'] as List<String>;
        _controllers.applyDraftTemplate(_activeDraftTemplate!, _activeStandards);
      });
    }
  }

  String get _effectiveAcid => (_activeAcidNumber ?? '').trim().isNotEmpty
      ? _activeAcidNumber!.trim()
      : _controllers.acidCtrl.text.trim();

  List<String> get _effectiveStandards => _activeStandards.isNotEmpty
      ? _activeStandards
      : _controllers.specCtrl.text.trim().split('\n').where((s) => s.isNotEmpty).toList();

  List<dynamic> get _exportMatrix => CodedItemText.localizeRows(
        _comparisonResult?['comparison_matrix'] as List<dynamic>?,
        context.l10n,
        forExport: true,
      );

  Map<String, dynamic> get _exportTemplate => _controllers.buildExportTemplate(
        activeDraftTemplate: _activeDraftTemplate,
        effectiveAcid: _effectiveAcid,
      );

  Future<void> _runComparison() async {
    setState(() => _isLoading = true);
    final res = await _workflow.runComparison(
      context: context,
      selectedImportFileId: _selectedImportFileId,
      inspType: _inspType,
      inspAgency: _inspAgency,
      controllers: _controllers,
    );
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

  Future<void> _saveReview() async {
    setState(() => _isLoading = true);
    final ok = await _workflow.saveReview(
      context: context,
      selectedImportFileId: _selectedImportFileId,
      inspType: _inspType,
      inspAgency: _inspAgency,
      effectiveAcid: _effectiveAcid,
      comparisonResult: _comparisonResult,
      controllers: _controllers,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (ok) _activeStep = 3;
      });
    }
  }

  Future<void> _generateOfficialDraft() async {
    setState(() => _isLoading = true);
    await _workflow.generateOfficialDraft(
      context: context,
      selectedImportFileId: _selectedImportFileId,
      inspAgency: _inspAgency,
      certType: _inspType,
      onRefresh: () => _fetchAndApplyDraft(_selectedImportFileId!),
      onLoaded: (template, acidNo, standards) {
        setState(() {
          _activeDraftTemplate = template;
          _activeAcidNumber = acidNo;
          _activeStandards = standards;
        });
      },
      onApplyData: () {
        setState(() {
          _controllers.applyDialogDraftTemplate(_activeDraftTemplate ?? {}, _activeStandards);
          _activeStep = 1;
        });
      },
    );
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _extractFromOcrText() async {
    setState(() => _isLoading = true);
    await _workflow.extractFromOcrText(
      context: context,
      selectedImportFileId: _selectedImportFileId,
      controllers: _controllers,
      onMetaFound: (agency, type) {
        _inspAgency = agency;
        _inspType = type;
      },
    );
    if (mounted) setState(() => _isLoading = false);
  }

  void _onEditReview(InspectionCertificateReviewModel r) {
    setState(() {
      _selectedImportFileId = r.importFileId;
      _inspType = r.inspectionType;
      _inspAgency = r.inspectionAgency;
      _controllers.loadSession(r);
      if (r.comparisonMatrix.isNotEmpty) {
        _comparisonResult = {
          'comparison_matrix': r.comparisonMatrix,
          'has_discrepancies': r.hasDiscrepancies,
          'has_critical_mismatch': r.hasCriticalMismatch,
          'system_snapshot_data': r.systemSnapshotData,
          'draft_input_data': r.draftInputData,
        };
      }
      _activeStep = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.loadedInspSessionForEdit(r.inspectionReviewCode), severity: AppSeverity.info),
    );
  }

  void _onSelectImportFile(int? v) {
    if (v != null) {
      setState(() => _selectedImportFileId = v);
      _loadSnapshot(v);
    }
  }

  void _onSelectInspType(String? v) {
    setState(() => _inspType = v ?? 'COC (Certificate of Conformity)');
    if (_selectedImportFileId != null) _fetchAndApplyDraft(_selectedImportFileId!);
  }

  void _onSelectInspAgency(String? v) {
    setState(() => _inspAgency = v ?? 'SGS');
    if (_selectedImportFileId != null) _fetchAndApplyDraft(_selectedImportFileId!);
  }

  void _export(InspectionExportType type) => _workflow.handleExport(
        context: context,
        type: type,
        effectiveAcid: _effectiveAcid,
        template: _exportTemplate,
        agency: _inspAgency,
        certType: _inspType,
        standards: _effectiveStandards,
        matrix: _exportMatrix,
        overrideReason: _controllers.overrideReasonCtrl.text.trim().isNotEmpty
            ? _controllers.overrideReasonCtrl.text.trim()
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return SelectionArea(
      child: Column(
        children: [
          ImportDocStepper(
            steps: _buildSteps(l10n),
            currentStep: _activeStep,
            onStepTapped: (i) => setState(() => _activeStep = i),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(importFiles),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(List<ImportFileModel> importFiles) {
    switch (_activeStep) {
      case 0:
        final existingReviews = ref.watch(inspectionReviewsProvider).valueOrNull ?? [];
        final existingReview = existingReviews.where((r) => r.importFileId == _selectedImportFileId).firstOrNull;
        return InspectionReviewHeader(
          selectedImportFileId: _selectedImportFileId,
          inspType: _inspType,
          inspAgency: _inspAgency,
          importFiles: importFiles,
          existingReview: existingReview,
          activeDraftTemplate: _activeDraftTemplate,
          activeAcidNumber: _activeAcidNumber,
          activeStandards: _activeStandards,
          onSelectImportFile: _onSelectImportFile,
          onSelectInspType: _onSelectInspType,
          onSelectInspAgency: _onSelectInspAgency,
          onOpenPreview: _generateOfficialDraft,
          onNextStep: () => setState(() => _activeStep = 1),
          onViewRegistry: () => setState(() => _activeStep = 3),
          onRefreshDraft: () => _selectedImportFileId != null ? _fetchAndApplyDraft(_selectedImportFileId!) : null,
        );
      case 1:
        return InspectionReviewCriteriaCard(
          controllers: _controllers,
          importFiles: importFiles,
          selectedImportFileId: _selectedImportFileId,
          inspType: _inspType,
          inspAgency: _inspAgency,
          isLoading: _isLoading,
          pickedFileName: _pickedFileName,
          onSelectImportFile: _onSelectImportFile,
          onSelectInspType: (v) => setState(() => _inspType = v ?? 'COC (Certificate of Conformity)'),
          onSelectInspAgency: (v) => setState(() => _inspAgency = v ?? 'SGS'),
          onRunComparison: _runComparison,
          onSmartUploadExtracted: (res) => setState(() {
            _pickedFileName = res.filename;
            _controllers.applySmartUpload(res.extractedFields, (a) => _inspAgency = a);
          }),
          onExtractOcr: _extractFromOcrText,
        );
      case 2:
        return InspectionReviewFindingsTable(
          selectedImportFileId: _selectedImportFileId,
          comparisonResult: _comparisonResult,
          controllers: _controllers,
          onReturnToStep1: () => setState(() => _activeStep = 1),
          onExportTsv: () => _export(InspectionExportType.tsv),
          onExportExcel: () => _export(InspectionExportType.excel),
          onExportPdf: () => _export(InspectionExportType.pdf),
          onCopyDossier: () => _export(InspectionExportType.dossier),
          onSaveReview: _saveReview,
        );
      case 3:
        return ref.watch(inspectionReviewsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(context.l10n.saveInspectionReviewError(err.toString()))),
          data: (reviews) => InspectionReviewRegistryCard(
            reviews: reviews,
            onStartNewReview: () => setState(() => _activeStep = 1),
            onEdit: _onEditReview,
            onViewDetails: (r) => InspectionReviewDialogs.showDetailsDialog(context: context, review: r),
            onDownloadPdf: (r) => _workflow.downloadReviewPdf(context: context, review: r, activeStandards: _activeStandards),
            onDelete: (r) => InspectionReviewDialogs.confirmDelete(context: context, ref: ref, review: r),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
