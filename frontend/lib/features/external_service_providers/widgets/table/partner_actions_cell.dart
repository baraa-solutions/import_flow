import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/row_actions_pill.dart';
import '../../models/partner_model.dart';

String buildPartnerSummary(BuildContext context, PartnerModel p) {
  final l10n = context.l10n;
  final b = StringBuffer();
  b.writeln('📋 ${l10n.partnerProfileTitle}');
  b.writeln('${l10n.partnerCodeBadgeLabel}${p.partnerCode}');
  b.writeln('${l10n.partnerNameLabel}: ${p.partnerName}');
  b.writeln('${l10n.partnerCategoriesLabel}: ${p.partnerType}');
  b.writeln('${l10n.countryDetailLabel}: ${p.country}');
  if (p.address != null && p.address!.isNotEmpty) b.writeln('${l10n.fullAddressDetailLabel}: ${p.address}');
  if (p.phone != null && p.phone!.isNotEmpty) b.writeln('${l10n.partnerPhoneLabel}: ${p.phone}');
  if (p.mobile != null && p.mobile!.isNotEmpty) b.writeln('${l10n.partnerMobileLabel}: ${p.mobile}');
  if (p.email != null && p.email!.isNotEmpty) b.writeln('${l10n.emailDetailLabel}: ${p.email}');
  if (p.website != null && p.website!.isNotEmpty) b.writeln('${l10n.websiteDetailLabel}: ${p.website}');
  if (p.swiftCode != null && p.swiftCode!.isNotEmpty) b.writeln('${l10n.partnerSwiftCodeDetailLabel}: ${p.swiftCode}');
  if (p.scacCode != null && p.scacCode!.isNotEmpty) b.writeln('${l10n.partnerScacCodeDetailLabel}: ${p.scacCode}');
  if (p.defaultFreeDays != null) b.writeln('${l10n.defaultFreeDaysLabel}: ${p.defaultFreeDays}');
  if (p.fiataId != null && p.fiataId!.isNotEmpty) b.writeln('${l10n.fiataLicenseLabel}: ${p.fiataId}');
  if (p.shippingModes != null && p.shippingModes!.isNotEmpty) b.writeln('${l10n.shippingModesLabel}: ${p.shippingModes}');
  if (p.supportedCurrencies != null && p.supportedCurrencies!.isNotEmpty) b.writeln('${l10n.supportedCurrenciesLabel}: ${p.supportedCurrencies}');
  if (p.inspectionAccreditationNumber != null && p.inspectionAccreditationNumber!.isNotEmpty) {
    b.writeln('${l10n.inspectionAccreditationNumLabel}: ${p.inspectionAccreditationNumber}');
  }
  if (p.inspectionScope != null && p.inspectionScope!.isNotEmpty) b.writeln('${l10n.inspectionScopeLabel}: ${p.inspectionScope}');
  if (p.clearanceLicenseNumber != null && p.clearanceLicenseNumber!.isNotEmpty) {
    b.writeln('${l10n.clearanceLicenseDetailLabel}: ${p.clearanceLicenseNumber}');
  }
  if (p.authorizedPorts != null && p.authorizedPorts!.isNotEmpty) b.writeln('${l10n.authorizedPortsLabel}: ${p.authorizedPorts}');
  if (p.transportLicenseNumber != null && p.transportLicenseNumber!.isNotEmpty) {
    b.writeln('${l10n.transportLicenseNumLabel}: ${p.transportLicenseNumber}');
  }
  if (p.fleetTypes != null && p.fleetTypes!.isNotEmpty) b.writeln('${l10n.fleetTypesLabel}: ${p.fleetTypes}');
  if (p.coverageAreas != null && p.coverageAreas!.isNotEmpty) b.writeln('${l10n.coverageAreasLabel}: ${p.coverageAreas}');
  if (p.insuranceLicenseNumber != null && p.insuranceLicenseNumber!.isNotEmpty) {
    b.writeln('${l10n.insuranceLicenseNumLabel}: ${p.insuranceLicenseNumber}');
  }
  if (p.insuranceCoverageTypes != null && p.insuranceCoverageTypes!.isNotEmpty) {
    b.writeln('${l10n.insuranceCoverageTypesLabel}: ${p.insuranceCoverageTypes}');
  }
  if (p.commercialRegister != null && p.commercialRegister!.isNotEmpty) {
    b.writeln('${l10n.commercialRegDetailLabel}: ${p.commercialRegister}');
  }
  if (p.taxId != null && p.taxId!.isNotEmpty) b.writeln('${l10n.taxIdDetailLabel}: ${p.taxId}');
  b.writeln('${l10n.partnerStatusCol}: ${p.isActive ? l10n.statusActive : l10n.statusInactive}');
  if (p.notes != null && p.notes!.isNotEmpty) b.writeln('${l10n.additionalNotesSection}: ${p.notes}');
  return b.toString().trim();
}

class PartnerActionsCell extends StatelessWidget {
  final PartnerModel partner;
  final void Function(PartnerModel) onEdit;
  final void Function(PartnerModel)? onView;
  final void Function(PartnerModel)? onStatementOfAccount;
  final void Function(PartnerModel)? onScorecard;
  final void Function(PartnerModel)? onPrint;
  final void Function(PartnerModel)? onToggleActive;

  const PartnerActionsCell({
    super.key,
    required this.partner,
    required this.onEdit,
    this.onView,
    this.onStatementOfAccount,
    this.onScorecard,
    this.onPrint,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isActive = partner.isActive;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onStatementOfAccount != null)
            Tooltip(
              message: l10n.partnerStatementOfAccountTooltip,
              child: InkWell(
                onTap: () => onStatementOfAccount!(partner),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.receipt_long, size: 14, color: AppTheme.cobalt),
                  ),
                ),
              ),
            ),
          if (partner.providerId != null && onScorecard != null)
            Tooltip(
              message: l10n.partnerScorecardTooltip,
              child: InkWell(
                onTap: () => onScorecard!(partner),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Icon(Icons.workspace_premium_outlined, size: 14, color: Colors.amber.shade800),
                  ),
                ),
              ),
            ),
          Tooltip(
            message: l10n.partnerCopySummaryBtn,
            child: InkWell(
              onTap: () => CopyHelper.copy(
                context,
                buildPartnerSummary(context, partner),
                customMessage: l10n.partnerCopySummarySuccess,
              ),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsetsDirectional.only(end: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.copy_all_rounded, size: 14, color: AppTheme.emerald),
                ),
              ),
            ),
          ),
          RowActionsPill(
            onView: onView != null ? () => onView!(partner) : null,
            onEdit: () => onEdit(partner),
            onPrint: onPrint != null ? () => onPrint!(partner) : null,
            onDelete: onToggleActive != null ? () => onToggleActive!(partner) : null,
            deleteTooltip: isActive ? l10n.deactivatePartnerTooltip : l10n.activatePartnerTooltip,
          ),
        ],
      ),
    );
  }
}
