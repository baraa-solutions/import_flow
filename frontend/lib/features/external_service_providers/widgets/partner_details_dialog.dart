import 'package:flutter/material.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/master_data_export_service.dart';
import '../models/partner_model.dart';
import 'partner_statement_of_account_dialog.dart';

class PartnerDetailsDialog extends StatelessWidget {
  final PartnerModel partner;
  final VoidCallback? onEdit;

  const PartnerDetailsDialog({
    super.key,
    required this.partner,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    PartnerModel partner, {
    VoidCallback? onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PartnerDetailsDialog(partner: partner, onEdit: onEdit),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = partner.isActive;
    final categories = partner.categoriesList;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
          width: 780,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header Banner ──────────────────────────────────────────
            Container(
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
                    child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: SelectableText(
                                partner.partnerCode,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                                  customMessage: l10n.copiedToClipboard(partner.partnerName),
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.copy_rounded, size: 15, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: l10n.partnerCopySummaryBtn,
                              child: InkWell(
                                onTap: () => CopyHelper.copy(
                                  context,
                                  _buildPartnerSummary(context, partner),
                                  customMessage: l10n.partnerCopySummarySuccess,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.copy_all_rounded, size: 15, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isActive ? AppTheme.emerald : AppTheme.crimson).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isActive ? AppTheme.emerald : AppTheme.crimson,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isActive ? l10n.statusActive : l10n.statusInactive,
                                style: TextStyle(
                                  color: isActive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
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
                          children: categories.map((c) => _buildCategoryChip(context, c)).toList(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                    tooltip: l10n.closeBtn,
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Professional Identifiers & Licenses
                    _buildSectionHeader(context, Icons.verified_outlined, l10n.professionalLicensesSection),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (partner.swiftCode != null && partner.swiftCode!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.partnerSwiftCodeDetailLabel,
                                    value: partner.swiftCode!,
                                    icon: Icons.flash_on_rounded,
                                    highlightColor: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.scacCode != null && partner.scacCode!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.partnerScacCodeDetailLabel,
                                    value: partner.scacCode!,
                                    icon: Icons.directions_boat_outlined,
                                    highlightColor: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.fiataId != null && partner.fiataId!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.fiataLicenseLabel,
                                    value: partner.fiataId!,
                                    icon: Icons.badge_rounded,
                                    highlightColor: isDark ? AppTheme.cobalt : AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.shippingModes != null && partner.shippingModes!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.shippingModesLabel,
                                    value: partner.shippingModes!,
                                    icon: Icons.alt_route_rounded,
                                    highlightColor: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.supportedCurrencies != null && partner.supportedCurrencies!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.supportedCurrenciesLabel,
                                    value: partner.supportedCurrencies!,
                                    icon: Icons.monetization_on_outlined,
                                    highlightColor: AppTheme.emerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.inspectionAccreditationNumber != null && partner.inspectionAccreditationNumber!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.inspectionAccreditationNumLabel,
                                    value: partner.inspectionAccreditationNumber!,
                                    icon: Icons.verified_user_outlined,
                                    highlightColor: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.inspectionScope != null && partner.inspectionScope!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.inspectionScopeLabel,
                                    value: partner.inspectionScope!,
                                    icon: Icons.rule_folder_outlined,
                                    highlightColor: AppTheme.emerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.clearanceLicenseNumber != null && partner.clearanceLicenseNumber!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.clearanceLicenseDetailLabel,
                                    value: partner.clearanceLicenseNumber!,
                                    icon: Icons.card_membership_rounded,
                                    highlightColor: AppTheme.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.authorizedPorts != null && partner.authorizedPorts!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.authorizedPortsLabel,
                                    value: partner.authorizedPorts!,
                                    icon: Icons.anchor_outlined,
                                    highlightColor: AppTheme.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.transportLicenseNumber != null && partner.transportLicenseNumber!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.transportLicenseNumLabel,
                                    value: partner.transportLicenseNumber!,
                                    icon: Icons.local_shipping_outlined,
                                    highlightColor: AppTheme.emerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.fleetTypes != null && partner.fleetTypes!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.fleetTypesLabel,
                                    value: partner.fleetTypes!,
                                    icon: Icons.rv_hookup,
                                    highlightColor: AppTheme.emerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.coverageAreas != null && partner.coverageAreas!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.coverageAreasLabel,
                                    value: partner.coverageAreas!,
                                    icon: Icons.map_outlined,
                                    highlightColor: AppTheme.emerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.insuranceLicenseNumber != null && partner.insuranceLicenseNumber!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.insuranceLicenseNumLabel,
                                    value: partner.insuranceLicenseNumber!,
                                    icon: Icons.verified_user_outlined,
                                    highlightColor: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (partner.insuranceCoverageTypes != null && partner.insuranceCoverageTypes!.isNotEmpty) ...[
                                Expanded(
                                  child: _buildCopyableInfoField(
                                    context: context,
                                    label: l10n.insuranceCoverageTypesLabel,
                                    value: partner.insuranceCoverageTypes!,
                                    icon: Icons.health_and_safety_outlined,
                                    highlightColor: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.commercialRegDetailLabel,
                                  value: partner.commercialRegister ?? '-',
                                  icon: Icons.account_balance_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCopyableInfoField(
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
                    const SizedBox(height: 18),

                    // Section 2: Credit Terms & Financial Conditions
                    _buildSectionHeader(context, Icons.payments_outlined, l10n.creditTermsSection),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.emerald.withValues(alpha: 0.1) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppTheme.emerald.withValues(alpha: 0.3) : const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleInfoField(
                                  context: context,
                                  label: l10n.paymentTermsDetailLabel,
                                  value: (partner.paymentTerms != null && partner.paymentTerms!.isNotEmpty)
                                      ? partner.paymentTerms!
                                      : partner.paymentType,
                                  icon: Icons.credit_score_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoField(
                                  context: context,
                                  label: l10n.creditLimitDetailLabel,
                                  value: '${partner.creditLimit.toStringAsFixed(2)} ${l10n.soaCurrencyEgp}',
                                  icon: Icons.monetization_on_outlined,
                                ),
                              ),
                              if (partner.defaultFreeDays != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSimpleInfoField(
                                    context: context,
                                    label: l10n.defaultFreeDaysLabel,
                                    value: l10n.partnerFreeDaysBadge(partner.defaultFreeDays!),
                                    icon: Icons.timer_outlined,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoField(
                                  context: context,
                                  label: l10n.ratingDetailLabel,
                                  value: '⭐ ${partner.rating.toStringAsFixed(1)} / 5.0',
                                  icon: Icons.star_rate_rounded,
                                ),
                              ),
                            ],
                          ),
                          if (partner.bankCode != null || partner.branchName != null) ...[
                            const Divider(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSimpleInfoField(
                                    context: context,
                                    label: l10n.bankCodeDetailLabel,
                                    value: partner.bankCode ?? '-',
                                    icon: Icons.account_balance,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSimpleInfoField(
                                    context: context,
                                    label: l10n.branchNameDetailLabel,
                                    value: partner.branchName ?? '-',
                                    icon: Icons.storefront_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 3: Contact & Address
                    _buildSectionHeader(context, Icons.contact_phone_outlined, l10n.contactAndAddressSection),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.contactPersonDetailLabel,
                                  value: partner.contactPerson ?? '-',
                                  icon: Icons.person_outline_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCopyableInfoField(
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
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.phoneMobileDetailLabel,
                                  value: partner.phone ?? partner.mobile ?? '-',
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCopyableInfoField(
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
                            _buildCopyableInfoField(
                              context: context,
                              label: l10n.fullAddressDetailLabel,
                              value: partner.address!,
                              icon: Icons.location_on_outlined,
                            ),
                          ],
                          if (partner.website != null && partner.website!.isNotEmpty) ...[
                            const Divider(height: 14),
                            _buildCopyableInfoField(
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
                      _buildSectionHeader(context, Icons.notes_rounded, l10n.additionalNotesSection),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.orange.withValues(alpha: 0.12) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.orange.withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          partner.notes!,
                          style: TextStyle(fontSize: 13, color: isDark ? AppTheme.orange : const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Action Toolbar (طباعة - حفظ PDF - تنزيل إكسل - واتس - إيميل - كشف حساب) ────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Left Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 1. Print / Save PDF
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.charcoal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: Text(l10n.printSavePdfBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await MasterDataExportService.printOrSavePartnerPdf(partner);
                        },
                      ),

                      // 2. Export Excel
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E7E34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.table_view_rounded, size: 16),
                        label: Text(l10n.downloadExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final path = await MasterDataExportService.exportPartnerToExcel(context, partner);
                          if (context.mounted && path != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.excelSavedSuccess(path)),
                                backgroundColor: AppTheme.emerald,
                              ),
                            );
                          }
                        },
                      ),

                      // 3. WhatsApp Share
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: Text(l10n.whatsappShareBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _showWhatsAppPreviewModal(context),
                      ),

                      // 4. Email Share
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 16),
                        label: Text(l10n.emailShareBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _showEmailPreviewModal(context),
                      ),

                      // 5. Statement of Account Shortcut
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cobalt,
                          side: const BorderSide(color: AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        label: Text(l10n.partnerStatementShortcutBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          PartnerStatementOfAccountDialog.show(context, partner);
                        },
                      ),
                    ],
                  ),

                  // Right Action Buttons: Edit & Close
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.charcoal,
                            side: const BorderSide(color: AppTheme.charcoal),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(l10n.editPartnerBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(context);
                            onEdit!();
                          },
                        ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.closeBtn, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(BuildContext context, String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.cobalt.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        _getCategoryLabel(context, category),
        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCopyableInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? highlightColor,
  }) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: highlightColor ?? Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: highlightColor ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      ),
                    ),
                  ),
                  if (value != '-' && value != 'غير مسجل')
                    Tooltip(
                      message: l10n.partnersCopyFieldTooltip,
                      child: InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          value,
                          customMessage: l10n.copiedToClipboard(value),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.copy, size: 13, color: Colors.grey),
                        ),
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

  Widget _buildSimpleInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showWhatsAppPreviewModal(BuildContext context) {
    final l10n = context.l10n;
    bool isArabic = l10n.isArabic;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final text = MasterDataExportService.generatePartnerWhatsAppText(partner, isArabic: isArabic);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.whatsappPreviewTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('عربي', style: TextStyle(fontSize: 11))),
                    ButtonSegment<bool>(value: false, label: Text('EN', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {isArabic},
                  onSelectionChanged: (newSelection) {
                    setModalState(() => isArabic = newSelection.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: SelectableText(
                      text,
                      style: const TextStyle(fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.closeBtn)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                label: Text(l10n.copyWhatsappTextBtn, style: const TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(ctx);
                  CopyHelper.copy(context, text, customMessage: l10n.whatsappCopiedSuccess);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEmailPreviewModal(BuildContext context) {
    final l10n = context.l10n;
    bool isArabic = l10n.isArabic;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final subject = MasterDataExportService.generatePartnerEmailSubject(partner, isArabic: isArabic);
          final body = MasterDataExportService.generatePartnerEmailBody(partner, isArabic: isArabic);

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.mail_outline_rounded, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.emailPreviewTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('عربي', style: TextStyle(fontSize: 11))),
                    ButtonSegment<bool>(value: false, label: Text('EN', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {isArabic},
                  onSelectionChanged: (newSelection) {
                    setModalState(() => isArabic = newSelection.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.emailSubjectPrefix(subject), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      body,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.closeBtn)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                label: Text(l10n.copyEmailTextBtn, style: const TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(ctx);
                  CopyHelper.copy(
                    context,
                    '${l10n.emailSubjectPrefix(subject)}\n\n$body',
                    customMessage: l10n.emailCopiedSuccess,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
