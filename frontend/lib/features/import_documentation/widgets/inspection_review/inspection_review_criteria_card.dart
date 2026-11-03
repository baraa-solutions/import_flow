import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';
import '../idoc_ui_b.dart';
import 'inspection_review_controllers.dart';
import 'inspection_review_header.dart';

class InspectionReviewCriteriaCard extends StatelessWidget {
  final InspectionReviewControllers controllers;
  final List<ImportFileModel> importFiles;
  final int? selectedImportFileId;
  final String inspType;
  final String inspAgency;
  final bool isLoading;
  final String? pickedFileName;
  final ValueChanged<int?> onSelectImportFile;
  final ValueChanged<String?> onSelectInspType;
  final ValueChanged<String?> onSelectInspAgency;
  final VoidCallback onRunComparison;
  final void Function(SmartUploadResult result) onSmartUploadExtracted;
  final VoidCallback onExtractOcr;

  const InspectionReviewCriteriaCard({
    super.key,
    required this.controllers,
    required this.importFiles,
    required this.selectedImportFileId,
    required this.inspType,
    required this.inspAgency,
    required this.isLoading,
    required this.pickedFileName,
    required this.onSelectImportFile,
    required this.onSelectInspType,
    required this.onSelectInspAgency,
    required this.onRunComparison,
    required this.onSmartUploadExtracted,
    required this.onExtractOcr,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
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
                Text(
                  l10n.inspDraftInputHeader,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IdocBUi.fit(
                  AppButton(
                    label: l10n.runInspectionComparisonBtn,
                    onPressed: (isLoading || selectedImportFileId == null) ? null : onRunComparison,
                    variant: AppButtonVariant.success,
                    icon: Icons.compare_arrows,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Mandatory Import File Selector Row
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SearchableDropdownField<int>(
                    value: selectedImportFileId,
                    labelText: l10n.linkedInspectionFileLabel,
                    searchHintText: l10n.linkedInspectionFileHint,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                            ))
                        .toList(),
                    onChanged: onSelectImportFile,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: inspType,
                    labelText: l10n.inspectionCertTypeLabel,
                    searchHintText: l10n.inspectionCertTypeHint,
                    items: InspectionReviewHeader.certTypeOptions(l10n),
                    onChanged: onSelectInspType,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: inspAgency,
                    labelText: l10n.inspectionAgencyLabel,
                    searchHintText: l10n.inspectionAgencyHint,
                    items: InspectionReviewHeader.agencyOptions(l10n),
                    onChanged: onSelectInspAgency,
                  ),
                ),
              ],
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
                        '⚠️ ${l10n.pleaseSelectInspectionFileWarning}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.crimson,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers.certNumberCtrl,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.idocBFieldRequired : null,
                    decoration: InputDecoration(
                      labelText: l10n.certNumberFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers.authorityCtrl,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.idocBFieldRequired : null,
                    decoration: InputDecoration(
                      labelText: l10n.regulatoryAuthorityFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers.invoiceNoCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l10n.inspectedInvoiceNumberFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers.exporterCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.exporterShipperFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers.importerCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.importerApplicantFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers.specCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.standardSpecFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers.acidCtrl,
                    textDirection: TextDirection.ltr,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.idocBAcidRequired : null,
                    decoration: InputDecoration(
                      labelText: l10n.acidNumberFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers.originCountryCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.countryOfOriginFieldLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // File Picker & Smart Upload Row
            Row(
              children: [
                SmartUploadButton(
                  module: SmartUploadModule.inspectionCertificate,
                  label: l10n.smartUploadInspectionBtn,
                  onDataExtracted: onSmartUploadExtracted,
                ),
                if (pickedFileName != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle, color: AppTheme.emerald, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      pickedFileName!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textStrong),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.rawTextInspectionHeader,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                IdocBUi.fit(
                  AppButton(
                    label: l10n.smartExtractFromTextBtn,
                    onPressed: (isLoading || selectedImportFileId == null) ? null : onExtractOcr,
                    variant: AppButtonVariant.secondary,
                    icon: Icons.auto_awesome,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: controllers.rawTextCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.rawTextInspectionHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
