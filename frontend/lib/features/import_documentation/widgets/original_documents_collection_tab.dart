import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/original_documents_collection_model.dart';
import '../providers/original_documents_collection_provider.dart';
import 'idoc_feedback.dart';
import 'original_documents/original_docs_actions_bar.dart';
import 'original_documents/original_docs_courier_alerts_banner.dart';
import 'original_documents/original_docs_courier_tracking_card.dart';
import 'original_documents/original_docs_dialogs.dart';
import 'original_documents/original_docs_dossier_table.dart';
import 'original_documents/original_docs_filter_bar.dart';
import 'original_documents/original_docs_header.dart';
import 'original_documents/original_docs_registry_section.dart';
import 'original_documents/original_docs_session_notes_card.dart';

/// Coordinator widget for Screen 57: Original Documents Collection & Courier Tracking.
/// Radically decomposed into modular subcomponents adhering strictly to Owner's Guardrails.
class OriginalDocumentsCollectionTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const OriginalDocumentsCollectionTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<OriginalDocumentsCollectionTab> createState() =>
      _OriginalDocumentsCollectionTabState();
}

class _OriginalDocumentsCollectionTabState
    extends ConsumerState<OriginalDocumentsCollectionTab> {
  final _formKey = GlobalKey<FormState>();

  ImportFileModel? _selectedImportFile;
  OriginalDocumentsCollectionSessionModel? _existingSession;

  List<CourierEntryModel> _couriers = [];
  List<OriginalDocumentItemModel> _documents = [];

  bool _isLoading = false;
  bool _isSaving = false;

  String _sessionStatus = 'DRAFT';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _overrideReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(originalDocumentsSessionsProvider).isLoading) {
        ref.read(originalDocumentsSessionsProvider.notifier).fetchSessions();
      }
      ref.invalidate(courierAlertsProvider);
      ref.invalidate(allCouriersProvider);
      if (widget.initialImportFileId != null) {
        _loadInitialFile(widget.initialImportFileId!);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _overrideReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFile(int fileId) async {
    final filesAsync = ref.read(importFilesProvider);
    filesAsync.whenData((files) {
      final match = files.where((f) => f.importFileId == fileId).firstOrNull;
      if (match != null) {
        _onSelectImportFile(match);
      }
    });
  }

  Future<void> _onSelectImportFile(ImportFileModel file) async {
    final l = context.l10n;
    setState(() {
      _selectedImportFile = file;
      _existingSession = null;
      _couriers = [];
      _documents = [];
      _notesController.clear();
      _overrideReasonController.clear();
      _isLoading = true;
    });

    try {
      final notifier = ref.read(originalDocumentsSessionsProvider.notifier);
      final autoData = await notifier.fetchAutoPopulate(file.importFileId);

      if (!mounted) return;
      setState(() {
        if (autoData.existingSession != null) {
          _existingSession = autoData.existingSession;
          _couriers = List.from(autoData.existingSession!.couriersList);
          _documents = List.from(autoData.existingSession!.documentsList);
          _sessionStatus = autoData.existingSession!.status;
          _notesController.text = autoData.existingSession!.notes ?? '';
          _overrideReasonController.text =
              autoData.existingSession!.discrepancyOverrideReason ?? '';
        } else {
          _couriers = List.from(autoData.defaultCouriers);
          _documents = List.from(autoData.requiredDocuments);
          _sessionStatus = 'DRAFT';
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.errorFetchingArchiveData(ApiErrorText.of(l, e)),
          severity: AppSeverity.danger,
        ),
      );
    }
  }

  void _addCourier() {
    setState(() {
      _couriers.add(
        CourierEntryModel(
          courierNo: '',
          courierCompany: '',
          dispatchDate: DateTime.now().toIso8601String().substring(0, 10),
          isReceived: false,
        ),
      );
    });
  }

  void _removeCourier(int index) {
    setState(() {
      _couriers.removeAt(index);
    });
  }

  void _addCustomDocument() {
    setState(() {
      _documents.add(
        OriginalDocumentItemModel(
          category: 'Commercial',
          documentName: storedText.defaultNewCustomDocName,
          isRequired: 'Yes',
          responsibleParty: 'Supplier',
          status: 'Pending',
        ),
      );
    });
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  Future<void> _handleSaveSession({bool isConfirmComplete = false}) async {
    final l = context.l10n;
    if (_selectedImportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.selectImportFileFirstWarning, severity: AppSeverity.danger),
      );
      return;
    }

    if (isConfirmComplete) {
      final unverified = _documents.where((d) => !d.isVerified && d.isRequired == 'Yes').toList();
      if (unverified.isNotEmpty && _overrideReasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.unverifiedMandatoryDocsWarning, severity: AppSeverity.warning),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(originalDocumentsSessionsProvider.notifier);
      final payload = {
        'import_file_id': _selectedImportFile!.importFileId,
        'import_file_code': _selectedImportFile!.importFileCode,
        'acid_number': _selectedImportFile!.acidNumber,
        'importer_name': _selectedImportFile!.companyName,
        'supplier_name': _selectedImportFile!.supplierName,
        'status': isConfirmComplete ? 'FULLY_VERIFIED' : _sessionStatus,
        'couriers_list': _couriers.map((c) => c.toJson()).toList(),
        'documents_list': _documents.map((d) => d.toJson()).toList(),
        'discrepancy_override_reason': _overrideReasonController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      final saved = await notifier.saveOrUpsertSession(payload);
      if (!mounted) return;
      setState(() {
        _existingSession = saved;
        _sessionStatus = saved.status;
        _isSaving = false;
      });

      ref.invalidate(courierAlertsProvider);
      ref.invalidate(allCouriersProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.sessionSavedSuccess(saved.collectionCode),
          severity: AppSeverity.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.sessionSaveError(ApiErrorText.of(l, e)), severity: AppSeverity.danger),
      );
    }
  }

  void _showDeliveryProof({
    required int importFileId,
    required String courierNo,
    required String courierCompany,
    String? trackingNo,
    required String importFileCode,
  }) {
    OriginalDocsDialogs.showCourierDeliveryProofDialog(
      context: context,
      ref: ref,
      importFileId: importFileId,
      courierNo: courierNo,
      courierCompany: courierCompany,
      trackingNo: trackingNo,
      importFileCode: importFileCode,
      onSessionReload: () async {
        if (_selectedImportFile?.importFileId == importFileId) {
          await _loadInitialFile(importFileId);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(importFilesProvider);
    final sessionsAsync = ref.watch(originalDocumentsSessionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OriginalDocsHeader(existingSession: _existingSession),
                if (_isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                OriginalDocsFilterBar(
                  selectedImportFile: _selectedImportFile,
                  documents: _documents,
                  filesAsync: filesAsync,
                  onSelectImportFile: _onSelectImportFile,
                  onRefreshFiles: () =>
                      ref.read(importFilesProvider.notifier).fetchImportFiles(),
                ),
                if (_selectedImportFile != null) ...[
                  const SizedBox(height: 16),
                  OriginalDocsCourierTrackingCard(
                    couriers: _couriers,
                    selectedImportFile: _selectedImportFile,
                    onAddCourier: _addCourier,
                    onRemoveCourier: _removeCourier,
                    onChanged: () => setState(() {}),
                    onShowDeliveryProof: _showDeliveryProof,
                  ),
                  const SizedBox(height: 16),
                  OriginalDocsDossierTable(
                    documents: _documents,
                    couriers: _couriers,
                    currentUserName: idocCurrentUserName(ref),
                    onAddCustomDocument: _addCustomDocument,
                    onRemoveDocument: _removeDocument,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  OriginalDocsSessionNotesCard(
                    notesController: _notesController,
                    overrideReasonController: _overrideReasonController,
                  ),
                  const SizedBox(height: 16),
                  OriginalDocsActionsBar(
                    isSaving: _isSaving,
                    selectedImportFile: _selectedImportFile,
                    documents: _documents,
                    couriers: _couriers,
                    existingSession: _existingSession,
                    notesText: _notesController.text,
                    overrideReasonText: _overrideReasonController.text,
                    onSaveDraft: () => _handleSaveSession(isConfirmComplete: false),
                    onCompleteCollection: () => _handleSaveSession(isConfirmComplete: true),
                  ),
                ],
                const SizedBox(height: 24),
                OriginalDocsCourierAlertsBanner(
                  onShowDeliveryProof: _showDeliveryProof,
                ),
                const SizedBox(height: 16),
                OriginalDocsRegistrySection(
                  sessionsAsync: sessionsAsync,
                  onLoadFile: _loadInitialFile,
                  onShowDeliveryProof: _showDeliveryProof,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
