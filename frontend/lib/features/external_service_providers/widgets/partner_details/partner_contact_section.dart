import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/partner_model.dart';
import 'partner_details_fields.dart';

class PartnerContactSection extends StatelessWidget {
  final PartnerModel partner;

  const PartnerContactSection({
    super.key,
    required this.partner,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PartnerDetailsFields.buildSectionHeader(
            context, Icons.contact_phone_outlined, l10n.contactAndAddressSection),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PartnerDetailsFields.buildCopyableInfoField(
                      context: context,
                      label: l10n.contactPersonDetailLabel,
                      value: partner.contactPerson ?? '-',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PartnerDetailsFields.buildCopyableInfoField(
                      context: context,
                      label: l10n.countryDetailLabel,
                      value: partner.country,
                      icon: Icons.public,
                    ),
                  ),
                ],
              ),
              const Divider(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PartnerDetailsFields.buildCopyableInfoField(
                      context: context,
                      label: l10n.phoneMobileDetailLabel,
                      value: partner.phone ?? partner.mobile ?? '-',
                      icon: Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PartnerDetailsFields.buildCopyableInfoField(
                      context: context,
                      label: l10n.emailDetailLabel,
                      value: partner.email ?? '-',
                      icon: Icons.email_outlined,
                    ),
                  ),
                ],
              ),
              if (partner.address != null && partner.address!.isNotEmpty) ...[
                const Divider(height: 14),
                PartnerDetailsFields.buildCopyableInfoField(
                  context: context,
                  label: l10n.fullAddressDetailLabel,
                  value: partner.address!,
                  icon: Icons.location_on_outlined,
                ),
              ],
              if (partner.website != null && partner.website!.isNotEmpty) ...[
                const Divider(height: 14),
                PartnerDetailsFields.buildCopyableInfoField(
                  context: context,
                  label: l10n.websiteDetailLabel,
                  value: partner.website!,
                  icon: Icons.language_outlined,
                ),
              ],
            ],
          ),
        ),
        if (partner.notes != null && partner.notes!.isNotEmpty) ...[
          const SizedBox(height: 18),
          PartnerDetailsFields.buildSectionHeader(
              context, Icons.notes_rounded, l10n.additionalNotesSection),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.orange.withValues(alpha: 0.12)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark
                      ? AppTheme.orange.withValues(alpha: 0.3)
                      : const Color(0xFFFDE68A)),
            ),
            child: Text(
              partner.notes!,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.orange : const Color(0xFF92400E)),
            ),
          ),
        ],
      ],
    );
  }
}
