import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/models/import_file_model.dart';
import '../idoc_ui_b.dart';

class Declaration46HeaderCard extends StatelessWidget {
  final int? selectedImportFileId;
  final List<ImportFileModel> importFiles;
  final ValueChanged<int?> onImportFileSelected;
  final VoidCallback onOpenSearchAndClone;

  const Declaration46HeaderCard({
    super.key,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onImportFileSelected,
    required this.onOpenSearchAndClone,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l.customsDeclTabInitialForm,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
            ),
            AppButton(
              key: const Key('subtab0SearchAndCloneBtn'),
              label: l.searchAndCloneCustomsDeclBtn,
              onPressed: onOpenSearchAndClone,
              variant: AppButtonVariant.secondary,
              icon: Icons.copy_all,
            ),
          ],
        ),
        const SizedBox(height: 14),
        IdocBNotice(
          message: l.customsDeclInfoBanner,
          icon: Icons.verified_outlined,
          margin: const EdgeInsetsDirectional.only(bottom: 16),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationOf(context),
          child: SearchableDropdownField<int>(
            key: const Key('decl46FileDropdown'),
            labelText: l.customsDeclSelectFileLabel,
            hintText: l.customsDeclSearchFileHint,
            value: selectedImportFileId,
            isRequired: true,
            items: importFiles
                .map((f) => SearchableDropdownItem<int>(
                      value: f.importFileId,
                      label: '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName})',
                    ))
                .toList(),
            onChanged: onImportFileSelected,
          ),
        ),
      ],
    );
  }
}
