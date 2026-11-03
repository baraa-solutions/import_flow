import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'partner_registration_copy_suffix.dart';

class PartnerBankInspectionInsuranceFields extends StatelessWidget {
  final bool isBank;
  final bool isInspectionAgency;
  final bool isInsuranceCompany;

  final TextEditingController swiftCtrl;
  final TextEditingController bankCodeCtrl;
  final TextEditingController branchCtrl;
  final TextEditingController accreditationCtrl;
  final TextEditingController inspectionScopeCtrl;
  final TextEditingController insuranceLicenseCtrl;
  final TextEditingController insuranceCoverageCtrl;

  const PartnerBankInspectionInsuranceFields({
    super.key,
    required this.isBank,
    required this.isInspectionAgency,
    required this.isInsuranceCompany,
    required this.swiftCtrl,
    required this.bankCodeCtrl,
    required this.branchCtrl,
    required this.accreditationCtrl,
    required this.inspectionScopeCtrl,
    required this.insuranceLicenseCtrl,
    required this.insuranceCoverageCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isBank) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🏦 ${l10n.bankingDetailsHeader}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: swiftCtrl,
                        textDirection: TextDirection.ltr,
                        suffixIcon:
                            PartnerRegistrationCopySuffix(controller: swiftCtrl),
                        label: l10n.bankSwiftCodeLabel,
                        icon: Icons.code,
                        isRequired: true,
                        hint: l10n.bankSwiftCodeHint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: bankCodeCtrl,
                        suffixIcon: PartnerRegistrationCopySuffix(
                            controller: bankCodeCtrl),
                        label: l10n.bankCodeLabel,
                        icon: Icons.account_balance,
                        hint: l10n.bankCodeHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: branchCtrl,
                  suffixIcon:
                      PartnerRegistrationCopySuffix(controller: branchCtrl),
                  label: l10n.branchNameLabel,
                  icon: Icons.location_city,
                  hint: l10n.branchNameHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (isInspectionAgency) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🔍 ${l10n.inspectionAgencyDetailsHeader}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald)),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: accreditationCtrl,
                  suffixIcon: PartnerRegistrationCopySuffix(
                      controller: accreditationCtrl),
                  label: l10n.inspectionAccreditationNumLabel,
                  icon: Icons.verified_user_outlined,
                  isRequired: true,
                  hint: l10n.inspectionAccreditationNumHint,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: inspectionScopeCtrl,
                  suffixIcon: PartnerRegistrationCopySuffix(
                      controller: inspectionScopeCtrl),
                  label: l10n.inspectionScopeLabel,
                  icon: Icons.rule_folder_outlined,
                  hint: l10n.inspectionScopeHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (isInsuranceCompany) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🛡️ ${l10n.insuranceDetailsHeader}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: insuranceLicenseCtrl,
                  suffixIcon: PartnerRegistrationCopySuffix(
                      controller: insuranceLicenseCtrl),
                  label: l10n.insuranceLicenseNumLabel,
                  icon: Icons.verified_user_outlined,
                  isRequired: true,
                  hint: l10n.insuranceLicenseNumHint,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: insuranceCoverageCtrl,
                  suffixIcon: PartnerRegistrationCopySuffix(
                      controller: insuranceCoverageCtrl),
                  label: l10n.insuranceCoverageTypesLabel,
                  icon: Icons.health_and_safety_outlined,
                  hint: l10n.insuranceCoverageTypesHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
