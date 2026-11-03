import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../idoc_ui.dart';

/// Action bar for selecting an Import File and applying extracted Commercial Invoice data.
class SmartExtractorInvoiceActionBar extends ConsumerWidget {
  final int? selectedImportFileId;
  final ValueChanged<int?> onFileChanged;
  final VoidCallback onApply;
  final bool isApplying;

  const SmartExtractorInvoiceActionBar({
    super.key,
    required this.selectedImportFileId,
    required this.onFileChanged,
    required this.onApply,
    required this.isApplying,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final importFilesAsync = ref.watch(importFilesProvider);

    return Card(
      elevation: 0,
      color: AppTheme.surfaceAltOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.link, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Text(
              l.smartExtractorApplySectionTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: importFilesAsync.when(
                data: (files) {
                  return SearchableDropdownField<int>(
                    labelText: l.smartExtractorSelectFileLabel,
                    hintText: l.smartExtractorSearchFileHint,
                    items: files
                        .map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label:
                                  '${f.primaryNameWithCode} - ${f.companyName}',
                            ))
                        .toList(),
                    value: selectedImportFileId,
                    onChanged: onFileChanged,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(l.smartExtractorFetchFilesError(e)),
              ),
            ),
            const SizedBox(width: 16),
            IdocUi.fit(AppButton(
              label: l.smartExtractorApplyInvoiceButton,
              icon: Icons.check_circle_outline,
              variant: AppButtonVariant.success,
              isLoading: isApplying,
              onPressed: isApplying ? null : onApply,
            )),
          ],
        ),
      ),
    );
  }
}

/// Action bar for applying extracted Bill of Lading data to active shipment files.
class SmartExtractorBLActionBar extends StatelessWidget {
  final VoidCallback onApply;
  final bool isApplying;

  const SmartExtractorBLActionBar({
    super.key,
    required this.onApply,
    required this.isApplying,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Card(
      elevation: 0,
      color: AppTheme.surfaceAltOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.directions_boat, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(
              l.smartExtractorApplyBlSectionTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IdocUi.fit(AppButton(
              label: l.smartExtractorApplyBlButton,
              icon: Icons.save_alt,
              variant: AppButtonVariant.primary,
              isLoading: isApplying,
              onPressed: isApplying ? null : onApply,
            )),
          ],
        ),
      ),
    );
  }
}
