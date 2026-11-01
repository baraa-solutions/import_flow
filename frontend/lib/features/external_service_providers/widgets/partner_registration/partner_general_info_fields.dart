import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'partner_registration_copy_suffix.dart';

class PartnerGeneralInfoFields extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController taxIdCtrl;
  final TextEditingController regCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController paymentTermsCtrl;
  final TextEditingController creditLimitCtrl;
  final bool isFreightForwarder;

  const PartnerGeneralInfoFields({
    super.key,
    required this.nameCtrl,
    required this.taxIdCtrl,
    required this.regCtrl,
    required this.addressCtrl,
    required this.countryCtrl,
    required this.paymentTermsCtrl,
    required this.creditLimitCtrl,
    required this.isFreightForwarder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: nameCtrl,
          suffixIcon: PartnerRegistrationCopySuffix(controller: nameCtrl),
          label: l10n.partnerNameLabel,
          icon: Icons.business,
          isRequired: true,
          hint: l10n.partnerNameHint,
        ),
        const SizedBox(height: 16),

        // Registration & Tax Identifiers
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: taxIdCtrl,
                suffixIcon: PartnerRegistrationCopySuffix(controller: taxIdCtrl),
                label: l10n.partnerTaxIdLabel,
                icon: Icons.receipt_long,
                hint: l10n.partnerTaxIdHint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: regCtrl,
                suffixIcon: PartnerRegistrationCopySuffix(controller: regCtrl),
                label: l10n.partnerCommercialRegLabel,
                icon: Icons.description_outlined,
                hint: l10n.partnerCommercialRegHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Address & Country
        Row(
          children: [
            Expanded(
              flex: 2,
              child: CustomTextField(
                controller: addressCtrl,
                suffixIcon:
                    PartnerRegistrationCopySuffix(controller: addressCtrl),
                label: l10n.partnerAddressLabel,
                icon: Icons.location_on,
                hint: l10n.partnerAddressHint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: CustomTextField(
                controller: countryCtrl,
                suffixIcon:
                    PartnerRegistrationCopySuffix(controller: countryCtrl),
                label: l10n.countryLabel,
                icon: Icons.public,
                hint: l10n.countryHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Payment Terms & Credit Limit
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: paymentTermsCtrl,
                suffixIcon:
                    PartnerRegistrationCopySuffix(controller: paymentTermsCtrl),
                label: l10n.paymentTermsDetailLabel,
                icon: Icons.payment,
                hint: 'e.g. Net 30',
              ),
            ),
            if (!isFreightForwarder) ...[
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: creditLimitCtrl,
                  suffixIcon: PartnerRegistrationCopySuffix(
                      controller: creditLimitCtrl),
                  label: l10n.creditLimitDetailLabel,
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  hint: '0.00',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
