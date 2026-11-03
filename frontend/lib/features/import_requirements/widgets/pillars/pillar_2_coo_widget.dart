import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// 🌍 Pillar 2 Widget: Certificate of Origin (COO) & Trade Agreements
///
/// Manages certificate of origin mandates, preferential trade agreement forms
/// (EUR.1, Form A, GAFTA, COMESA, Standard), and status verification.
class Pillar2CooWidget extends StatelessWidget {
  final bool cooRequired;
  final String? cooType;
  final String cooStatus;
  final TextEditingController cooNotesCtrl;
  final ValueChanged<bool> onCooRequiredChanged;
  final ValueChanged<String?> onCooTypeChanged;
  final ValueChanged<String> onCooStatusChanged;

  const Pillar2CooWidget({
    super.key,
    required this.cooRequired,
    required this.cooType,
    required this.cooStatus,
    required this.cooNotesCtrl,
    required this.onCooRequiredChanged,
    required this.onCooTypeChanged,
    required this.onCooStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pillar2Header,
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
                      l10n.cooRequiredCheck,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    value: cooRequired,
                    onChanged: (v) => onCooRequiredChanged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.cooTypeFieldLabel,
                  value: cooType,
                  items: [
                    SearchableDropdownItem(value: 'EUR.1', label: l10n.cooTypeEur1Option),
                    SearchableDropdownItem(value: 'Form A', label: l10n.cooTypeFormAOption),
                    SearchableDropdownItem(value: 'Arab League COO', label: l10n.cooTypeGaftaOption),
                    SearchableDropdownItem(value: 'COMESA', label: l10n.cooTypeComesaOption),
                    SearchableDropdownItem(value: 'Standard COO', label: l10n.cooTypeStandardChamberOption),
                  ],
                  onChanged: onCooTypeChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.cooStatusFieldLabel,
                  value: cooStatus,
                  items: [
                    SearchableDropdownItem(value: 'Not Required', label: l10n.statusInactive),
                    SearchableDropdownItem(value: 'Pending', label: l10n.cooStatusPendingOption),
                    SearchableDropdownItem(value: 'Obtained', label: l10n.cooStatusObtainedOption),
                    SearchableDropdownItem(value: 'Waived', label: l10n.cooStatusWaivedOption),
                  ],
                  onChanged: (v) => onCooStatusChanged(v ?? cooStatus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: cooNotesCtrl,
            decoration: InputDecoration(
              labelText: l10n.cooNotesFieldLabel,
              hintText: l10n.cooNotesHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: l10n.requirementCopyFieldTooltip,
                onPressed: () => CopyHelper.copy(
                  context,
                  cooNotesCtrl.text,
                  customMessage: l10n.requirementCopySummarySuccess,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
