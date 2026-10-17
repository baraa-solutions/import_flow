import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/import_files/models/import_file_model.dart';
import '../../features/import_files/providers/import_files_provider.dart';
import '../localization/app_localizations.dart';
import '../network/api_error.dart';
import '../theme/app_theme.dart';
import 'buttons/app_button.dart';
import 'searchable_dropdown_field.dart';

/// 📂 Shared Import-File Picker Dialog (FEX-T21).
///
/// Provides a unified, accessible modal dialog to select an [ImportFileModel]
/// across the ERP (e.g. customs clearance hub, sampling, inland transport, file closure).
///
/// Returns the chosen [ImportFileModel], or `null` if the user cancels or closes the dialog.
Future<ImportFileModel?> showImportFilePickerDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  String? message,
  bool Function(ImportFileModel f)? where,
  int? excludeId,
}) {
  return showDialog<ImportFileModel>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => ImportFilePickerDialog(
      title: title,
      message: message,
      where: where,
      excludeId: excludeId,
    ),
  );
}

/// Modal dialog widget that queries [importFilesProvider] and prompts
/// the user to select an active file via a searchable dropdown.
class ImportFilePickerDialog extends ConsumerStatefulWidget {
  final String title;
  final String? message;
  final bool Function(ImportFileModel f)? where;
  final int? excludeId;

  const ImportFilePickerDialog({
    super.key,
    required this.title,
    this.message,
    this.where,
    this.excludeId,
  });

  /// Static helper equivalent to [showImportFilePickerDialog].
  static Future<ImportFileModel?> show(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    String? message,
    bool Function(ImportFileModel f)? where,
    int? excludeId,
  }) =>
      showImportFilePickerDialog(
        context,
        ref,
        title: title,
        message: message,
        where: where,
        excludeId: excludeId,
      );

  @override
  ConsumerState<ImportFilePickerDialog> createState() => _ImportFilePickerDialogState();
}

class _ImportFilePickerDialogState extends ConsumerState<ImportFilePickerDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedFileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(importFilesProvider);
      if (current.valueOrNull == null && !current.isLoading) {
        try {
          ref.read(importFilesProvider.notifier).fetchImportFiles();
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asyncFiles = ref.watch(importFilesProvider);

    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = math.min(mediaQuery.size.width - 32, 540.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.surfaceOf(context)
            : Colors.white,
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Header ───────────────────────────────────────────────
              _buildHeader(context, l),
              Divider(height: 1, thickness: 1, color: AppTheme.borderOf(context)),

              // ── 2. Body ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 16),
                child: _buildBody(context, l, asyncFiles),
              ),

              // ── 3. Footer ───────────────────────────────────────────────
              Divider(height: 1, thickness: 1, color: AppTheme.borderOf(context)),
              _buildFooter(context, l, asyncFiles),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobaltLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: AppTheme.cobalt,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.message != null && widget.message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.message!.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textMutedOf(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            splashRadius: 18,
            tooltip: l.closeBtn,
            color: AppTheme.textMutedOf(context),
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l,
    AsyncValue<List<ImportFileModel>> asyncFiles,
  ) {
    if (asyncFiles.isLoading && !asyncFiles.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (asyncFiles.hasError && !asyncFiles.hasValue) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 40),
            const SizedBox(height: 12),
            Text(
              ApiError.message(asyncFiles.error, fallback: l.genericErrorMessage),
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: l.tableRetry,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              icon: Icons.refresh_rounded,
              onPressed: () => ref.read(importFilesProvider.notifier).fetchImportFiles(),
            ),
          ],
        ),
      );
    }

    final allFiles = asyncFiles.valueOrNull ?? [];
    final filteredFiles = _filterFiles(allFiles);

    if (filteredFiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppTheme.cobalt, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.importFilePickerNoFilesFound,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: SearchableDropdownField<int>(
        key: const Key('importFilePickerDropdown'),
        value: _selectedFileId,
        labelText: l.importFilePickerSelectFile,
        searchHintText: l.importFilePickerSearchHint,
        isRequired: true,
        items: filteredFiles.map((f) {
          final supplier = f.supplierName.trim();
          final label = supplier.isNotEmpty
              ? '${f.primaryNameWithCode} — $supplier'
              : f.primaryNameWithCode;
          return SearchableDropdownItem<int>(
            value: f.importFileId,
            label: label,
            searchValue:
                '${f.importFileCode} ${f.customFileNumber ?? ''} ${f.supplierName} ${f.companyName}',
            subtitle: f.companyName.trim().isNotEmpty ? f.companyName.trim() : null,
          );
        }).toList(),
        onChanged: (id) {
          setState(() {
            _selectedFileId = id;
          });
        },
        validator: (val) {
          if (val == null) {
            return l.importFilePickerFileRequired;
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AppLocalizations l,
    AsyncValue<List<ImportFileModel>> asyncFiles,
  ) {
    final allFiles = asyncFiles.valueOrNull ?? [];
    final filteredFiles = _filterFiles(allFiles);
    final hasFiles = filteredFiles.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.surfaceAltOf(context)
            : const Color(0xFFF8FAFC),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          AppButton(
            label: l.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(null),
          ),
          const Spacer(),
          if (hasFiles)
            AppButton(
              key: const Key('importFilePickerContinueBtn'),
              label: l.importFilePickerContinue,
              variant: AppButtonVariant.primary,
              onPressed: _selectedFileId == null
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        final picked = filteredFiles.firstWhere(
                          (f) => f.importFileId == _selectedFileId,
                        );
                        Navigator.of(context).pop(picked);
                      }
                    },
            ),
        ],
      ),
    );
  }

  List<ImportFileModel> _filterFiles(List<ImportFileModel> files) {
    const closedStatuses = {'closed', 'archived'};
    return files.where((f) {
      if (widget.excludeId != null && f.importFileId == widget.excludeId) {
        return false;
      }
      if (widget.where != null) {
        return widget.where!(f);
      }
      // Default: active files (isActive == true and status is neither 'Closed' nor 'Archived')
      return f.isActive && !closedStatuses.contains(f.status.trim().toLowerCase());
    }).toList();
  }
}
