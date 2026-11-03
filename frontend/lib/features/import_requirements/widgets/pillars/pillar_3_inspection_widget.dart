import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// 🔍 Pillar 3 Widget: Pre-Shipment Inspection (PSI)
///
/// Handles pre-shipment inspection mandates, accredited inspection companies
/// (SGS, Bureau Veritas, TÜV, Intertek, QIMA, ILAC ISO 17025), and certificate logs.
class Pillar3InspectionWidget extends StatelessWidget {
  final bool inspectionRequired;
  final String? inspectionBody;
  final String inspectionStatus;
  final TextEditingController inspReportNoCtrl;
  final TextEditingController inspNotesCtrl;
  final ValueChanged<bool> onInspectionRequiredChanged;
  final ValueChanged<String?> onInspectionBodyChanged;
  final ValueChanged<String> onInspectionStatusChanged;

  const Pillar3InspectionWidget({
    super.key,
    required this.inspectionRequired,
    required this.inspectionBody,
    required this.inspectionStatus,
    required this.inspReportNoCtrl,
    required this.inspNotesCtrl,
    required this.onInspectionRequiredChanged,
    required this.onInspectionBodyChanged,
    required this.onInspectionStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pillar3Header,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(
                      l10n.inspectionRequiredCheck,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    value: inspectionRequired,
                    onChanged: (v) => onInspectionRequiredChanged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.inspectionBodyFieldLabel,
                  value: inspectionBody,
                  items: [
                    SearchableDropdownItem(value: 'SGS', label: l10n.inspectionBodySgsOption),
                    SearchableDropdownItem(value: 'Bureau Veritas', label: l10n.inspectionBodyBvOption),
                    SearchableDropdownItem(value: 'TÜV', label: l10n.inspectionBodyTuvOption),
                    SearchableDropdownItem(value: 'Intertek', label: l10n.inspectionBodyIntertekOption),
                    SearchableDropdownItem(value: 'QIMA', label: l10n.inspectionBodyQimaOption),
                    SearchableDropdownItem(value: 'ILAC ISO 17025', label: l10n.inspectionBodyIlacOption),
                  ],
                  onChanged: onInspectionBodyChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.inspectionStatusFieldLabel,
                  value: inspectionStatus,
                  items: [
                    SearchableDropdownItem(value: 'Not Required', label: l10n.statusInactive),
                    SearchableDropdownItem(value: 'Pending', label: l10n.inspectionStatusPendingOption),
                    SearchableDropdownItem(value: 'Scheduled', label: l10n.inspectionStatusScheduledOption),
                    SearchableDropdownItem(value: 'Completed', label: l10n.inspectionStatusCompletedOption),
                    SearchableDropdownItem(value: 'Rejected', label: l10n.inspectionStatusRejectedOption),
                  ],
                  onChanged: (v) => onInspectionStatusChanged(v ?? inspectionStatus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: inspReportNoCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.inspectionReportNumFieldLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        inspReportNoCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: inspNotesCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.inspectionNotesFieldLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        inspNotesCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
