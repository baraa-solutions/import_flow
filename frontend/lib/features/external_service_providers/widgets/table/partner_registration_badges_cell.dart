import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/partner_model.dart';

class PartnerRegistrationBadgesCell extends StatelessWidget {
  final PartnerModel partner;

  const PartnerRegistrationBadgesCell({super.key, required this.partner});

  Widget _badgeRow({
    required IconData icon,
    required Color color,
    required String text,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, fontWeight: fontWeight, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (partner.swiftCode != null && partner.swiftCode!.isNotEmpty)
          _badgeRow(
            icon: Icons.account_balance_outlined,
            color: AppTheme.cobalt,
            text: l10n.partnerSwiftLabel(partner.swiftCode!),
          ),
        if (partner.scacCode != null && partner.scacCode!.isNotEmpty)
          _badgeRow(
            icon: Icons.directions_boat_outlined,
            color: AppTheme.cobalt,
            text: l10n.partnerScacLabel(partner.scacCode!),
          ),
        if (partner.defaultFreeDays != null)
          _badgeRow(
            icon: Icons.timer_outlined,
            color: AppTheme.emerald,
            text: l10n.partnerFreeDaysBadge(partner.defaultFreeDays!),
          ),
        if (partner.fiataId != null && partner.fiataId!.isNotEmpty)
          _badgeRow(
            icon: Icons.badge_rounded,
            color: isDark ? AppTheme.cobalt : AppTheme.charcoal,
            text: l10n.partnerFiataBadge(partner.fiataId!),
          ),
        if (partner.shippingModes != null && partner.shippingModes!.isNotEmpty)
          _badgeRow(
            icon: Icons.alt_route_rounded,
            color: AppTheme.cobalt,
            text: partner.shippingModes!,
            fontWeight: FontWeight.w500,
          ),
        if (partner.supportedCurrencies != null && partner.supportedCurrencies!.isNotEmpty)
          _badgeRow(
            icon: Icons.monetization_on_outlined,
            color: AppTheme.emerald,
            text: partner.supportedCurrencies!,
          ),
        if (partner.inspectionAccreditationNumber != null && partner.inspectionAccreditationNumber!.isNotEmpty)
          _badgeRow(
            icon: Icons.verified_user_outlined,
            color: AppTheme.cobalt,
            text: l10n.partnerAccreditationBadge(partner.inspectionAccreditationNumber!),
          ),
        if (partner.inspectionScope != null && partner.inspectionScope!.isNotEmpty)
          _badgeRow(
            icon: Icons.rule_folder_outlined,
            color: AppTheme.emerald,
            text: partner.inspectionScope!,
            fontWeight: FontWeight.w500,
          ),
        if (partner.clearanceLicenseNumber != null && partner.clearanceLicenseNumber!.isNotEmpty)
          _badgeRow(
            icon: Icons.assignment_ind_outlined,
            color: AppTheme.orange,
            text: l10n.partnerLicenseLabel(partner.clearanceLicenseNumber!),
          ),
        if (partner.authorizedPorts != null && partner.authorizedPorts!.isNotEmpty)
          _badgeRow(
            icon: Icons.anchor_outlined,
            color: AppTheme.orange,
            text: l10n.partnerPortsBadge(partner.authorizedPorts!),
            fontWeight: FontWeight.w500,
          ),
        if (partner.transportLicenseNumber != null && partner.transportLicenseNumber!.isNotEmpty)
          _badgeRow(
            icon: Icons.local_shipping_outlined,
            color: AppTheme.cobalt,
            text: l10n.partnerLicenseLabel(partner.transportLicenseNumber!),
          ),
        if (partner.fleetTypes != null && partner.fleetTypes!.isNotEmpty)
          _badgeRow(
            icon: Icons.fire_truck_outlined,
            color: AppTheme.cobalt,
            text: l10n.partnerFleetBadge(partner.fleetTypes!),
            fontWeight: FontWeight.w500,
          ),
        if (partner.coverageAreas != null && partner.coverageAreas!.isNotEmpty)
          _badgeRow(
            icon: Icons.map_outlined,
            color: AppTheme.emerald,
            text: l10n.partnerCoverageBadge(partner.coverageAreas!),
            fontWeight: FontWeight.w500,
          ),
        if (partner.insuranceLicenseNumber != null && partner.insuranceLicenseNumber!.isNotEmpty)
          _badgeRow(
            icon: Icons.verified_user_outlined,
            color: AppTheme.cobalt,
            text: l10n.partnerLicenseLabel(partner.insuranceLicenseNumber!),
          ),
        if (partner.insuranceCoverageTypes != null && partner.insuranceCoverageTypes!.isNotEmpty)
          _badgeRow(
            icon: Icons.health_and_safety_outlined,
            color: AppTheme.cobalt,
            text: l10n.partnerInsuranceCoverageBadge(partner.insuranceCoverageTypes!),
            fontWeight: FontWeight.w500,
          ),
        if (partner.commercialRegister != null && partner.commercialRegister!.isNotEmpty)
          _badgeRow(
            icon: Icons.description_outlined,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
            text: l10n.partnerRegLabel(partner.commercialRegister!),
            fontWeight: FontWeight.normal,
          ),
        if (partner.taxId != null && partner.taxId!.isNotEmpty)
          _badgeRow(
            icon: Icons.receipt_long,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
            text: '${l10n.partnerTaxIdLabel}: ${partner.taxId}',
            fontWeight: FontWeight.normal,
          ),
      ],
    );
  }
}
