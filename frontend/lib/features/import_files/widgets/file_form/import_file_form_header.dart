import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../models/import_file_model.dart';

/// 🚢 Modular Header Title Bar for [ImportFileFormDialog].
///
/// Features clean title rendering with import file reference and unsaved changes guard pop handler.
class ImportFileFormHeader extends StatelessWidget {
  final ImportFileModel? fileToEdit;
  final bool isDirty;
  final VoidCallback? onClose;

  const ImportFileFormHeader({
    super.key,
    required this.fileToEdit,
    required this.isDirty,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.folder, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileToEdit == null
                      ? l.addNewImportFile
                      : '${l.editImportFile}: ${fileToEdit!.displayName}${fileToEdit!.displayName != fileToEdit!.importFileCode ? " (${fileToEdit!.importFileCode})" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          tooltip: l.close,
          onPressed: onClose ?? () => UnsavedChangesGuard.maybePop(context, isDirty: isDirty),
        ),
      ],
    );
  }
}
