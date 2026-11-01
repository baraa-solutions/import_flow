import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../financial_ui.dart';

class EstimatedBudgetHeader extends ConsumerWidget {
  final bool isMobile;
  final int? selectedImportFileId;
  final TextEditingController titleController;
  final bool isLoadingPrefill;
  final VoidCallback onSearchAndClone;
  final ValueChanged<int?> onImportFileSelected;

  const EstimatedBudgetHeader({
    super.key,
    required this.isMobile,
    required this.selectedImportFileId,
    required this.titleController,
    required this.isLoadingPrefill,
    required this.onSearchAndClone,
    required this.onImportFileSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Clone Button
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l.importBudgetSetupTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.charcoal,
                          ),
                        ),
                      ),
                      if (isLoadingPrefill) const AppLoadingState.inline(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FinancialUi.fit(AppButton(
                    key: const Key('searchAndCloneBudgetBtn'),
                    label: l.searchAndCloneBudgetBtn,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    icon: Icons.copy_all,
                    onPressed: onSearchAndClone,
                  )),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            l.importBudgetSetupTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.charcoal,
                            ),
                          ),
                        ),
                        if (isLoadingPrefill) ...[
                          const SizedBox(width: 12),
                          const AppLoadingState.inline(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FinancialUi.fit(AppButton(
                    key: const Key('searchAndCloneBudgetBtn'),
                    label: l.searchAndCloneBudgetBtn,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    icon: Icons.copy_all,
                    onPressed: onSearchAndClone,
                  )),
                ],
              ),
        Divider(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        const SizedBox(height: 10),

        // Row 1: Import File & Title
        if (isMobile) ...[
          SearchableDropdownField<int?>(
            value: selectedImportFileId,
            labelText: '${l.importFile} *',
            searchHintText: l.search,
            items: [
              SearchableDropdownItem<int?>(
                value: null,
                label: '-- ${l.notLinked} --',
              ),
              ...(ref.watch(importFilesProvider).valueOrNull ?? []).map((f) =>
                  SearchableDropdownItem<int?>(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode} - ${f.companyName}',
                    subtitle: f.companyName,
                  )),
            ],
            onChanged: onImportFileSelected,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: '${l.budgetTitleLabel} *',
              border: const OutlineInputBorder(),
              fillColor:
                  isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
              filled: isDark,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l.requiredField : null,
          ),
        ] else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SearchableDropdownField<int?>(
                  value: selectedImportFileId,
                  labelText: '${l.importFile} *',
                  searchHintText: l.search,
                  items: [
                    SearchableDropdownItem<int?>(
                      value: null,
                      label: '-- ${l.notLinked} --',
                    ),
                    ...(ref.watch(importFilesProvider).valueOrNull ?? []).map(
                        (f) => SearchableDropdownItem<int?>(
                              value: f.importFileId,
                              label:
                                  '${f.primaryNameWithCode} - ${f.companyName}',
                              subtitle: f.companyName,
                            )),
                  ],
                  onChanged: onImportFileSelected,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: '${l.budgetTitleLabel} *',
                    border: const OutlineInputBorder(),
                    fillColor:
                        isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                    filled: isDark,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.requiredField : null,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
