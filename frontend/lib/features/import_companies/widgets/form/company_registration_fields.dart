import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';

/// Core registration fields for ImportCompanyFormDialog
class CompanyRegistrationFields extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController impIdCtrl;
  final TextEditingController vatIdCtrl;
  final TextEditingController regNumCtrl;
  final DateTime impExpiry;
  final DateTime vatExpiry;
  final DateTime regExpiry;
  final ValueChanged<DateTime> onImpExpiryChanged;
  final ValueChanged<DateTime> onVatExpiryChanged;
  final ValueChanged<DateTime> onRegExpiryChanged;

  const CompanyRegistrationFields({
    super.key,
    required this.nameCtrl,
    required this.addressCtrl,
    required this.countryCtrl,
    required this.impIdCtrl,
    required this.vatIdCtrl,
    required this.regNumCtrl,
    required this.impExpiry,
    required this.vatExpiry,
    required this.regExpiry,
    required this.onImpExpiryChanged,
    required this.onVatExpiryChanged,
    required this.onRegExpiryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: nameCtrl,
          label: l10n.companyNameLabel,
          icon: Icons.business,
          isRequired: true,
          hint: l10n.companyNameHint,
          suffixIcon: IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
            tooltip: l10n.importCompaniesCopyFieldTooltip,
            onPressed: () => CopyHelper.copy(context, nameCtrl.text),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: addressCtrl,
                label: l10n.addressLabel,
                icon: Icons.location_on,
                isRequired: true,
                hint: l10n.addressHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, addressCtrl.text),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: countryCtrl,
                label: l10n.countryLabel,
                icon: Icons.flag,
                isRequired: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, countryCtrl.text),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: impIdCtrl,
                label: l10n.importerCardIdLabel,
                icon: Icons.badge,
                isRequired: true,
                hint: l10n.importerCardIdHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, impIdCtrl.text),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppDatePickerField(
                label: l10n.importerCardExpiryLabel,
                value: impExpiry,
                allowClear: false,
                isRequired: true,
                onChanged: (d) {
                  if (d != null) onImpExpiryChanged(d);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: vatIdCtrl,
                label: l10n.vatRegIdLabel,
                icon: Icons.receipt_long,
                isRequired: true,
                hint: l10n.vatRegIdHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, vatIdCtrl.text),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppDatePickerField(
                label: l10n.vatRegExpiryLabel,
                value: vatExpiry,
                allowClear: false,
                isRequired: true,
                onChanged: (d) {
                  if (d != null) onVatExpiryChanged(d);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: regNumCtrl,
                label: l10n.commercialRegNumLabel,
                icon: Icons.app_registration,
                isRequired: true,
                hint: l10n.commercialRegNumHint,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                  tooltip: l10n.importCompaniesCopyFieldTooltip,
                  onPressed: () => CopyHelper.copy(context, regNumCtrl.text),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppDatePickerField(
                label: l10n.commercialRegExpiryLabel,
                value: regExpiry,
                allowClear: false,
                isRequired: true,
                onChanged: (d) {
                  if (d != null) onRegExpiryChanged(d);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
