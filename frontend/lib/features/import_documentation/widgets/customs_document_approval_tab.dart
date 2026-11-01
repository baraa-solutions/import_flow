import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/docs_customs_approval_model.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../screens/central_docs_archive_screen.dart';
import 'document_approval/doc_approval_actions_bar.dart';
import 'document_approval/doc_approval_dialogs.dart';
import 'document_approval/doc_approval_documents_table.dart';
import 'document_approval/doc_approval_filter_bar.dart';
import 'document_approval/doc_approval_header.dart';
import 'document_approval/doc_approval_helpers.dart';
import 'document_approval/doc_approval_verification_card.dart';

class CustomsDocumentApprovalTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const CustomsDocumentApprovalTab({super.key, this.initialImportFileId});

  @override
  ConsumerState<CustomsDocumentApprovalTab> createState() => CustomsDocumentApprovalTabState();
}

class CustomsDocumentApprovalTabState extends ConsumerState<CustomsDocumentApprovalTab> {
  int? _selectedImportFileId;
  CrossDocumentMatrixResultModel? _matrixResult;
  bool _isRunningMatrixCheck = false;
  String _selectedStatusFilter = 'All';
  int _activeViewIndex = 0; // 0: Dual-Tier Sign-off & Audit, 1: Central Archive & Rectifications Hub

  static String getLocalizedDocType(String docType, AppLocalizations l) =>
      DocApprovalHelpers.getLocalizedDocType(docType, l);

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() => _refresh());
  }

  @override
  void didUpdateWidget(covariant CustomsDocumentApprovalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
        _matrixResult = null;
      });
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!ref.read(importFilesProvider).isLoading) {
      await ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
      setState(() => _selectedImportFileId = files.first.importFileId);
    }
    if (!ref.read(docsCustomsApprovalProvider).isLoading) {
      ref.read(docsCustomsApprovalProvider.notifier).fetchApprovals(
            importFileId: _selectedImportFileId,
            overallStatus: _selectedStatusFilter == 'All' ? null : _selectedStatusFilter,
          );
    }
    if (!ref.read(discrepancyTicketsProvider).isLoading) {
      ref.read(discrepancyTicketsProvider.notifier).fetchTickets(importFileId: _selectedImportFileId);
    }
  }

  Future<void> _handleRunMatrixCheck() async {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.customsApprovalSelectFileForMatrixWarning, severity: AppSeverity.warning),
      );
      return;
    }

    setState(() => _isRunningMatrixCheck = true);
    try {
      final res = await ref.read(docsCustomsApprovalProvider.notifier).runMatrixCheck(_selectedImportFileId!);
      if (!mounted) return;
      setState(() => _matrixResult = res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.customsApprovalMatrixCheckCompleted(
            DocApprovalHelpers.getLocalizedCompliance(res.overallCompliance, context.l10n),
          )),
          backgroundColor: res.overallCompliance == 'Fully Compliant' ? AppTheme.emerald : AppTheme.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.customsApprovalMatrixCheckFailed(ApiErrorText.of(context.l10n, e))),
          backgroundColor: AppTheme.crimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRunningMatrixCheck = false);
    }
  }

  Future<void> _handleAutoGenerate() async {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.customsApprovalSelectFileWarning, severity: AppSeverity.warning),
      );
      return;
    }

    try {
      await ref.read(docsCustomsApprovalProvider.notifier).autoGenerateChecklist(_selectedImportFileId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.customsApprovalStandardListGeneratedSuccess, severity: AppSeverity.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.customsApprovalGenerateFailed(ApiErrorText.of(context.l10n, e))),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  void openSearchAndCloneDialog([List<CustomsDocumentApprovalModel>? items]) {
    final available = items ?? (ref.read(docsCustomsApprovalProvider).valueOrNull ?? []);
    DocApprovalDialogs.openSearchAndClone(
      context,
      items: available,
      onSelectItem: (item) => DocApprovalDialogs.cloneApprovalItem(context, sourceItem: item, onCloned: () {}),
    );
  }

  void _showRaiseTicketDialog([CustomsDocumentApprovalModel? item, DiscrepancyRectificationTicketModel? initialTicket]) {
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.customsApprovalSelectFileForTicketWarning, severity: AppSeverity.warning),
      );
      return;
    }
    DocApprovalDialogs.showRaiseTicket(
      context,
      importFileId: _selectedImportFileId!,
      approvalItem: item,
      initialTicket: initialTicket,
    );
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final approvalsState = ref.watch(docsCustomsApprovalProvider);
    final ticketsState = ref.watch(discrepancyTicketsProvider);
    final tickets = ticketsState.valueOrNull ?? const [];

    return SelectionArea(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () => openSearchAndCloneDialog(),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              DocApprovalFilterBar(
                selectedImportFileId: _selectedImportFileId,
                importFiles: importFiles,
                onFileChanged: (val) {
                  setState(() {
                    _selectedImportFileId = val;
                    _matrixResult = null;
                  });
                  _refresh();
                },
                isRunningMatrixCheck: _isRunningMatrixCheck,
                onRunMatrixCheck: _handleRunMatrixCheck,
                onAutoGenerate: _handleAutoGenerate,
                onRaiseTicket: () => _showRaiseTicketDialog(),
                selectedStatusFilter: _selectedStatusFilter,
                onStatusFilterChanged: (val) {
                  setState(() => _selectedStatusFilter = val);
                  _refresh();
                },
              ),
              DocApprovalHeader(
                activeViewIndex: _activeViewIndex,
                onViewChanged: (idx) => setState(() => _activeViewIndex = idx),
              ),
              if (_activeViewIndex == 0 && _matrixResult != null)
                DocApprovalVerificationCard(matrixResult: _matrixResult!),
              if (_activeViewIndex == 1)
                Expanded(
                  child: CentralDocsArchiveScreen(
                    initialImportFileId: _selectedImportFileId,
                    isEmbedded: true,
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 950;
                        final leftCol = DocApprovalDocumentsTable(
                          approvalsState: approvalsState,
                          onRefresh: _refresh,
                          onCopyTsv: () => DocApprovalHelpers.copyApprovalsAsTsv(context, approvalsState.valueOrNull ?? []),
                          onExportExcel: () => DocApprovalHelpers.exportApprovalsToExcel(
                            context: context,
                            approvals: approvalsState.valueOrNull ?? [],
                            importFileId: _selectedImportFileId,
                          ),
                          onExportPdf: () => DocApprovalHelpers.exportApprovalsToPdf(
                            context: context,
                            approvals: approvalsState.valueOrNull ?? [],
                            importFileId: _selectedImportFileId,
                          ),
                          onCommercialReview: (item) => DocApprovalDialogs.showCommercialReview(
                            context,
                            item: item,
                            importFileId: _selectedImportFileId,
                          ),
                          onCustomsBrokerReview: (item) => DocApprovalDialogs.showCustomsBrokerReview(
                            context,
                            item: item,
                            importFileId: _selectedImportFileId,
                          ),
                          onCloneItem: (item) => DocApprovalDialogs.cloneApprovalItem(context, sourceItem: item, onCloned: () {}),
                        );

                        final rightCol = DocApprovalActionsBar(
                          ticketsState: ticketsState,
                          onCopyTsv: () => DocApprovalHelpers.copyTicketsAsTsv(context, tickets),
                          onExportExcel: () => DocApprovalHelpers.exportTicketsToExcel(
                            context: context,
                            tickets: tickets,
                            importFileId: _selectedImportFileId,
                          ),
                          onExportPdf: () => DocApprovalHelpers.exportTicketsToPdf(
                            context: context,
                            tickets: tickets,
                            importFileId: _selectedImportFileId,
                          ),
                          onRaiseTicket: () => _showRaiseTicketDialog(),
                          onCloneTicket: (ticket) => _showRaiseTicketDialog(null, ticket),
                          onResolveTicket: (ticket) => DocApprovalDialogs.showResolveTicket(
                            context,
                            ticket: ticket,
                            importFileId: _selectedImportFileId,
                          ),
                        );

                        if (isNarrow) {
                          return ListView(
                            children: [
                              SizedBox(height: 400, child: leftCol),
                              const SizedBox(height: 12),
                              SizedBox(height: 400, child: rightCol),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: leftCol),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: rightCol),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
