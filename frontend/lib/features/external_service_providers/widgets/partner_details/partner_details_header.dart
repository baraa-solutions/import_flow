import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/partner_model.dart';
import 'partner_details_fields.dart';

class PartnerDetailsHeader extends StatelessWidget {
  final PartnerModel partner;
  final VoidCallback onClose;

  const PartnerDetailsHeader({
    super.key,
    required this.partner,
    required this.onClose,
  });

  static String buildPartnerSummary(BuildContext context, PartnerModel p) {
    final l10n = context.l10n;
    final b = StringBuffer();
    b.writeln('📋 ${l10n.partnerProfileTitle}');
    b.writeln('${l10n.partnerCodeBadgeLabel}${p.partnerCode}');
    b.writeln('${l10n.partnerNameLabel}: ${p.partnerName}');
    b.writeln('${l10n.partnerCategoriesLabel}: ${p.partnerType}');
    b.writeln('${l10n.countryDetailLabel}: ${p.country}');
    if (p.address != null && p.address!.isNotEmpty) {
      b.writeln('${l10n.fullAddressDetailLabel}: ${p.address}');
    }
    if (p.phone != null && p.phone!.isNotEmpty) {
      b.writeln('${l10n.partnerPhoneLabel}: ${p.phone}');
    }
    if (p.mobile != null && p.mobile!.isNotEmpty) {
      b.writeln('${l10n.partnerMobileLabel}: ${p.mobile}');
    }
    if (p.email != null && p.email!.isNotEmpty) {
      b.writeln('${l10n.emailDetailLabel}: ${p.email}');
    }
    if (p.website != null && p.website!.isNotEmpty) {
      b.writeln('${l10n.websiteDetailLabel}: ${p.website}');
    }
    if (p.swiftCode != null && p.swiftCode!.isNotEmpty) {
      b.writeln('${l10n.partnerSwiftCodeDetailLabel}: ${p.swiftCode}');
    }
    if (p.scacCode != null && p.scacCode!.isNotEmpty) {
      b.writeln('${l10n.partnerScacCodeDetailLabel}: ${p.scacCode}');
    }
    if (p.defaultFreeDays != null) {
      b.writeln('${l10n.defaultFreeDaysLabel}: ${p.defaultFreeDays}');
    }
    if (p.fiataId != null && p.fiataId!.isNotEmpty) {
      b.writeln('${l10n.fiataLicenseLabel}: ${p.fiataId}');
    }
    if (p.shippingModes != null && p.shippingModes!.isNotEmpty) {
      b.writeln('${l10n.shippingModesLabel}: ${p.shippingModes}');
    }
    if (p.supportedCurrencies != null && p.supportedCurrencies!.isNotEmpty) {
      b.writeln('${l10n.supportedCurrenciesLabel}: ${p.supportedCurrencies}');
    }
    if (p.inspectionAccreditationNumber != null &&
        p.inspectionAccreditationNumber!.isNotEmpty) {
      b.writeln(
          '${l10n.inspectionAccreditationNumLabel}: ${p.inspectionAccreditationNumber}');
    }
    if (p.inspectionScope != null && p.inspectionScope!.isNotEmpty) {
      b.writeln('${l10n.inspectionScopeLabel}: ${p.inspectionScope}');
    }
    if (p.clearanceLicenseNumber != null &&
        p.clearanceLicenseNumber!.isNotEmpty) {
      b.writeln(
          '${l10n.clearanceLicenseDetailLabel}: ${p.clearanceLicenseNumber}');
    }
    if (p.authorizedPorts != null && p.authorizedPorts!.isNotEmpty) {
      b.writeln('${l10n.authorizedPortsLabel}: ${p.authorizedPorts}');
    }
    if (p.transportLicenseNumber != null &&
        p.transportLicenseNumber!.isNotEmpty) {
      b.writeln(
          '${l10n.transportLicenseNumLabel}: ${p.transportLicenseNumber}');
    }
    if (p.fleetTypes != null && p.fleetTypes!.isNotEmpty) {
      b.writeln('${l10n.fleetTypesLabel}: ${p.fleetTypes}');
    }
    if (p.coverageAreas != null && p.coverageAreas!.isNotEmpty) {
      b.writeln('${l10n.coverageAreasLabel}: ${p.coverageAreas}');
    }
    if (p.insuranceLicenseNumber != null &&
        p.insuranceLicenseNumber!.isNotEmpty) {
      b.writeln(
          '${l10n.insuranceLicenseNumLabel}: ${p.insuranceLicenseNumber}');
    }
    if (p.insuranceCoverageTypes != null &&
        p.insuranceCoverageTypes!.isNotEmpty) {
      b.writeln(
          '${l10n.insuranceCoverageTypesLabel}: ${p.insuranceCoverageTypes}');
    }
    if (p.commercialRegister != null && p.commercialRegister!.isNotEmpty) {
      b.writeln('${l10n.commercialRegDetailLabel}: ${p.commercialRegister}');
    }
    if (p.taxId != null && p.taxId!.isNotEmpty) {
      b.writeln('${l10n.taxIdDetailLabel}: ${p.taxId}');
    }
    b.writeln(
        '${l10n.partnerStatusCol}: ${p.isActive ? l10n.statusActive : l10n.statusInactive}');
    if (p.notes != null && p.notes!.isNotEmpty) {
      b.writeln('${l10n.additionalNotesSection}: ${p.notes}');
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = partner.isActive;
    final categories = partner.categoriesList;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.handshake_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        partner.partnerCode,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SelectableText(
                        partner.partnerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.partnersCopyFieldTooltip,
                      child: InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          partner.partnerName,
                          customMessage:
                              l10n.copiedToClipboard(partner.partnerName),
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.copy_rounded,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.partnerCopySummaryBtn,
                      child: InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          buildPartnerSummary(context, partner),
                          customMessage: l10n.partnerCopySummarySuccess,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.copy_all_rounded,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isActive ? AppTheme.emerald : AppTheme.crimson)
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              isActive ? AppTheme.emerald : AppTheme.crimson,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isActive ? l10n.statusActive : l10n.statusInactive,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFFE74C3C),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: categories
                      .map((c) =>
                          PartnerDetailsFields.buildCategoryChip(context, c))
                      .toList(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
            tooltip: l10n.closeBtn,
          ),
        ],
      ),
    );
  }
}
