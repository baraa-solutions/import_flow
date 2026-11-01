import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';

/// Stage 4 View: Dual Approval Engine (Importer + Customs Broker).
/// Mandates dual digital sign-off from both parties before document certification.
class DraftBlDualApprovalView extends StatelessWidget {
  final int? selectedImportFileId;
  final List<dynamic> importFiles;
  final ValueChanged<int?> onSelectImportFile;
  final DraftBLReviewModel? activeSession;
  final DraftBLComparisonResultModel? comparisonResult;
  final Set<String> currentUserNames;
  final TextEditingController importerApproverCtrl;
  final TextEditingController importerNotesCtrl;
  final TextEditingController brokerApproverCtrl;
  final TextEditingController brokerNotesCtrl;
  final bool isLoading;
  final Future<void> Function() onApproveSingleStep;
  final Future<void> Function(String role, String action) onSubmitApproval;
  final VoidCallback onBackToSelectFile;

  const DraftBlDualApprovalView({
    super.key,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onSelectImportFile,
    this.activeSession,
    this.comparisonResult,
    required this.currentUserNames,
    required this.importerApproverCtrl,
    required this.importerNotesCtrl,
    required this.brokerApproverCtrl,
    required this.brokerNotesCtrl,
    required this.isLoading,
    required this.onApproveSingleStep,
    required this.onSubmitApproval,
    required this.onBackToSelectFile,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasBlocking = comparisonResult?.hasBlockingMismatch ?? false;
    final singleRole = draftBlSingleStepRole(activeSession, currentUserNames: currentUserNames);
    final reasons = comparisonResult == null
        ? <String>[]
        : displayBlockingReasons(l, comparisonResult!.blockingReasons, comparisonResult!.blockingReasonsCoded);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        l.draftBlSelectFileToCompleteApproval,
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
          else ...[
            if (hasBlocking)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimson),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block, color: AppTheme.crimson, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.draftBlApprovalBlockedTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reasons.join(' | '),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.severityForegroundOf(context, AppSeverity.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;

                final importerCard = Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: AppTheme.cobalt),
                            const SizedBox(width: 8),
                            Text(
                              l.draftBlImporterApprovalTitle,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              activeSession?.importerApprovalStatus == 'Approved' ? l.approved : l.pending,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: activeSession?.importerApprovalStatus == 'Approved'
                                    ? AppTheme.emerald
                                    : AppTheme.orange,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        TextFormField(
                          controller: importerApproverCtrl,
                          decoration: InputDecoration(
                            labelText: l.draftBlImporterApproverNameLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: importerNotesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: l.draftBlImporterNotesLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (singleRole == null || singleRole == 'importer')
                              Expanded(
                                child: AppButton(
                                  key: const Key('draftBlImporterApproveBtn'),
                                  label: l.draftBlApproveAndAcceptButton,
                                  icon: Icons.check,
                                  variant: AppButtonVariant.success,
                                  onPressed: (hasBlocking || isLoading)
                                      ? null
                                      : (singleRole == 'importer'
                                          ? onApproveSingleStep
                                          : () => onSubmitApproval('importer', 'Approved')),
                                ),
                              ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: l.draftBlRejectDraftButton,
                              icon: Icons.close,
                              variant: AppButtonVariant.danger,
                              onPressed: isLoading ? null : () => onSubmitApproval('importer', 'Rejected'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                final brokerCard = Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gavel, color: AppTheme.emerald),
                            const SizedBox(width: 8),
                            Text(
                              l.draftBlBrokerApprovalTitle,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              activeSession?.brokerApprovalStatus == 'Approved' ? l.approved : l.pending,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: activeSession?.brokerApprovalStatus == 'Approved'
                                    ? AppTheme.emerald
                                    : AppTheme.orange,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        TextFormField(
                          controller: brokerApproverCtrl,
                          decoration: InputDecoration(
                            labelText: l.draftBlBrokerApproverNameLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: brokerNotesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: l.draftBlBrokerNotesLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (singleRole == null || singleRole == 'customs_broker')
                              Expanded(
                                child: AppButton(
                                  key: const Key('draftBlBrokerApproveBtn'),
                                  label: l.draftBlBrokerApproveButton,
                                  icon: Icons.check,
                                  variant: AppButtonVariant.success,
                                  onPressed: (hasBlocking || isLoading)
                                      ? null
                                      : (singleRole == 'customs_broker'
                                          ? onApproveSingleStep
                                          : () => onSubmitApproval('customs_broker', 'Approved')),
                                ),
                              ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: l.draftBlRejectDraftButton,
                              icon: Icons.close,
                              variant: AppButtonVariant.danger,
                              onPressed: isLoading ? null : () => onSubmitApproval('customs_broker', 'Rejected'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      importerCard,
                      const SizedBox(height: 16),
                      brokerCard,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: importerCard),
                    const SizedBox(width: 16),
                    Expanded(child: brokerCard),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
