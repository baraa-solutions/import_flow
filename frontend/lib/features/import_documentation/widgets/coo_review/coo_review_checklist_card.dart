import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../idoc_ui_b.dart';
import 'coo_review_actions_bar.dart';
import 'coo_review_controllers.dart';

class CooReviewChecklistCard extends StatelessWidget {
  final int? selectedImportFileId;
  final String certType;
  final List<dynamic> importFiles;
  final CooReviewControllers controllers;
  final String? pickedFileName;
  final bool isLoading;
  final bool isSavingDraft;
  final ValueChanged<int?> onFileChanged;
  final ValueChanged<String> onCertTypeChanged;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onRunComparison;
  final VoidCallback? onExtractFromOcrText;
  final ValueChanged<SmartUploadResult> onDataExtracted;

  const CooReviewChecklistCard({
    super.key,
    required this.selectedImportFileId,
    required this.certType,
    required this.importFiles,
    required this.controllers,
    required this.pickedFileName,
    required this.isLoading,
    required this.isSavingDraft,
    required this.onFileChanged,
    required this.onCertTypeChanged,
    required this.onSaveDraft,
    required this.onRunComparison,
    required this.onExtractFromOcrText,
    required this.onDataExtracted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.l10n.cooDraftInputTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                CooReviewInputActionsBar(
                  onSaveDraft: onSaveDraft,
                  onRunComparison: onRunComparison,
                  isSavingDraft: isSavingDraft,
                  isLoading: isLoading,
                ),
              ],
            ),
            const Divider(height: 24),
            // Mandatory Import File Selector
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final fileField = SearchableDropdownField<int>(
                  value: selectedImportFileId,
                  labelText: context.l10n.cooLinkedImportFileLabel,
                  searchHintText: context.l10n.cooSearchFileHint,
                  items: importFiles
                      .map((f) => SearchableDropdownItem<int>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} - ${f.companyName}',
                          ))
                      .toList(),
                  onChanged: onFileChanged,
                );

                final certTypeField = SearchableDropdownField<String>(
                  value: certType,
                  labelText: context.l10n.cooCertTypeLabel,
                  searchHintText: context.l10n.cooSelectCertTypeHint,
                  items: [
                    SearchableDropdownItem(value: 'EUR.1', label: context.l10n.cooCertTypeEur1),
                    SearchableDropdownItem(value: 'China Certificate of Origin (CCPIT)', label: context.l10n.cooCertTypeChina),
                    SearchableDropdownItem(value: 'Standard COO', label: context.l10n.cooCertTypeStandard),
                    SearchableDropdownItem(value: 'Form A / GSP', label: context.l10n.cooCertTypeFormA),
                    SearchableDropdownItem(value: 'Agadir Agreement', label: context.l10n.cooCertTypeAgadir),
                    SearchableDropdownItem(value: 'GAFTA', label: context.l10n.cooCertTypeGafta),
                  ],
                  onChanged: (v) {
                    if (v != null) onCertTypeChanged(v);
                  },
                );

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fileField,
                      const SizedBox(height: 12),
                      certTypeField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 4, child: fileField),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: certTypeField),
                  ],
                );
              },
            ),
            if (selectedImportFileId == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimsonBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.cooSelectFileWarning,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final certNum = TextFormField(
                  controller: controllers.certNumber,
                  decoration: InputDecoration(
                    labelText: context.l10n.cooDraftCertNumberLabel,
                    border: const OutlineInputBorder(),
                  ),
                );
                final originCountry = TextFormField(
                  controller: controllers.originCountry,
                  decoration: InputDecoration(
                    labelText: context.l10n.cooOriginCountryLabel,
                    border: const OutlineInputBorder(),
                  ),
                );
                final destCountry = TextFormField(
                  controller: controllers.destCountry,
                  decoration: InputDecoration(
                    labelText: context.l10n.cooDestinationCountryLabel,
                    border: const OutlineInputBorder(),
                  ),
                );

                if (isMobile) {
                  return Column(
                    children: [
                      certNum,
                      const SizedBox(height: 12),
                      originCountry,
                      const SizedBox(height: 12),
                      destCountry,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: certNum),
                    const SizedBox(width: 12),
                    Expanded(child: originCountry),
                    const SizedBox(width: 12),
                    Expanded(child: destCountry),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;
                final expField = TextFormField(
                  controller: controllers.exporter,
                  decoration: InputDecoration(
                    labelText: context.l10n.cooExporterNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                );
                final regIdField = TextFormField(
                  controller: controllers.exporterRegId,
                  decoration: InputDecoration(
                    labelText: context.l10n.cooExporterRegIdLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  ),
                );
                final impField = TextFormField(
                  controller: controllers.importer,
                  decoration: InputDecoration(
                    labelText: context.l10n.cooImporterNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                );
                final invField = TextFormField(
                  controller: controllers.invoiceNo,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: context.l10n.cooInvoiceNumberLabel,
                    border: const OutlineInputBorder(),
                  ),
                );

                if (isMobile) {
                  return Column(
                    children: [
                      expField,
                      const SizedBox(height: 12),
                      regIdField,
                      const SizedBox(height: 12),
                      impField,
                      const SizedBox(height: 12),
                      invField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: expField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: regIdField),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: impField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: invField),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // File Picker & Smart Upload Row
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SmartUploadButton(
                  module: SmartUploadModule.cooCertificate,
                  label: context.l10n.cooSmartUploadButtonLabel,
                  onDataExtracted: onDataExtracted,
                ),
                if (pickedFileName != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.emerald, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        pickedFileName!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textStrong),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.l10n.cooRawTextSectionTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                IdocBUi.fit(
                  AppButton(
                    label: context.l10n.cooSmartExtractFromTextButton,
                    onPressed: onExtractFromOcrText,
                    variant: AppButtonVariant.secondary,
                    icon: Icons.auto_awesome,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: controllers.rawText,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.l10n.cooRawTextHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
