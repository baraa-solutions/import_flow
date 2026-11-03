import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';
import '../idoc_ui_b.dart';

/// Top header banner and shipment selector for Form 4 Request.
class BankForm4Header extends StatelessWidget {
  final bool isMobile;
  final bool isDark;
  final int? editingBankDocId;
  final String? editingBankDocCode;
  final int? selectedImportFileId;
  final List<ImportFileModel> importFiles;
  final VoidCallback onOpenSearchAndClone;
  final VoidCallback onCancelEdit;
  final ValueChanged<int?> onSelectImportFile;

  const BankForm4Header({
    super.key,
    required this.isMobile,
    required this.isDark,
    required this.editingBankDocId,
    required this.editingBankDocCode,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onOpenSearchAndClone,
    required this.onCancelEdit,
    required this.onSelectImportFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                context.l10n.form4RequestTab,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
            ),
            IdocBUi.fit(AppButton(
              key: const Key('subtab0SearchAndCloneBtn'),
              label: context.l10n.searchAndCloneBankForm4Btn,
              onPressed: onOpenSearchAndClone,
              variant: AppButtonVariant.secondary,
              icon: Icons.copy_all,
            )),
          ],
        ),
        const SizedBox(height: 14),

        if (editingBankDocId != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.orangeLight : AppTheme.warningBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.orange),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note, color: AppTheme.orange, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CopyableText(
                              context.l10n.bankForm4EditingBanner(editingBankDocCode ?? ''),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.orange : AppTheme.warningForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IdocBUi.fit(AppButton(
                          key: const Key('cancelForm4EditModeBtn'),
                          label: context.l10n.cancelEditNewForm4,
                          onPressed: onCancelEdit,
                          variant: AppButtonVariant.secondary,
                          icon: Icons.cancel,
                        )),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.edit_note, color: AppTheme.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CopyableText(
                          context.l10n.bankForm4EditingBanner(editingBankDocCode ?? ''),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.orange : AppTheme.warningForeground,
                          ),
                        ),
                      ),
                      IdocBUi.fit(AppButton(
                        key: const Key('cancelForm4EditModeBtn'),
                        label: context.l10n.cancelEditNewForm4,
                        onPressed: onCancelEdit,
                        variant: AppButtonVariant.secondary,
                        icon: Icons.cancel,
                      )),
                    ],
                  ),
          ),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationOf(context),
          child: SearchableDropdownField<int>(
            labelText: context.l10n.selectImportFileForm4Label,
            hintText: context.l10n.searchFileOrSupplierHint,
            value: selectedImportFileId,
            isRequired: true,
            items: importFiles
                .map((f) => SearchableDropdownItem<int>(
                      value: f.importFileId,
                      label: '${f.primaryNameWithCode} — ${f.supplierName} (${f.companyName})',
                    ))
                .toList(),
            onChanged: onSelectImportFile,
          ),
        ),
      ],
    );
  }
}
