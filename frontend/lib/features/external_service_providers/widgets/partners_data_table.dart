import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../models/partner_model.dart';

/// جدول بيانات الشركاء ومقدمي الخدمات الموحد
class PartnersDataTable extends StatelessWidget {
  final List<PartnerModel> partners;
  final void Function(PartnerModel partner) onEdit;
  final void Function(PartnerModel partner)? onView;
  final void Function(PartnerModel partner)? onStatementOfAccount;
  final void Function(PartnerModel partner)? onScorecard;
  final void Function(PartnerModel partner)? onPrint;
  final void Function(PartnerModel partner)? onToggleActive;

  const PartnersDataTable({
    super.key,
    required this.partners,
    required this.onEdit,
    this.onView,
    this.onStatementOfAccount,
    this.onScorecard,
    this.onPrint,
    this.onToggleActive,
  });

  String _getCategoryLabel(BuildContext context, String cat) {
    final l10n = context.l10n;
    switch (cat) {
      case 'All':
        return l10n.partnerCatAll;
      case 'Bank':
        return l10n.partnerCatBank;
      case 'Shipping Line':
        return l10n.partnerCatShippingLine;
      case 'Customs Broker':
        return l10n.partnerCatCustomsBroker;
      case 'Freight Forwarder':
        return l10n.partnerCatFreightForwarder;
      case 'Inland Transport':
        return l10n.partnerCatInlandTransport;
      case 'Inspection Agency':
        return l10n.partnerCatInspectionAgency;
      case 'Insurance Company':
        return l10n.partnerCatInsuranceCompany;
      default:
        return cat;
    }
  }

  Widget _buildCategoryBadge(BuildContext context, String cat) {
    Color color;
    switch (cat) {
      case 'Bank':
        color = AppTheme.emerald;
        break;
      case 'Shipping Line':
        color = AppTheme.cobalt;
        break;
      case 'Customs Broker':
        color = AppTheme.orange;
        break;
      case 'Freight Forwarder':
        color = AppTheme.charcoal;
        break;
      default:
        color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        _getCategoryLabel(context, cat),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _buildPartnerSummary(BuildContext context, PartnerModel p) {
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
    if (p.inspectionAccreditationNumber != null && p.inspectionAccreditationNumber!.isNotEmpty) b.writeln('${l10n.inspectionAccreditationNumLabel}: ${p.inspectionAccreditationNumber}');
    if (p.inspectionScope != null && p.inspectionScope!.isNotEmpty) b.writeln('${l10n.inspectionScopeLabel}: ${p.inspectionScope}');
    if (p.clearanceLicenseNumber != null && p.clearanceLicenseNumber!.isNotEmpty) b.writeln('${l10n.clearanceLicenseDetailLabel}: ${p.clearanceLicenseNumber}');
    if (p.authorizedPorts != null && p.authorizedPorts!.isNotEmpty) b.writeln('${l10n.authorizedPortsLabel}: ${p.authorizedPorts}');
    if (p.transportLicenseNumber != null && p.transportLicenseNumber!.isNotEmpty) b.writeln('${l10n.transportLicenseNumLabel}: ${p.transportLicenseNumber}');
    if (p.fleetTypes != null && p.fleetTypes!.isNotEmpty) b.writeln('${l10n.fleetTypesLabel}: ${p.fleetTypes}');
    if (p.coverageAreas != null && p.coverageAreas!.isNotEmpty) b.writeln('${l10n.coverageAreasLabel}: ${p.coverageAreas}');
    if (p.insuranceLicenseNumber != null && p.insuranceLicenseNumber!.isNotEmpty) b.writeln('${l10n.insuranceLicenseNumLabel}: ${p.insuranceLicenseNumber}');
    if (p.insuranceCoverageTypes != null && p.insuranceCoverageTypes!.isNotEmpty) b.writeln('${l10n.insuranceCoverageTypesLabel}: ${p.insuranceCoverageTypes}');
    if (p.commercialRegister != null && p.commercialRegister!.isNotEmpty) b.writeln('${l10n.commercialRegDetailLabel}: ${p.commercialRegister}');
    if (p.taxId != null && p.taxId!.isNotEmpty) b.writeln('${l10n.taxIdDetailLabel}: ${p.taxId}');
    b.writeln('${l10n.partnerStatusCol}: ${p.isActive ? l10n.statusActive : l10n.statusInactive}');
    if (p.notes != null && p.notes!.isNotEmpty) b.writeln('${l10n.additionalNotesSection}: ${p.notes}');
    return b.toString().trim();
  }

  Widget _cell({required Widget child}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 1200 ? 1200.0 : constraints.maxWidth;

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderOf(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: const {
                        0: FixedColumnWidth(235),
                        1: FixedColumnWidth(140),
                        2: FlexColumnWidth(3.0),
                        3: FlexColumnWidth(2.6),
                        4: FlexColumnWidth(2.2),
                        5: FixedColumnWidth(100),
                      },
                      children: [
                        // Table Header
                        TableRow(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal,
                          ),
                          children: [
                            l10n.partnerActionsCol,
                            l10n.partnerCodeCol,
                            l10n.partnerNameAndCategoryCol,
                            l10n.registrationAndLicenseCol,
                            l10n.contactDetailsCol,
                            l10n.partnerStatusCol,
                          ]
                              .map(
                                (h) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  child: Text(
                                    h,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),

                        // Table Data Rows
                        ...partners.asMap().entries.map((entry) {
                          final partner = entry.value;
                          final isEven = entry.key % 2 == 0;
                          final isActive = partner.isActive;
                          final categories = partner.categoriesList;

                          return TableRow(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (isEven ? AppTheme.darkElevatedSurface : AppTheme.darkCardBackground)
                                  : (isEven ? AppTheme.surfaceOf(context) : Colors.grey.shade50),
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                                ),
                              ),
                            ),
                            children: [
                              // Actions
                              _cell(
                                child: SingleChildScrollView(
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
                                            _buildPartnerSummary(context, partner),
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
                                ),
                              ),

                              // Code
                              _cell(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Tooltip(
                                    message: '${l10n.partnerCodeBadgeLabel}${partner.partnerCode} (${l10n.partnersCopyFieldTooltip})',
                                    child: InkWell(
                                      onTap: () => CopyHelper.copy(
                                        context,
                                        partner.partnerCode,
                                        customMessage: l10n.copiedToClipboard(partner.partnerCode),
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withValues(alpha: 0.15),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              partner.partnerCode,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                letterSpacing: 0.3,
                                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.copy_rounded,
                                              size: 11,
                                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Partner Name & Categories
                              _cell(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            partner.partnerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isActive
                                                  ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)
                                                  : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                                              decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Tooltip(
                                          message: l10n.partnersCopyFieldTooltip,
                                          child: InkWell(
                                            onTap: () => CopyHelper.copy(
                                              context,
                                              partner.partnerName,
                                              customMessage: l10n.copiedToClipboard(partner.partnerName),
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                            child: const Padding(
                                              padding: EdgeInsets.all(2.0),
                                              child: Icon(Icons.copy_rounded, size: 13, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: categories.map((cat) => _buildCategoryBadge(context, cat)).toList(),
                                    ),
                                  ],
                                ),
                              ),

                              // Registration & Identifiers
                              _cell(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (partner.swiftCode != null && partner.swiftCode!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.account_balance_outlined, size: 12, color: AppTheme.cobalt),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerSwiftLabel(partner.swiftCode!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.scacCode != null && partner.scacCode!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.directions_boat_outlined, size: 12, color: AppTheme.cobalt),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerScacLabel(partner.scacCode!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.defaultFreeDays != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 12, color: AppTheme.emerald),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerFreeDaysBadge(partner.defaultFreeDays!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.fiataId != null && partner.fiataId!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.badge_rounded, size: 12, color: isDark ? AppTheme.cobalt : AppTheme.charcoal),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerFiataBadge(partner.fiataId!),
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.cobalt : AppTheme.charcoal),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.shippingModes != null && partner.shippingModes!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.alt_route_rounded, size: 12, color: AppTheme.cobalt),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                partner.shippingModes!,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.cobalt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.supportedCurrencies != null && partner.supportedCurrencies!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.monetization_on_outlined, size: 12, color: AppTheme.emerald),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                partner.supportedCurrencies!,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.inspectionAccreditationNumber != null && partner.inspectionAccreditationNumber!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified_user_outlined, size: 12, color: AppTheme.cobalt),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerAccreditationBadge(partner.inspectionAccreditationNumber!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.inspectionScope != null && partner.inspectionScope!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.rule_folder_outlined, size: 12, color: AppTheme.emerald),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                partner.inspectionScope!,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.emerald),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.clearanceLicenseNumber != null && partner.clearanceLicenseNumber!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.assignment_ind_outlined, size: 12, color: AppTheme.orange),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerLicenseLabel(partner.clearanceLicenseNumber!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.authorizedPorts != null && partner.authorizedPorts!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.anchor_outlined, size: 12, color: AppTheme.orange),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerPortsBadge(partner.authorizedPorts!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.orange),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.transportLicenseNumber != null && partner.transportLicenseNumber!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.local_shipping_outlined, size: 12, color: AppTheme.cobalt),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerLicenseLabel(partner.transportLicenseNumber!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.fleetTypes != null && partner.fleetTypes!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.fire_truck_outlined, size: 12, color: AppTheme.cobalt),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerFleetBadge(partner.fleetTypes!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.cobalt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.coverageAreas != null && partner.coverageAreas!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.map_outlined, size: 12, color: AppTheme.emerald),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerCoverageBadge(partner.coverageAreas!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.emerald),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.insuranceLicenseNumber != null && partner.insuranceLicenseNumber!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified_user_outlined, size: 12, color: AppTheme.cobalt),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerLicenseLabel(partner.insuranceLicenseNumber!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.insuranceCoverageTypes != null && partner.insuranceCoverageTypes!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.health_and_safety_outlined, size: 12, color: AppTheme.cobalt),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerInsuranceCoverageBadge(partner.insuranceCoverageTypes!),
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.cobalt),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.commercialRegister != null && partner.commercialRegister!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.description_outlined, size: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                l10n.partnerRegLabel(partner.commercialRegister!),
                                                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (partner.taxId != null && partner.taxId!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.receipt_long, size: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                '${l10n.partnerTaxIdLabel}: ${partner.taxId}',
                                                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Contact Details
                              _cell(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (partner.email != null && partner.email!.isNotEmpty)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.email_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              partner.email!,
                                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (partner.phone != null && partner.phone!.isNotEmpty)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              partner.phone!,
                                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(l10n.noPhoneLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),

                              // Status
                              _cell(
                                child: AppStatusBadge(
                                  label: isActive ? l10n.statusActive : l10n.statusInactive,
                                  severity: isActive ? AppSeverity.success : AppSeverity.danger,
                                  size: AppStatusBadgeSize.small,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
