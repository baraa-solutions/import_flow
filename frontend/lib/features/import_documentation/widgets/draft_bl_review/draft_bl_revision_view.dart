import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';

/// Stage 2 View: Revision Report & Carrier Correction Request Letter.
/// Lists identified discrepancies and provides a ready-to-dispatch amendment letter for the shipping line.
class DraftBlRevisionView extends StatelessWidget {
  final int? selectedImportFileId;
  final List<dynamic> importFiles;
  final ValueChanged<int?> onSelectImportFile;
  final List<DraftBLChecklistItemModel> checklist;
  final String? correctionRequestLetter;
  final VoidCallback onProceedToVersionHistory;
  final VoidCallback onBackToSelectFile;

  const DraftBlRevisionView({
    super.key,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onSelectImportFile,
    required this.checklist,
    this.correctionRequestLetter,
    required this.onProceedToVersionHistory,
    required this.onBackToSelectFile,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final incorrectItems = checklist.where((c) => c.status == 'Incorrect').toList();
    final letter = correctionRequestLetter ?? l.draftBlNoLetterGeneratedYet;

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
                        l.draftBlSelectFileToViewRevision,
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
            // Revision Discrepancies Card
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
                            const Icon(Icons.assignment_late, color: AppTheme.orange, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              l.draftBlRevisionReportTitle,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        AppButton(
                          label: l.draftBlProceedToVersionHistory,
                          icon: Icons.history,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          onPressed: onProceedToVersionHistory,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.draftBlRevisionReportSub,
                      style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13),
                    ),
                    const Divider(height: 20),

                    if (incorrectItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.emerald),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.emerald),
                            const SizedBox(width: 10),
                            Text(
                              l.draftBlNoAmendmentsNeeded,
                              style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(l.draftBlRevisionColItem)),
                            DataColumn(label: Text(l.draftBlRevisionColRequiredAction)),
                            DataColumn(label: Text(l.draftBlRevisionColResponsible)),
                            DataColumn(label: Text(l.draftBlRevisionColReason)),
                          ],
                          rows: incorrectItems.map((itm) {
                            final label = isAr ? itm.fieldLabelAr : itm.fieldLabelEn;
                            final corr = itm.requiredCorrection ?? 'Update to match system value (${itm.systemValue})';
                            final resp = itm.responsibleParty == 'Shipping Provider'
                                ? l.draftBlPartyShippingLine
                                : itm.responsibleParty == 'Supplier'
                                    ? l.draftBlPartySupplier
                                    : itm.responsibleParty == 'Importer'
                                        ? l.draftBlPartyImporter
                                        : l.draftBlPartyCustomsBroker;
                            final rsn = itm.reason == null
                                ? 'Mismatch with system master record'
                                : itm.displayReason(l);
                            final rowSummary = [label, corr, resp, rsn].join('\t');

                            return DataRow(cells: [
                              DataCell(CopyableTableCell(
                                value: label,
                                rowSummary: rowSummary,
                                child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                              )),
                              DataCell(CopyableTableCell(
                                value: corr,
                                rowSummary: rowSummary,
                                child: Text(corr, style: const TextStyle(color: AppTheme.crimson)),
                              )),
                              DataCell(CopyableTableCell(
                                value: resp,
                                rowSummary: rowSummary,
                                child: Text(resp),
                              )),
                              DataCell(CopyableTableCell(
                                value: rsn,
                                rowSummary: rowSummary,
                                child: Text(rsn),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Carrier Correction Request Letter Card
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
                            const Icon(Icons.mail, color: AppTheme.cobalt, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              l.draftBlCarrierRequestLetterTitle,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        AppButton(
                          label: l.draftBlCopyLetterButton,
                          icon: Icons.copy,
                          variant: AppButtonVariant.success,
                          size: AppButtonSize.small,
                          onPressed: () => CopyHelper.copy(context, letter),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAltOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderOf(context)),
                      ),
                      child: SelectableText(
                        letter,
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
