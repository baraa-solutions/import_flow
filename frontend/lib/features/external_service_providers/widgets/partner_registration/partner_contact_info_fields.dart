import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'partner_registration_copy_suffix.dart';

class PartnerContactInfoFields extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController secondaryEmailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController mobileCtrl;
  final TextEditingController faxCtrl;
  final TextEditingController websiteCtrl;

  const PartnerContactInfoFields({
    super.key,
    required this.emailCtrl,
    required this.secondaryEmailCtrl,
    required this.phoneCtrl,
    required this.mobileCtrl,
    required this.faxCtrl,
    required this.websiteCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contact Details
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: emailCtrl,
                textDirection: TextDirection.ltr,
                suffixIcon: PartnerRegistrationCopySuffix(controller: emailCtrl),
                label: l10n.partnerPrimaryEmailLabel,
                icon: Icons.email,
                hint: l10n.partnerPrimaryEmailHint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: secondaryEmailCtrl,
                textDirection: TextDirection.ltr,
                suffixIcon: PartnerRegistrationCopySuffix(
                    controller: secondaryEmailCtrl),
                label: l10n.partnerSecondaryEmailLabel,
                icon: Icons.alternate_email,
                hint: l10n.partnerSecondaryEmailHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: phoneCtrl,
                textDirection: TextDirection.ltr,
                suffixIcon: PartnerRegistrationCopySuffix(controller: phoneCtrl),
                label: l10n.partnerPhoneLabel,
                icon: Icons.phone,
                hint: l10n.partnerPhoneHint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: mobileCtrl,
                textDirection: TextDirection.ltr,
                suffixIcon: PartnerRegistrationCopySuffix(controller: mobileCtrl),
                label: l10n.partnerMobileLabel,
                icon: Icons.phone_android,
                hint: l10n.partnerMobileHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: faxCtrl,
                textDirection: TextDirection.ltr,
                suffixIcon: PartnerRegistrationCopySuffix(controller: faxCtrl),
                label: l10n.partnerFaxLabel,
                icon: Icons.print_outlined,
                hint: l10n.partnerFaxHint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: websiteCtrl,
                textDirection: TextDirection.ltr,
                suffixIcon:
                    PartnerRegistrationCopySuffix(controller: websiteCtrl),
                label: l10n.partnerWebsiteUrlLabel,
                icon: Icons.language,
                hint: l10n.partnerWebsiteUrlHint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
