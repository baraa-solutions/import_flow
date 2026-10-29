import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// 🏛️ Pillar 4 Widget: Prior Import Permits & Approvals
///
/// Tracks ministerial and regulatory agency prior import permits (EDA, NTRA,
/// GOEIC, Atomic Energy, Agriculture, Environment, etc.) and verification status.
class Pillar4PermitsWidget extends StatelessWidget {
  final bool importPermitRequired;
  final String? permitIssuingAuthority;
  final String permitStatus;
  final TextEditingController permitNumberCtrl;
  final TextEditingController permitNotesCtrl;
  final ValueChanged<bool> onImportPermitRequiredChanged;
  final ValueChanged<String?> onPermitIssuingAuthorityChanged;
  final ValueChanged<String> onPermitStatusChanged;

  const Pillar4PermitsWidget({
    super.key,
    required this.importPermitRequired,
    required this.permitIssuingAuthority,
    required this.permitStatus,
    required this.permitNumberCtrl,
    required this.permitNotesCtrl,
    required this.onImportPermitRequiredChanged,
    required this.onPermitIssuingAuthorityChanged,
    required this.onPermitStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pillar4Header,
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
                      l10n.importPermitRequiredCheck,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    value: importPermitRequired,
                    onChanged: (v) => onImportPermitRequiredChanged(v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.issuingAuthorityFieldLabel,
                  value: permitIssuingAuthority,
                  items: [
                    for (final code in DomainEnums.codesOf(DomainEnumType.regulatoryBody))
                      SearchableDropdownItem(
                        value: code,
                        label: DomainEnums.label(l10n, DomainEnumType.regulatoryBody, code),
                      ),
                  ],
                  onChanged: onPermitIssuingAuthorityChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l10n.permitStatusFieldLabel,
                  value: permitStatus,
                  items: [
                    SearchableDropdownItem(value: 'Not Required', label: l10n.statusInactive),
                    SearchableDropdownItem(value: 'Applied', label: l10n.permitStatusAppliedOption),
                    SearchableDropdownItem(value: 'Approved', label: l10n.permitStatusApprovedOption),
                    SearchableDropdownItem(value: 'Rejected', label: l10n.permitStatusRejectedOption),
                  ],
                  onChanged: (v) => onPermitStatusChanged(v ?? permitStatus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: permitNumberCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.permitNumberFieldLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        permitNumberCtrl.text,
                        customMessage: l10n.requirementCopySummarySuccess,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: permitNotesCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.permitNotesFieldLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.requirementCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(
                        context,
                        permitNotesCtrl.text,
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
