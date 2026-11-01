import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';

/// Stage 3 View: Version Branching (v1, v2, v3, etc.).
/// Tracks version revisions of the draft B/L, locked field count, and current stage.
class DraftBlVersionBranchingView extends StatelessWidget {
  final int? selectedImportFileId;
  final List<dynamic> importFiles;
  final ValueChanged<int?> onSelectImportFile;
  final DraftBLReviewModel? activeSession;
  final DraftBLComparisonResultModel? comparisonResult;
  final VoidCallback onProceedToDualApproval;
  final VoidCallback onBackToSelectFile;

  const DraftBlVersionBranchingView({
    super.key,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onSelectImportFile,
    this.activeSession,
    this.comparisonResult,
    required this.onProceedToDualApproval,
    required this.onBackToSelectFile,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Column(
        children: [
          // Top File Selector
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SearchableDropdownField<int>(
                      value: selectedImportFileId,
                      labelText: l.draftBlSelectImportFileLabel,
                      searchHintText: l.searchFileOrCompanyHint,
                      items: importFiles
                          .map((f) => SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '${f.primaryNameWithCode} - ${f.companyName}',
                              ))
                          .toList(),
                      onChanged: onSelectImportFile,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (selectedImportFileId == null)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.folder_off, size: 48, color: AppTheme.orange),
                      const SizedBox(height: 12),
                      Text(
                        l.draftBlSelectFileToViewVersions,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: l.draftBlBackToSelectFile,
                        icon: Icons.arrow_back,
                        variant: AppButtonVariant.primary,
                        onPressed: onBackToSelectFile,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.alt_route, color: AppTheme.cobalt, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              l.draftBlVersionBranchingTitle,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        AppButton(
                          label: l.draftBlProceedToDualApproval,
                          icon: Icons.verified_user,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          onPressed: onProceedToDualApproval,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.draftBlVersionBranchingSub,
                      style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13),
                    ),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: AppTheme.cobalt),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.draftBlActiveVersionBanner(
                                activeSession?.version ?? 'v1',
                                activeSession?.stage ?? 'Stage 1: Review',
                                comparisonResult?.checklist.where((c) => c.isLocked).length ?? 0,
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
