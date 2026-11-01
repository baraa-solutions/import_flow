import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/import_documentation_model.dart';
import '../idoc_ui_b.dart';
import '../visual_draft_inspection_sheet.dart';

class InspectionReviewHeader extends StatelessWidget {
  final int? selectedImportFileId;
  final String inspType;
  final String inspAgency;
  final List<ImportFileModel> importFiles;
  final InspectionCertificateReviewModel? existingReview;
  final Map<String, dynamic>? activeDraftTemplate;
  final String? activeAcidNumber;
  final List<String> activeStandards;
  final ValueChanged<int?> onSelectImportFile;
  final ValueChanged<String?> onSelectInspType;
  final ValueChanged<String?> onSelectInspAgency;
  final VoidCallback onOpenPreview;
  final VoidCallback onNextStep;
  final VoidCallback onViewRegistry;
  final VoidCallback onRefreshDraft;

  const InspectionReviewHeader({
    super.key,
    required this.selectedImportFileId,
    required this.inspType,
    required this.inspAgency,
    required this.importFiles,
    required this.existingReview,
    required this.activeDraftTemplate,
    required this.activeAcidNumber,
    required this.activeStandards,
    required this.onSelectImportFile,
    required this.onSelectInspType,
    required this.onSelectInspAgency,
    required this.onOpenPreview,
    required this.onNextStep,
    required this.onViewRegistry,
    required this.onRefreshDraft,
  });

  static List<SearchableDropdownItem<String>> certTypeOptions(AppLocalizations l10n) => [
        SearchableDropdownItem(value: 'COC (Certificate of Conformity)', label: l10n.optInspectionCoc),
        SearchableDropdownItem(value: 'COA (Certificate of Analysis)', label: l10n.optInspectionCoa),
        SearchableDropdownItem(value: 'VOC (Verification of Conformity)', label: l10n.optInspectionVoc),
        SearchableDropdownItem(value: 'PSI (Pre-Shipment Inspection)', label: l10n.optInspectionPsi),
      ];

  static List<SearchableDropdownItem<String>> agencyOptions(AppLocalizations l10n) => [
        SearchableDropdownItem(value: 'SGS', label: l10n.inspectionBodySgsOption),
        SearchableDropdownItem(value: 'TÜV Rheinland', label: l10n.inspectionBodyTuvOption),
        SearchableDropdownItem(value: 'Bureau Veritas', label: l10n.inspectionBodyBvOption),
        SearchableDropdownItem(value: 'Intertek', label: l10n.inspectionBodyIntertekOption),
        const SearchableDropdownItem(value: 'Cotecna', label: 'Cotecna Inspection'),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existingReview != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.infoBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cobaltBorder, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.existingInspectionReviewBanner(
                              existingReview!.inspectionReviewCode,
                              existingReview!.status,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: AppTheme.charcoal,
                            ),
                          ),
                        ),
                        IdocBUi.fit(
                          AppButton(
                            label: l10n.inspectionRegistryBtn,
                            onPressed: onViewRegistry,
                            size: AppButtonSize.small,
                            icon: Icons.history,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    const Icon(Icons.verified, color: AppTheme.cobalt),
                    const SizedBox(width: 10),
                    Text(
                      l10n.inspRequirementsHeader,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SearchableDropdownField<int>(
                        value: selectedImportFileId,
                        labelText: l10n.selectInspectionFileLabel,
                        searchHintText: l10n.selectInspectionFileHint,
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
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        value: inspType,
                        labelText: l10n.inspectionCertTypeLabel,
                        searchHintText: l10n.inspectionCertTypeHint,
                        items: certTypeOptions(l10n),
                        onChanged: onSelectInspType,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        value: inspAgency,
                        labelText: l10n.inspectionAgencyLabel,
                        searchHintText: l10n.inspectionAgencyHint,
                        items: agencyOptions(l10n),
                        onChanged: onSelectInspAgency,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IdocBUi.fit(
                      AppButton(
                        label: l10n.openInspectionPreviewBtn,
                        onPressed: onOpenPreview,
                        variant: AppButtonVariant.success,
                        icon: Icons.bolt,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IdocBUi.fit(
                      AppButton(
                        label: l10n.nextInspectionInputBtn,
                        onPressed: onNextStep,
                        icon: Icons.arrow_forward,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (activeDraftTemplate != null) ...[
          const SizedBox(height: 16),
          VisualDraftInspectionSheet(
            templateData: activeDraftTemplate!,
            agency: inspAgency,
            certType: inspType,
            acidNumber: activeAcidNumber ?? '',
            standards: activeStandards,
            onRefresh: onRefreshDraft,
          ),
        ],
      ],
    );
  }
}
