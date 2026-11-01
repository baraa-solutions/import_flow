import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/import_documentation_provider.dart';
import '../idoc_ui_b.dart';
import '../visual_draft_coo_sheet.dart';
import 'coo_review_localizer.dart';

class CooReviewHeader extends ConsumerWidget {
  final int? selectedImportFileId;
  final String certType;
  final String originCountry;
  final Map<String, dynamic>? activeDraftTemplate;
  final String? activeAcidNumber;
  final String? activeExemptionNotes;
  final String? recommendationAlert;
  final bool isManualChoiceRequired;
  final List<String> allowedCertTypes;
  final List<dynamic> importFiles;
  final ValueChanged<int?> onFileChanged;
  final ValueChanged<String> onCertTypeChanged;
  final VoidCallback onRefresh;
  final VoidCallback onGenerateOfficialDraft;
  final VoidCallback onNextStep;
  final VoidCallback onGoToRegistry;

  const CooReviewHeader({
    super.key,
    required this.selectedImportFileId,
    required this.certType,
    required this.originCountry,
    required this.activeDraftTemplate,
    required this.activeAcidNumber,
    required this.activeExemptionNotes,
    required this.recommendationAlert,
    required this.isManualChoiceRequired,
    required this.allowedCertTypes,
    required this.importFiles,
    required this.onFileChanged,
    required this.onCertTypeChanged,
    required this.onRefresh,
    required this.onGenerateOfficialDraft,
    required this.onNextStep,
    required this.onGoToRegistry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existingReviews = ref.watch(cooReviewsProvider).valueOrNull ?? [];
    final existingReview = existingReviews
        .where((r) => r.importFileId == selectedImportFileId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dedicated COO Decision Engine Header Card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.charcoal, AppTheme.charcoal.withValues(alpha: 0.92)],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: AppTheme.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, color: AppTheme.darkHyperlink, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.cooDecisionEngineTitle,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.cooDecisionEngineSub,
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.cloudWhite),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedImportFileId != null)
                    IdocBUi.fit(
                      AppButton(
                        label: context.l10n.cooRecheckAgreementButton,
                        onPressed: onRefresh,
                        icon: Icons.refresh,
                      ),
                    ),
                ],
              ),
              if (selectedImportFileId != null) ...[
                const Divider(color: AppTheme.darkBorderLight, height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (originCountry.isNotEmpty || activeDraftTemplate?['country_of_origin'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBorder,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.darkBorderLight),
                        ),
                        child: CopyableText(
                          context.l10n.cooInvoiceOriginBadge(activeDraftTemplate?['country_of_origin'] ?? originCountry),
                          style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isManualChoiceRequired ? AppTheme.orange.withValues(alpha: 0.2) : AppTheme.emerald.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isManualChoiceRequired ? AppTheme.orange : AppTheme.emerald),
                      ),
                      child: CopyableText(
                        isManualChoiceRequired ? context.l10n.cooManualChoiceRequiredBadge : context.l10n.cooApprovedCertBadge(certType),
                        style: TextStyle(
                          color: isManualChoiceRequired ? AppTheme.orange : AppTheme.emerald,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (activeExemptionNotes != null && activeExemptionNotes!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.darkHyperlink.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.savings_outlined, color: AppTheme.darkHyperlink, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                CooReviewLocalizer.localizeExemption(context, activeExemptionNotes),
                                style: const TextStyle(color: AppTheme.darkHyperlink, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Recommendation & Status Card
        if (recommendationAlert != null && recommendationAlert!.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isManualChoiceRequired ? AppTheme.warningBackground : AppTheme.infoBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isManualChoiceRequired ? AppTheme.orange : AppTheme.cobaltBorder,
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isManualChoiceRequired ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: isManualChoiceRequired ? AppTheme.warningForeground : AppTheme.cobalt,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    CooReviewLocalizer.localizeAlert(context, recommendationAlert),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: isManualChoiceRequired ? AppTheme.warningForeground : AppTheme.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Certificate Type Selector Card
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
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  context.l10n.cooExistingReviewBanner(existingReview.cooReviewCode, existingReview.status),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IdocBUi.fit(
                          AppButton(
                            label: context.l10n.cooReviewRegistryButton,
                            onPressed: onGoToRegistry,
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
                    const Icon(Icons.flag, color: AppTheme.cobalt),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.cooGenerateDraftHeader,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 768;
                    final dropdownFile = SearchableDropdownField<int>(
                      value: selectedImportFileId,
                      labelText: context.l10n.cooSelectImportFileLabel,
                      searchHintText: context.l10n.cooSearchFileHint,
                      items: importFiles
                          .map((f) => SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '${f.primaryNameWithCode} - ${f.companyName}',
                              ))
                          .toList(),
                      onChanged: onFileChanged,
                    );

                    final dropdownType = SearchableDropdownField<String>(
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

                    final actionButtons = Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        IdocBUi.fit(
                          AppButton(
                            label: context.l10n.cooOpenVisualPreviewButton,
                            onPressed: onGenerateOfficialDraft,
                            variant: AppButtonVariant.success,
                            icon: Icons.bolt,
                          ),
                        ),
                        IdocBUi.fit(
                          AppButton(
                            label: context.l10n.cooNextDraftInputButton,
                            onPressed: onNextStep,
                            icon: Icons.arrow_forward,
                          ),
                        ),
                      ],
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dropdownFile,
                          const SizedBox(height: 14),
                          dropdownType,
                          const SizedBox(height: 16),
                          actionButtons,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 3, child: dropdownFile),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: dropdownType),
                        const SizedBox(width: 16),
                        actionButtons,
                      ],
                    );
                  },
                ),
                if (recommendationAlert != null && recommendationAlert!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isManualChoiceRequired ? AppTheme.warningBackground : AppTheme.successBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isManualChoiceRequired ? AppTheme.orange : AppTheme.emeraldBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isManualChoiceRequired ? Icons.warning_amber_rounded : Icons.verified,
                              color: isManualChoiceRequired ? AppTheme.warningForeground : AppTheme.successForeground,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CopyableText(
                                CooReviewLocalizer.localizeAlert(context, recommendationAlert),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isManualChoiceRequired ? AppTheme.warningForeground : AppTheme.successForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isManualChoiceRequired && allowedCertTypes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: allowedCertTypes.map((type) {
                              final isSelected = certType == type;
                              final typeLabel = CooReviewLocalizer.localizeCertType(context, type);
                              return ChoiceChip(
                                label: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppTheme.white : AppTheme.textPrimary,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppTheme.cobalt,
                                onSelected: (sel) {
                                  if (sel) {
                                    onCertTypeChanged(type);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (activeDraftTemplate != null) ...[
          const SizedBox(height: 16),
          VisualDraftCOOSheet(
            templateData: activeDraftTemplate!,
            certificateType: certType,
            acidNumber: activeAcidNumber ?? '',
            exemptionNotes: CooReviewLocalizer.localizeExemption(context, activeExemptionNotes),
            onRefresh: onRefresh,
          ),
        ],
      ],
    );
  }
}
