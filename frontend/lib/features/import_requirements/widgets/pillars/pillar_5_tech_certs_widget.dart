import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// 📜 Pillar 5 Widget: Technical Certificates & Sailing Readiness
///
/// Manages MSDS (Material Safety Data Sheets), Halal Certificates, COA (Certificate
/// of Analysis), Sailing Status authorization, Risk Assessment, and Overall Status.
class Pillar5TechCertsWidget extends StatelessWidget {
  final bool msdsRequired;
  final bool halalCertRequired;
  final bool coaRequired;
  final String sailingStatus;
  final String riskLevel;
  final String overallStatus;
  final TextEditingController sailingDateCtrl;
  final TextEditingController specialNotesCtrl;
  final ValueChanged<bool> onMsdsRequiredChanged;
  final ValueChanged<bool> onHalalCertRequiredChanged;
  final ValueChanged<bool> onCoaRequiredChanged;
  final ValueChanged<String> onSailingStatusChanged;
  final ValueChanged<String> onRiskLevelChanged;
  final ValueChanged<String> onOverallStatusChanged;

  const Pillar5TechCertsWidget({
    super.key,
    required this.msdsRequired,
    required this.halalCertRequired,
    required this.coaRequired,
    required this.sailingStatus,
    required this.riskLevel,
    required this.overallStatus,
    required this.sailingDateCtrl,
    required this.specialNotesCtrl,
    required this.onMsdsRequiredChanged,
    required this.onHalalCertRequiredChanged,
    required this.onCoaRequiredChanged,
    required this.onSailingStatusChanged,
    required this.onRiskLevelChanged,
    required this.onOverallStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pillar5Header,
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
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(
                      l10n.msdsRequiredCheck,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    value: msdsRequired,
                    onChanged: (v) => onMsdsRequiredChanged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(
                      l10n.halalCertRequiredCheck,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    value: halalCertRequired,
                    onChanged: (v) => onHalalCertRequiredChanged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    title: Text(
                      l10n.coaRequiredCheck,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    value: coaRequired,
                    onChanged: (v) => onCoaRequiredChanged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.charcoalSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cloudWhite),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.sailingStatusFieldLabel,
                    value: sailingStatus,
                    items: [
                      SearchableDropdownItem(value: 'Pre-Sailing', label: l10n.sailingStatusPreSailingOption),
                      SearchableDropdownItem(value: 'Cleared for Sailing', label: l10n.sailingStatusClearedOption),
                      SearchableDropdownItem(value: 'Sailed', label: l10n.sailingStatusSailedOption),
                    ],
                    onChanged: (v) => onSailingStatusChanged(v ?? sailingStatus),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: sailingDateCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.sailingDateFieldLabel,
                      hintText: 'YYYY-MM-DD',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_boat, color: AppTheme.cobalt, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: l10n.requirementCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(
                          context,
                          sailingDateCtrl.text,
                          customMessage: l10n.requirementCopySummarySuccess,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.riskLevelFieldLabel,
                    value: riskLevel,
                    items: [
                      SearchableDropdownItem(value: 'Low', label: l10n.riskLevelLowOption),
                      SearchableDropdownItem(value: 'Medium', label: l10n.riskLevelMediumOption),
                      SearchableDropdownItem(value: 'High', label: l10n.riskLevelHighOption),
                    ],
                    onChanged: (v) => onRiskLevelChanged(v ?? riskLevel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.statusCol,
                    value: overallStatus,
                    items: [
                      SearchableDropdownItem(value: 'Draft', label: l10n.overallStatusDraftOption),
                      SearchableDropdownItem(value: 'In Progress', label: l10n.overallStatusInProgressOption),
                      SearchableDropdownItem(value: 'Complete', label: l10n.overallStatusCompleteOption),
                      SearchableDropdownItem(value: 'Confirmed', label: l10n.overallStatusConfirmedOption),
                    ],
                    onChanged: (v) => onOverallStatusChanged(v ?? overallStatus),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: specialNotesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.requirementsTsvHeaderNotes,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note_alt_outlined, color: AppTheme.cobalt, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: l10n.requirementCopyFieldTooltip,
                onPressed: () => CopyHelper.copy(
                  context,
                  specialNotesCtrl.text,
                  customMessage: l10n.copiedToClipboardGeneric,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
