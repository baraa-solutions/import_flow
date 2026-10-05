import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/file_closure_model.dart';
import '../providers/file_closure_provider.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';

/// Number of the 5 mandatory checklist items that passed.
int closureCompletedCount(ClosureChecklistModel c) =>
    (c.docsVerified ? 1 : 0) +
    (c.customsCleared ? 1 : 0) +
    (c.warehouseReceived ? 1 : 0) +
    (c.landedCostSettled ? 1 : 0) +
    (c.tasksClosed ? 1 : 0);

/// Closure form (draft or certify). The checklist is evaluated by the SERVER (precheck of
/// the selected file) and shown read-only: the user cannot tick a box to make the file
/// look closable, and the flags sent are the server's own (plan FC-01 / FE-07).
class FileClosureFormDialog extends ConsumerStatefulWidget {
  final ImportFileClosureModel? initialRecord;
  final bool isCloneDraft;

  const FileClosureFormDialog({
    super.key,
    this.initialRecord,
    this.isCloneDraft = false,
  });

  @override
  ConsumerState<FileClosureFormDialog> createState() => _FileClosureFormDialogState();
}

class _FileClosureFormDialogState extends ConsumerState<FileClosureFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;

  ClosurePrecheckResponseModel? _precheck;
  bool _precheckLoading = false;
  Object? _precheckError;

  late final TextEditingController _auditorCtrl;
  late final TextEditingController _vaultCtrl;
  late final TextEditingController _notesCtrl;

  bool _isLoading = false;
  bool _isDraftSaving = false;

  ClosureChecklistModel get _checklist => _precheck != null
      ? ClosureChecklistModel.fromStatusMap(_precheck!.checklistStatus)
      : (widget.initialRecord?.closureChecklist ?? ClosureChecklistModel());

  @override
  void initState() {
    super.initState();
    final init = widget.initialRecord;
    _selectedImportFileId = init?.importFileId;
    final username = ref.read(authProvider).user?.username ?? '';
    _auditorCtrl = TextEditingController(text: (init?.auditorName.isNotEmpty ?? false) ? init!.auditorName : username);
    _vaultCtrl = TextEditingController(text: init?.archiveLocation ?? '');
    _notesCtrl = TextEditingController(text: init?.archivalNotes ?? '');

    Future.microtask(() {
      if (!mounted) return;
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      if (_selectedImportFileId != null) _loadPrecheck(_selectedImportFileId!);
    });
  }

  @override
  void dispose() {
    _auditorCtrl.dispose();
    _vaultCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrecheck(int fileId) async {
    setState(() {
      _precheckLoading = true;
      _precheckError = null;
      _precheck = null;
    });
    try {
      final pre = await ref.read(fileClosureProvider.notifier).fetchClosurePrecheck(fileId);
      if (!mounted || _selectedImportFileId != fileId) return;
      setState(() {
        _precheck = pre;
        _precheckLoading = false;
      });
    } catch (e) {
      if (!mounted || _selectedImportFileId != fileId) return;
      setState(() {
        _precheckError = e;
        _precheckLoading = false;
      });
    }
  }

  void _onFileSelected(int? fileId) {
    setState(() => _selectedImportFileId = fileId);
    if (fileId == null) return;

    final existingClosures = ref.read(fileClosureProvider).valueOrNull ?? [];
    final match = existingClosures.where((c) => c.importFileId == fileId).firstOrNull;
    if (match != null) {
      setState(() {
        if (match.auditorName.isNotEmpty) _auditorCtrl.text = match.auditorName;
        if (match.archiveLocation.isNotEmpty) _vaultCtrl.text = match.archiveLocation;
        if (match.archivalNotes != null) _notesCtrl.text = match.archivalNotes!;
      });
    }
    _loadPrecheck(fileId);
  }

  Future<void> _submitClosure({required bool isDraft}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    if (!isDraft && !(_precheck?.canClose ?? false)) {
      messenger.showSnackBar(SnackBar(
        content: Text(_precheck == null ? l10n.closureFormPrecheckMissing : l10n.fileClosureChecklistIncompleteWarning),
        backgroundColor: AppTheme.crimson,
      ));
      return;
    }

    setState(() {
      if (isDraft) {
        _isDraftSaving = true;
      } else {
        _isLoading = true;
      }
    });

    final nav = Navigator.of(context);
    try {
      final checklist = _checklist;
      final payload = {
        'import_file_id': _selectedImportFileId,
        // The server's own evaluation, for the record: it is never trusted as the gate.
        'closure_checklist': checklist.toJson(),
        'auditor_name': _auditorCtrl.text.trim(),
        'archive_location': _vaultCtrl.text.trim(),
        'archival_notes': _notesCtrl.text.trim(),
        'is_draft': isDraft,
      };

      await ref.read(fileClosureProvider.notifier).closeImportFile(payload);

      final int completedCount = closureCompletedCount(checklist);
      final double progressPct = (completedCount / 5.0) * 100.0;

      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isDraft
                ? l10n.fileClosureDraftSavedSuccess(progressPct.toStringAsFixed(0), completedCount)
                : l10n.fileClosureCertifiedSuccess,
          ),
          backgroundColor: isDraft ? AppTheme.cobalt : AppTheme.emerald,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiErrorText.of(l10n, e)), backgroundColor: AppTheme.crimson));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDraftSaving = false;
        });
      }
    }
  }

  Widget _checkRow(String label, bool ok) {
    final color = AppTheme.severityForegroundOf(context, ok ? AppSeverity.success : AppSeverity.danger);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: ok ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }

  Widget _copyField(TextEditingController ctrl, String label, {String? Function(String?)? validator, int maxLines = 1}) {
    final l10n = context.l10n;
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: l10n.fileClosureCopyFieldTooltip,
          onPressed: () => CopyHelper.copy(context, ctrl.text),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 32).clamp(320.0, 700.0);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final busy = _isLoading || _isDraftSaving;

    final checklist = _checklist;
    final int completedCount = closureCompletedCount(checklist);
    final double progressPct = (completedCount / 5.0) * 100.0;
    final bool isFullyComplete = completedCount == 5;
    final Color progressColor = isFullyComplete
        ? AppTheme.emerald
        : (completedCount >= 3 ? AppTheme.cobalt : (completedCount >= 1 ? AppTheme.orange : AppTheme.charcoal));

    final titleText = widget.isCloneDraft
        ? '${l10n.fileClosureDialogTitle} (${l10n.closureFormClonedSuffix})'
        : l10n.fileClosureDialogTitle;

    return AlertDialog(
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.down,
      titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 8),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
      title: OpsSectionHeader(
        title: titleText,
        icon: widget.isCloneDraft ? Icons.difference_outlined : Icons.inventory_2_outlined,
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SelectionArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchableDropdownField<int?>(
                    value: _selectedImportFileId,
                    labelText: l10n.fileClosureSelectImportFile,
                    searchHintText: l10n.fileClosureSelectImportFileHint,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int?>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                              subtitle: f.companyName,
                            ))
                        .toList(),
                    onChanged: _onFileSelected,
                    validator: (v) => v == null ? l10n.fileClosureSelectImportFileValidator : null,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: progressColor.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  Icon(isFullyComplete ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                      color: progressColor, size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      l10n.fileClosureChecklistCompletionLabel,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: progressColor, borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                '${progressPct.toStringAsFixed(0)}% ($completedCount/5)',
                                style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: completedCount / 5.0,
                            backgroundColor: AppTheme.borderOf(context),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                            minHeight: 7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(l10n.fileClosureSaveDraftTip, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(l10n.fileClosureMandatoryChecklistHeader,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                  const SizedBox(height: 2),
                  Text(l10n.closureFormServerChecklistNote, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                  const SizedBox(height: 6),
                  if (_selectedImportFileId == null)
                    Text(l10n.closureFormSelectFileFirst, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)))
                  else if (_precheckLoading)
                    const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
                  else if (_precheckError != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.closurePrecheckFailed(ApiErrorText.of(l10n, _precheckError)),
                            key: const Key('closureFormPrecheckError'),
                            style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                          ),
                        ),
                        AppButton(
                          key: const Key('closureFormRetryPrecheckBtn'),
                          label: l10n.closureRetryBtn,
                          icon: Icons.refresh,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: () => _loadPrecheck(_selectedImportFileId!),
                        ),
                      ],
                    )
                  else ...[
                    _checkRow(l10n.fileClosureCheck1Docs, checklist.docsVerified),
                    _checkRow(l10n.fileClosureCheck2Customs, checklist.customsCleared),
                    _checkRow(l10n.fileClosureCheck3Warehouse, checklist.warehouseReceived),
                    _checkRow(l10n.fileClosureCheck4LandedCost, checklist.landedCostSettled),
                    _checkRow(l10n.fileClosureCheck5Tasks, checklist.tasksClosed),
                    if (_precheck != null && _precheck!.blockingTexts(l10n).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (final t in _precheck!.blockingTexts(l10n))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('• $t', style: const TextStyle(fontSize: 11.5, color: AppTheme.crimson)),
                        ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  _copyField(
                    _auditorCtrl,
                    l10n.fileClosureAuditorNameLabel,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fileClosureAuditorNameValidator : null,
                  ),
                  const SizedBox(height: 8),
                  _copyField(_vaultCtrl, l10n.fileClosureVaultLocationLabel),
                  const SizedBox(height: 8),
                  _copyField(_notesCtrl, l10n.fileClosureArchivalNotesLabel, maxLines: 2),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.fileClosureLiveReloadBtn,
          variant: AppButtonVariant.ghost,
          icon: Icons.refresh,
          size: AppButtonSize.small,
          onPressed: () {
            ref.read(fileClosureProvider.notifier).fetchClosures();
            ref.read(importFilesProvider.notifier).fetchImportFiles();
            final id = _selectedImportFileId;
            if (id != null) _loadPrecheck(id);
          },
        ),
        AppButton(
          label: l10n.fileClosureResetFormBtn,
          variant: AppButtonVariant.ghost,
          icon: Icons.cleaning_services_outlined,
          size: AppButtonSize.small,
          onPressed: busy
              ? null
              : () => setState(() {
                    _notesCtrl.clear();
                    _auditorCtrl.clear();
                    _vaultCtrl.clear();
                  }),
        ),
        AppButton(
          label: l10n.fileClosureSaveDraftBtn,
          variant: AppButtonVariant.saveDraft,
          icon: Icons.save_outlined,
          size: AppButtonSize.small,
          isLoading: _isDraftSaving,
          onPressed: busy ? null : () => _submitClosure(isDraft: true),
        ),
        AppButton(
          label: l10n.cancel,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
        AppButton(
          key: const Key('closureFormCertifyBtn'),
          label: l10n.fileClosureCertifySubmitBtn,
          variant: AppButtonVariant.success,
          icon: Icons.archive_outlined,
          size: AppButtonSize.small,
          isLoading: _isLoading,
          onPressed: busy ? null : () => _submitClosure(isDraft: false),
        ),
      ],
    );
  }
}
