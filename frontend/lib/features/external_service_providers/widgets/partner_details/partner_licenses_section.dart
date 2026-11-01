import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/partner_model.dart';
import 'partner_details_fields.dart';

class PartnerLicensesSection extends StatelessWidget {
  final PartnerModel partner;

  const PartnerLicensesSection({
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
            context, Icons.verified_outlined, l10n.professionalLicensesSection),
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (partner.swiftCode != null && partner.swiftCode!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.partnerSwiftCodeDetailLabel,
                        value: partner.swiftCode!,
                        icon: Icons.flash_on_rounded,
                        highlightColor: AppTheme.cobalt,
                      ),
                    ),
                  if (partner.scacCode != null && partner.scacCode!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.partnerScacCodeDetailLabel,
                        value: partner.scacCode!,
                        icon: Icons.directions_boat_outlined,
                        highlightColor: AppTheme.cobalt,
                      ),
                    ),
                  if (partner.fiataId != null && partner.fiataId!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.fiataLicenseLabel,
                        value: partner.fiataId!,
                        icon: Icons.badge_rounded,
                        highlightColor:
                            isDark ? AppTheme.cobalt : AppTheme.charcoal,
                      ),
                    ),
                  if (partner.shippingModes != null &&
                      partner.shippingModes!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.shippingModesLabel,
                        value: partner.shippingModes!,
                        icon: Icons.alt_route_rounded,
                        highlightColor: AppTheme.cobalt,
                      ),
                    ),
                  if (partner.supportedCurrencies != null &&
                      partner.supportedCurrencies!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.supportedCurrenciesLabel,
                        value: partner.supportedCurrencies!,
                        icon: Icons.monetization_on_outlined,
                        highlightColor: AppTheme.emerald,
                      ),
                    ),
                  if (partner.inspectionAccreditationNumber != null &&
                      partner.inspectionAccreditationNumber!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.inspectionAccreditationNumLabel,
                        value: partner.inspectionAccreditationNumber!,
                        icon: Icons.verified_user_outlined,
                        highlightColor: AppTheme.cobalt,
                      ),
                    ),
                  if (partner.inspectionScope != null &&
                      partner.inspectionScope!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.inspectionScopeLabel,
                        value: partner.inspectionScope!,
                        icon: Icons.rule_folder_outlined,
                        highlightColor: AppTheme.emerald,
                      ),
                    ),
                  if (partner.clearanceLicenseNumber != null &&
                      partner.clearanceLicenseNumber!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.clearanceLicenseDetailLabel,
                        value: partner.clearanceLicenseNumber!,
                        icon: Icons.card_membership_rounded,
                        highlightColor: AppTheme.orange,
                      ),
                    ),
                  if (partner.authorizedPorts != null &&
                      partner.authorizedPorts!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.authorizedPortsLabel,
                        value: partner.authorizedPorts!,
                        icon: Icons.anchor_outlined,
                        highlightColor: AppTheme.orange,
                      ),
                    ),
                  if (partner.transportLicenseNumber != null &&
                      partner.transportLicenseNumber!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.transportLicenseNumLabel,
                        value: partner.transportLicenseNumber!,
                        icon: Icons.local_shipping_outlined,
                        highlightColor: AppTheme.emerald,
                      ),
                    ),
                  if (partner.fleetTypes != null && partner.fleetTypes!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.fleetTypesLabel,
                        value: partner.fleetTypes!,
                        icon: Icons.rv_hookup,
                        highlightColor: AppTheme.emerald,
                      ),
                    ),
                  if (partner.coverageAreas != null &&
                      partner.coverageAreas!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.coverageAreasLabel,
                        value: partner.coverageAreas!,
                        icon: Icons.map_outlined,
                        highlightColor: AppTheme.emerald,
                      ),
                    ),
                  if (partner.insuranceLicenseNumber != null &&
                      partner.insuranceLicenseNumber!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.insuranceLicenseNumLabel,
                        value: partner.insuranceLicenseNumber!,
                        icon: Icons.verified_user_outlined,
                        highlightColor: AppTheme.cobalt,
                      ),
                    ),
                  if (partner.insuranceCoverageTypes != null &&
                      partner.insuranceCoverageTypes!.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: PartnerDetailsFields.buildCopyableInfoField(
                        context: context,
                        label: l10n.insuranceCoverageTypesLabel,
                        value: partner.insuranceCoverageTypes!,
                        icon: Icons.health_and_safety_outlined,
                        highlightColor: AppTheme.cobalt,
                      ),
                    ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: PartnerDetailsFields.buildCopyableInfoField(
                      context: context,
                      label: l10n.commercialRegDetailLabel,
                      value: partner.commercialRegister ?? '-',
                      icon: Icons.account_balance_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PartnerDetailsFields.buildCopyableInfoField(
                      context: context,
                      label: l10n.taxIdDetailLabel,
                      value: partner.taxId ?? '-',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
