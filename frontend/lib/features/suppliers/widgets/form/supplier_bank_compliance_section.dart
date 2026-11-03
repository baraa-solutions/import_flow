import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import 'supplier_form_controllers.dart';

class SupplierBankComplianceSection extends StatelessWidget {
  final SupplierFormControllers controllers;
  final ValueChanged<VoidCallback> onStateChanged;

  const SupplierBankComplianceSection({
    super.key,
    required this.controllers,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Beneficiary Bank & SWIFT Information
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance, size: 16, color: AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Text(
                    l10n.beneficiaryBankDetailsHeader,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: controllers.bankNameCtrl,
                suffixIcon: controllers.buildCopySuffix(context, controllers.bankNameCtrl),
                label: l10n.beneficiaryBankNameLabel,
                icon: Icons.business,
                hint: l10n.beneficiaryBankNameHint,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: controllers.swiftCodeCtrl,
                      textDirection: TextDirection.ltr,
                      suffixIcon: controllers.buildCopySuffix(context, controllers.swiftCodeCtrl),
                      label: l10n.beneficiarySwiftCodeLabel,
                      icon: Icons.code,
                      hint: l10n.beneficiarySwiftCodeHint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: controllers.accountNumberCtrl,
                      suffixIcon: controllers.buildCopySuffix(context, controllers.accountNumberCtrl),
                      label: l10n.beneficiaryAccountNumberLabel,
                      icon: Icons.numbers,
                      hint: l10n.beneficiaryAccountNumberHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: controllers.ibanCtrl,
                textDirection: TextDirection.ltr,
                suffixIcon: controllers.buildCopySuffix(context, controllers.ibanCtrl),
                label: l10n.beneficiaryIbanLabel,
                icon: Icons.credit_card,
                hint: l10n.beneficiaryIbanHint,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Compliance Flags Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.complianceAndCertsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.isoCertifiedCheck),
                value: controllers.hasIso,
                activeColor: AppTheme.cobalt,
                onChanged: (val) => onStateChanged(() => controllers.hasIso = val ?? false),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.decree43Check),
                value: controllers.registeredDecree43,
                activeColor: AppTheme.cobalt,
                onChanged: (val) => onStateChanged(() => controllers.registeredDecree43 = val ?? false),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.whiteListCheck),
                value: controllers.whiteListRegistered,
                activeColor: AppTheme.emerald,
                onChanged: (val) => onStateChanged(() => controllers.whiteListRegistered = val ?? false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
