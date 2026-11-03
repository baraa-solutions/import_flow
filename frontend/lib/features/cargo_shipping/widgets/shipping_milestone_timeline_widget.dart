import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/cargo_shipping_model.dart';
import '../services/cargo_shipping_sla_export_service.dart';
import 'cargo_shipping_ui.dart';

/// Toolbar providing TSV, Excel, Vector PDF, and Dossier exports for 48h SLA Tracking.
class ShippingSlaExportToolbar extends StatelessWidget {
  final dynamic curFile;
  final int totalCount;
  final int inProgressCount;
  final int gatedInCount;
  final int breachedCount;
  final String shipmentType;
  final List<ContainerLoadingModel> containers;
  final LclLoadingTrackingModel? lclTracking;
  final String cfsWarehouse;

  const ShippingSlaExportToolbar({
    super.key,
    required this.curFile,
    required this.totalCount,
    required this.inProgressCount,
    required this.gatedInCount,
    required this.breachedCount,
    required this.shipmentType,
    required this.containers,
    required this.lclTracking,
    required this.cfsWarehouse,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fileModel = curFile is ImportFileModel ? curFile as ImportFileModel : null;
    final exportService = CargoShippingSlaExportService(
      context: context,
      importFile: fileModel,
      shipmentType: shipmentType,
      containers: containers,
      lclTracking: lclTracking,
      cfsWarehouse: cfsWarehouse.trim(),
      totalCount: totalCount,
      inProgressCount: inProgressCount,
      gatedInCount: gatedInCount,
      breachedCount: breachedCount,
    );

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 14),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CcUi.fit(AppButton(
            label: l10n.cargoShippingSlaExportTsvBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: () => exportService.exportToTsv(),
          )),
          CcUi.fit(AppButton(
            label: l10n.cargoShippingSlaExportExcelBtn,
            icon: Icons.table_chart,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: () => exportService.exportToExcel(),
          )),
          CcUi.fit(AppButton(
            label: l10n.cargoShippingSlaPrintPdfBtn,
            icon: Icons.picture_as_pdf,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () => exportService.printOrSavePdf(),
          )),
          CcUi.fit(AppButton(
            label: l10n.shipmentUpdateBtnSavePdf,
            icon: Icons.save_alt_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => exportService.printOrSavePdf(save: true),
          )),
          CcUi.fit(AppButton(
            label: l10n.cargoShippingSlaCopyDossierBtn,
            icon: Icons.copy_all_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => exportService.copyDossierToClipboard(),
          )),
        ],
      ),
    );
  }
}

/// Visual 5-milestone timeline progress widget.
class ShippingMilestoneTimelineWidget extends StatelessWidget {
  final int stepIndex;
  final List<String> labels;

  const ShippingMilestoneTimelineWidget({
    super.key,
    required this.stepIndex,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return ShippingMilestoneTimeline(stepIndex: stepIndex, labels: labels);
  }
}

/// Interactive milestone box widget for selecting date/time and displaying notes.
class MilestonePickerBox extends StatelessWidget {
  final String stepNumber;
  final String stepTitle;
  final String? valueText;
  final String? noteText;
  final VoidCallback onPick;
  final VoidCallback onSetNow;
  final VoidCallback onClear;

  const MilestonePickerBox({
    super.key,
    required this.stepNumber,
    required this.stepTitle,
    required this.valueText,
    this.noteText,
    required this.onPick,
    required this.onSetNow,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ShippingMilestoneBox(
      stepNumber: stepNumber,
      stepTitle: stepTitle,
      valueText: valueText,
      noteText: noteText,
      onPick: onPick,
      onSetNow: onSetNow,
      onClear: onClear,
    );
  }
}

/// Interactive milestone-linked notes editor with quick operational tags.
class MilestoneNotesInteractiveSection extends StatelessWidget {
  final int containerIndex;
  final ContainerLoadingModel container;
  final String selectedStep;
  final ValueChanged<String> onSelectStep;
  final TextEditingController noteController;
  final VoidCallback onSaveNote;
  final VoidCallback onClearNote;
  final void Function(String tag) onAddTag;

  const MilestoneNotesInteractiveSection({
    super.key,
    required this.containerIndex,
    required this.container,
    required this.selectedStep,
    required this.onSelectStep,
    required this.noteController,
    required this.onSaveNote,
    required this.onClearNote,
    required this.onAddTag,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    final stepTitles = {
      '1': l.cargoShippingMilestone1,
      '2': l.cargoShippingMilestone2,
      '3': l.cargoShippingMilestone3,
      '4': l.cargoShippingMilestone4,
      '5': l.cargoShippingMilestone5,
    };

    final quickTags = [
      l.cargoShippingTagDriverDelayed,
      l.cargoShippingTagPermitPending,
      l.cargoShippingTagContainerInspection,
      l.cargoShippingTagPortCongestion,
      l.cargoShippingTagPalletizedCargo,
      l.cargoShippingTagVisualCheck,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined, color: AppTheme.cobalt, size: 18),
              const SizedBox(width: 6),
              Text(
                l.cargoShippingNotesHeader(
                  container.containerNo.isNotEmpty
                      ? container.containerNo
                      : l.cargoShippingUnitPrefix(containerIndex + 1),
                ),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Selector of Milestone
          Row(
            children: [
              Text(l.cargoShippingSelectMilestoneTarget, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: stepTitles.entries.map((entry) {
                    final isSel = selectedStep == entry.key;
                    final hasExistingNote = (container.milestoneNotes[entry.key]?.isNotEmpty ?? false);
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value,
                            style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                          ),
                          if (hasExistingNote) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.comment, size: 12, color: AppTheme.orange),
                          ],
                        ],
                      ),
                      selected: isSel,
                      selectedColor: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                      onSelected: (selected) {
                        if (selected) {
                          onSelectStep(entry.key);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Quick Tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: quickTags.map((tag) {
              return ActionChip(
                backgroundColor: AppTheme.surfaceOf(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: AppTheme.borderOf(context)),
                ),
                label: Text(tag, style: TextStyle(fontSize: 11, color: AppTheme.textPrimaryOf(context))),
                onPressed: () => onAddTag(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // 3. Note Input & Save Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: l.cargoShippingNoteHint(stepTitles[selectedStep] ?? ""),
                    hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.surfaceOf(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  AppButton(
                    label: l.cargoShippingSaveNote,
                    icon: Icons.check,
                    size: AppButtonSize.small,
                    onPressed: onSaveNote,
                  ),
                  const SizedBox(height: 4),
                  if (container.milestoneNotes[selectedStep]?.isNotEmpty ?? false)
                    AppButton(
                      label: l.cargoShippingClearNote,
                      icon: Icons.delete_outline,
                      variant: AppButtonVariant.danger,
                      size: AppButtonSize.small,
                      onPressed: onClearNote,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
