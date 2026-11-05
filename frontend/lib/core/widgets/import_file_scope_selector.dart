import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/import_files/providers/import_files_provider.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'searchable_dropdown_field.dart';
import 'states/app_empty_state.dart';

/// Import-file picker for screens whose data is scoped to one import file.
///
/// The screen keeps the selected id; nothing should be fetched until it is set.
class ImportFileScopeSelector extends ConsumerWidget {
  static const fieldKey = Key('importFileScopeSelector');

  final int? selectedImportFileId;
  final ValueChanged<int?> onChanged;

  const ImportFileScopeSelector({
    super.key,
    required this.selectedImportFileId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(importFilesProvider);
    final files = filesAsync.valueOrNull ?? const [];

    final items = files
        .map((file) => SearchableDropdownItem<int>(
              value: file.importFileId,
              label: file.primaryNameWithCode,
              subtitle: [file.supplierName, file.companyName].where((s) => s.isNotEmpty).join(' — '),
            ))
        .toList();

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.cobalt.withValues(alpha: 0.04),
      child: Row(
        children: [
          const Icon(Icons.folder_open, color: AppTheme.cobalt, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: SearchableDropdownField<int>(
              key: fieldKey,
              labelText: context.l10n.importFileScopeLabel,
              searchHintText: context.l10n.selectImportFileDropdownHint,
              value: files.any((f) => f.importFileId == selectedImportFileId) ? selectedImportFileId : null,
              items: items,
              onChanged: onChanged,
            ),
          ),
          if (filesAsync.isLoading) ...[
            const SizedBox(width: 10),
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }
}

/// Shown in place of file-scoped content until an import file is chosen.
class ImportFileRequiredState extends StatelessWidget {
  static const stateKey = Key('importFileRequiredState');

  const ImportFileRequiredState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      key: stateKey,
      icon: Icons.folder_open_outlined,
      message: l10n.importFileScopeRequired,
      subtitle: l10n.importFileScopeRequiredHint,
    );
  }
}
