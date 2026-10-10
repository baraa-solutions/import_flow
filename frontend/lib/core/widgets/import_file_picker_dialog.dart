import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/import_files/models/import_file_model.dart';
import '../../features/import_files/providers/import_files_provider.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'buttons/app_button.dart';
import 'searchable_dropdown_field.dart';

/// FEX-T21: Shared Import File Picker Dialog.
/// Allows the user to select an active Import File from `importFilesProvider`.
Future<ImportFileModel?> showImportFilePickerDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  bool Function(ImportFileModel f)? where,
  int? excludeId,
}) async {
  final l = context.l10n;

  return showDialog<ImportFileModel>(
    context: context,
    builder: (ctx) {
      return Consumer(
        builder: (dialogCtx, refWatch, _) {
          final filesAsync = refWatch.watch(importFilesProvider);

          return filesAsync.when(
            loading: () => AlertDialog(
              title: Text(title),
              content: const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              actions: [
                AppButton(
                  label: l.cancel,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => Navigator.pop(ctx, null),
                ),
              ],
            ),
            error: (err, _) => AlertDialog(
              title: Text(title),
              content: Text(
                '${l.error}: $err',
                style: const TextStyle(color: AppTheme.crimson),
              ),
              actions: [
                AppButton(
                  label: l.cancel,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => Navigator.pop(ctx, null),
                ),
              ],
            ),
            data: (allFiles) {
              final candidateFiles = allFiles.where((f) {
                if (excludeId != null && f.importFileId == excludeId) return false;
                if (where != null) return where(f);
                return f.status != 'Closed' && f.status != 'Archived' && f.status != 'Cancelled';
              }).toList();

              if (candidateFiles.isEmpty) {
                return AlertDialog(
                  title: Text(title),
                  content: Text(
                    l.importFilePickerNoFilesFound,
                    style: TextStyle(color: AppTheme.textSecondaryOf(ctx)),
                  ),
                  actions: [
                    AppButton(
                      label: l.cancel,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: () => Navigator.pop(ctx, null),
                    ),
                  ],
                );
              }

              return _PickerContent(
                title: title,
                candidateFiles: candidateFiles,
                onSelected: (picked) => Navigator.pop(ctx, picked),
                onCancel: () => Navigator.pop(ctx, null),
              );
            },
          );
        },
      );
    },
  );
}

class _PickerContent extends StatefulWidget {
  final String title;
  final List<ImportFileModel> candidateFiles;
  final ValueChanged<ImportFileModel> onSelected;
  final VoidCallback onCancel;

  const _PickerContent({
    required this.title,
    required this.candidateFiles,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  State<_PickerContent> createState() => _PickerContentState();
}

class _PickerContentState extends State<_PickerContent> {
  int? selectedId;
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dropdownItems = widget.candidateFiles.map((f) {
      final label = '${f.primaryNameWithCode} — ${f.supplierName}';
      return SearchableDropdownItem<int>(
        value: f.importFileId,
        label: label,
        searchValue: '${f.primaryNameWithCode} ${f.supplierName} ${f.importFileCode}',
      );
    }).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width - 48).clamp(320.0, 520.0),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchableDropdownField<int>(
                key: const Key('importFilePickerDropdown'),
                labelText: l.importFilePickerTitle,
                hintText: l.importFilePickerSelectPrompt,
                value: selectedId,
                items: dropdownItems,
                isRequired: true,
                validator: (val) => val == null ? l.importFilePickerSelectPrompt : null,
                onChanged: (val) {
                  setState(() {
                    selectedId = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l.cancel,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: widget.onCancel,
        ),
        AppButton(
          key: const Key('importFilePickerContinueBtn'),
          label: l.importFilePickerContinue,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: selectedId == null
              ? null
              : () {
                  if (!formKey.currentState!.validate()) return;
                  final picked = widget.candidateFiles.firstWhere((f) => f.importFileId == selectedId);
                  widget.onSelected(picked);
                },
        ),
      ],
    );
  }
}
