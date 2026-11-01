import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_details_dialog.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/invoice_bl_match_session_model.dart';
import '../providers/import_documentation_provider.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_actions_bar.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_controllers.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_discrepancy_banner.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_ingestion_section.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_service.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_sessions_view.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_summary_card.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_table.dart';
import 'invoice_bl_matcher/invoice_bl_matcher_toolbar.dart';

typedef InvoiceBlMatcherTab = InvoiceBLMatcherTab;

/// Coordinator widget for Screen 22: Smart Commercial Invoice vs B/L Matcher.
///
/// Orchestrates dual ingestion, cross-document reconciliation, sessions registry,
/// certification approvals, and correction letter generations.
class InvoiceBLMatcherTab extends ConsumerStatefulWidget {
  final int? selectedImportFileId;
  final Function(int)? onImportFileChanged;
  final ValueChanged<bool>? onDirtyChanged;

  const InvoiceBLMatcherTab({
    super.key,
    this.selectedImportFileId,
    this.onImportFileChanged,
    this.onDirtyChanged,
  });

  @override
  ConsumerState<InvoiceBLMatcherTab> createState() => _InvoiceBLMatcherTabState();
}

class _InvoiceBLMatcherTabState extends ConsumerState<InvoiceBLMatcherTab> {
  late final Dio _dio = ref.read(dioProvider);
  late final Dio _uploadDio = ref.read(uploadDioProvider);
  final CancelToken _cancelToken = CancelToken();
  final InvoiceBlMatcherControllers _ctrls = InvoiceBlMatcherControllers();

  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isSavingDraft = false;
  int _activeViewMode = 0; // 0: Matcher, 1: Sessions Registry

  Map<String, dynamic>? _matchResult;
  int? _activeFileId;
  int? _activeSessionId;
  String? _activeSessionCode;
  double _sensitivity = 0.85;

  void _onTextChanged() => widget.onDirtyChanged?.call(true);

  @override
  void initState() {
    super.initState();
    _ctrls.addListener(_onTextChanged);
    _activeFileId = widget.selectedImportFileId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(importFilesProvider).isLoading) {
        await ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      if (_activeFileId == null && files.isNotEmpty && mounted) {
        setState(() => _activeFileId = files.first.importFileId);
      }
      ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId);
    });
  }

  @override
  void didUpdateWidget(covariant InvoiceBLMatcherTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedImportFileId != oldWidget.selectedImportFileId) {
      setState(() => _activeFileId = widget.selectedImportFileId);
      ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId);
    }
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    _ctrls.removeListener(_onTextChanged);
    _ctrls.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String docType) async {
    final changed = await _ctrls.pickFile(context, docType);
    if (changed && mounted) setState(() {});
  }

  void _loadSampleData() {
    _ctrls.loadSampleData(context);
    setState(() {});
  }

  void _resetAll() {
    _ctrls.reset();
    setState(() {
      _matchResult = null;
      _activeSessionId = null;
      _activeSessionCode = null;
    });
    widget.onDirtyChanged?.call(false);
  }

  Future<void> _runCrossMatching() async {
    if (!_ctrls.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.invoiceBlMatcherValidationRequired, severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await InvoiceBlMatcherService.runCrossMatching(
        dio: _dio,
        uploadDio: _uploadDio,
        cancelToken: _cancelToken,
        activeFileId: _activeFileId,
        ctrls: _ctrls,
      );

      if (!mounted) return;
      setState(() => _matchResult = data);
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.invoiceBlMatcherMatchCompletedSuccess(data['match_score_percentage']),
          severity: AppSeverity.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: context.l10n.invoiceBlMatcherMatchErrorTitle, error: e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSession({required bool isDraft}) async {
    if (_isSavingDraft || _isSyncing) return;
    setState(() => isDraft ? _isSavingDraft = true : _isSyncing = true);

    try {
      final created = await InvoiceBlMatcherService.executeSaveSession(
        context: context,
        ref: ref,
        activeFileId: _activeFileId,
        isDraft: isDraft,
        matchResult: _matchResult,
      );
      if (created != null) {
        widget.onDirtyChanged?.call(false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _isSyncing = false;
        });
      }
    }
  }

  void _loadSessionIntoMatcher(InvoiceBLMatchSessionModel session) {
    setState(() {
      _activeFileId = session.importFileId;
      _ctrls.showPackingList = session.packingListData != null;
      _activeSessionId = session.sessionId;
      _activeSessionCode = session.sessionCode;
      if (session.comparisonMatrix != null && session.comparisonMatrix!.isNotEmpty) {
        _matchResult = InvoiceBlMatcherService.buildMatchResultFromSession(session);
      }
      _activeViewMode = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.idocASessionRestoredInspection(session.sessionCode)),
    );
  }

  void _cloneSession(InvoiceBLMatchSessionModel session) {
    setState(() {
      _activeFileId = session.importFileId;
      _ctrls.showPackingList = session.packingListData != null;
      _activeSessionId = null;
      _activeSessionCode = null;
      if (session.comparisonMatrix != null && session.comparisonMatrix!.isNotEmpty) {
        _matchResult = InvoiceBlMatcherService.cloneSessionToMatchResult(session);
      }
      _activeViewMode = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.idocASessionDataClonedAsDraft(session.sessionCode)),
    );
  }

  Future<void> _deleteSession(InvoiceBLMatchSessionModel session) async {
    await InvoiceBlMatcherService.confirmAndDeleteSession(context, ref, session);
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final sessions = ref.watch(invoiceBLMatchSessionsProvider).valueOrNull ?? [];
    final l = context.l10n;

    final carrierCode = _matchResult?['bl_data']?['carrier_name']?.toString() ??
        _matchResult?['bl_data']?['scac_code']?.toString();

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InvoiceBlMatcherToolbar(
              activeViewMode: _activeViewMode,
              onViewModeChanged: (mode) {
                setState(() => _activeViewMode = mode);
                if (mode == 1) {
                  ref.read(invoiceBLMatchSessionsProvider.notifier).fetchSessions(importFileId: _activeFileId);
                }
              },
              sessionCount: sessions.length,
              importFiles: importFiles,
              activeFileId: _activeFileId,
              activeSessionCode: _activeSessionCode,
              carrierCode: carrierCode,
              sensitivity: _sensitivity,
              onSensitivityChanged: (val) => setState(() => _sensitivity = val),
              onFileSelected: (val) {
                setState(() => _activeFileId = val);
                if (widget.onImportFileChanged != null && val != null) {
                  widget.onImportFileChanged!(val);
                }
              },
            ),
            const SizedBox(height: 16),

            if (_activeViewMode == 0) ...[
              InvoiceBlMatcherIngestionSection(
                invoiceTextCtrl: _ctrls.invoiceTextCtrl,
                blTextCtrl: _ctrls.blTextCtrl,
                packingTextCtrl: _ctrls.packingTextCtrl,
                invoiceFileName: _ctrls.invoiceFileName,
                blFileName: _ctrls.blFileName,
                packingFileName: _ctrls.packingFileName,
                showPackingList: _ctrls.showPackingList,
                onAddPackingList: () => setState(() => _ctrls.showPackingList = true),
                onRemovePackingList: () {
                  setState(() {
                    _ctrls.showPackingList = false;
                    _ctrls.packingFileName = null;
                    _ctrls.packingFileBytes = null;
                    _ctrls.packingTextCtrl.clear();
                  });
                },
                onPickFile: _pickFile,
              ),
              const SizedBox(height: 16),

              InvoiceBlMatcherActionsBar(
                isLoading: _isLoading,
                isSavingDraft: _isSavingDraft,
                activeFileId: _activeFileId,
                onRunMatch: _runCrossMatching,
                onLoadSample: _loadSampleData,
                onReset: _resetAll,
                onSaveDraft: () => _saveSession(isDraft: true),
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          l.invoiceBlMatcherAnalyzingProgress,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_matchResult != null) ...[
                InvoiceBlMatcherDiscrepancyBanner(
                  matchResult: _matchResult!,
                ),
                InvoiceBlMatcherSummaryCard(
                  matchResult: _matchResult!,
                  showPackingList: _ctrls.showPackingList,
                ),
                const SizedBox(height: 16),
                InvoiceBlMatcherTable(
                  matrix: (_matchResult!['comparison_matrix'] as List<dynamic>?) ?? [],
                  activeFileId: _activeFileId,
                ),
                const SizedBox(height: 24),
                InvoiceBlMatcherFooterBar(
                  activeFileId: _activeFileId,
                  matchResult: _matchResult,
                  isSavingDraft: _isSavingDraft,
                  isSyncing: _isSyncing,
                  onSaveDraft: () => _saveSession(isDraft: true),
                  onApproveAndSync: () => _saveSession(isDraft: false),
                ),
              ],
            ] else ...[
              InvoiceBlMatcherSessionsView(
                importFiles: importFiles,
                activeFileId: _activeFileId,
                activeSessionId: _activeSessionId,
                onNewSession: () => setState(() {
                  _activeViewMode = 0;
                  _activeSessionId = null;
                  _activeSessionCode = null;
                }),
                onLoadSession: _loadSessionIntoMatcher,
                onCloneSession: _cloneSession,
                onDeleteSession: _deleteSession,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
