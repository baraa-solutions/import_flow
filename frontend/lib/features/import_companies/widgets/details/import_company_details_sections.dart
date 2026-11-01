import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/import_company_model.dart';

class ImportCompanyDetailsSections extends StatelessWidget {
  final ImportCompanyModel company;

  const ImportCompanyDetailsSections({
    super.key,
    required this.company,
  });

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        SelectableText(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required DateTime expiryDate,
    required int daysRemaining,
  }) {
    final l10n = context.l10n;
    final isExpired = daysRemaining <= 0;
    final isWarning = daysRemaining > 0 && daysRemaining <= 30;

    Color badgeBg = AppTheme.emerald.withValues(alpha: 0.12);
    Color badgeColor = AppTheme.emerald;
    String statusText = l10n.expiryValidDaysRemaining(daysRemaining);

    if (isExpired) {
      badgeBg = AppTheme.crimson.withValues(alpha: 0.12);
      badgeColor = AppTheme.crimson;
      statusText = l10n.expiryExpired;
    } else if (isWarning) {
      badgeBg = AppTheme.orange.withValues(alpha: 0.15);
      badgeColor = AppTheme.orange;
      statusText = l10n.expiryEndingSoon(daysRemaining);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Row(
                children: [
                  SelectableText(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: '${l10n.importCompaniesCopyFieldTooltip}: $label',
                    child: InkWell(
                      onTap: () => CopyHelper.copy(context, value),
                      child: const Icon(Icons.copy, size: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(
              l10n.expiryDateLabel(expiryDate.toIso8601String().split('T')[0]),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                statusText,
                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleInfoRow(BuildContext context, IconData icon, String label, String value) {
    final l10n = context.l10n;
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 1),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                    ),
                  ),
                  if (value != '-')
                    Tooltip(
                      message: '${l10n.importCompaniesCopyFieldTooltip}: $label',
                      child: InkWell(
                        onTap: () => CopyHelper.copy(context, value),
                        child: const Icon(Icons.copy, size: 13, color: Colors.grey),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isArabic = l10n.isArabic;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Official Identifiers & Registrations
          _buildSectionHeader(Icons.verified_user_rounded, l10n.officialRegistrationsHeader),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  context: context,
                  icon: Icons.badge_outlined,
                  label: l10n.importerCardIdRowLabel,
                  value: company.importerId,
                  expiryDate: company.importerIdExpiry,
                  daysRemaining: company.daysUntilImporterIdExpiry,
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  context: context,
                  icon: Icons.receipt_long_outlined,
                  label: l10n.vatTaxIdRowLabel,
                  value: company.vatId,
                  expiryDate: company.vatIdExpiry,
                  daysRemaining: company.daysUntilVatExpiry,
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  context: context,
                  icon: Icons.account_balance_outlined,
                  label: l10n.commercialRegRowLabel,
                  value: company.registrationNumber,
                  expiryDate: company.registrationExpiry,
                  daysRemaining: company.daysUntilRegExpiry,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section 2: Address & Contact Details
          _buildSectionHeader(Icons.location_on_outlined, l10n.locationAndContactHeader),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildSimpleInfoRow(
                  context,
                  Icons.public,
                  l10n.countryRowLabel,
                  company.country.isNotEmpty ? company.country : l10n.egyptCountryFallback,
                ),
                const Divider(height: 14),
                _buildSimpleInfoRow(context, Icons.home_outlined, l10n.addressRowLabel, company.address),
                const Divider(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildSimpleInfoRow(context, Icons.phone_outlined, l10n.phoneRowLabel, company.phone ?? '-'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.smartphone,
                        l10n.importCompaniesMobileLabel,
                        company.mobileNumber ?? '-',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSimpleInfoRow(context, Icons.print, l10n.importCompaniesFaxLabel, company.faxNumber ?? '-'),
                    ),
                  ],
                ),
                const Divider(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.email_outlined,
                        isArabic ? 'البريد الأساسي' : 'Primary Email',
                        company.primaryEmail ?? company.email ?? '-',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.mark_email_read_outlined,
                        isArabic ? 'البريد الثانوي' : 'Secondary Email',
                        company.secondaryEmail ?? '-',
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.language,
                        l10n.importCompaniesWebsiteLabel,
                        company.website ?? '-',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.vpn_key_rounded,
                        l10n.importCompaniesNafezaTokenLabel,
                        company.maskedNafezaToken ?? (company.hasNafezaToken ? '****' : '-'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section 3: Trademark & Quality Certificates
          _buildSectionHeader(Icons.verified_rounded, l10n.importCompaniesCertificatesSection),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.verified_outlined,
                        'WIPO Madrid Monitor',
                        company.hasWipo
                            ? (company.wipoNumber != null && company.wipoNumber!.isNotEmpty
                                ? (isArabic ? 'مسجل (#${company.wipoNumber})' : 'Registered (#${company.wipoNumber})')
                                : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                            : (isArabic ? 'غير مسجل' : 'Not Registered'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.verified_outlined,
                        isArabic ? 'مكتب الملكية الفكرية الأوروبي (EUIPO)' : 'EUIPO',
                        company.hasEuipo
                            ? (company.euipoNumber != null && company.euipoNumber!.isNotEmpty
                                ? (isArabic ? 'مسجل (#${company.euipoNumber})' : 'Registered (#${company.euipoNumber})')
                                : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                            : (isArabic ? 'غير مسجل' : 'Not Registered'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.public,
                        'Global Brand Database',
                        company.hasGlobalBrand
                            ? (company.globalBrandNumber != null && company.globalBrandNumber!.isNotEmpty
                                ? (isArabic ? 'مسجل (#${company.globalBrandNumber})' : 'Registered (#${company.globalBrandNumber})')
                                : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                            : (isArabic ? 'غير مسجل' : 'Not Registered'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSimpleInfoRow(
                        context,
                        Icons.workspace_premium_outlined,
                        isArabic ? 'شهادة آيزو 9001' : 'ISO 9001 Certificate',
                        company.hasIso9001
                            ? (company.iso9001Number != null && company.iso9001Number!.isNotEmpty
                                ? (isArabic ? 'معتمد (#${company.iso9001Number})' : 'Certified (#${company.iso9001Number})')
                                : (isArabic ? 'نعم (معتمد)' : 'Yes (Certified)'))
                            : (isArabic ? 'غير معتمد' : 'Not Certified'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (company.notes != null && company.notes!.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildSectionHeader(Icons.notes_rounded, l10n.administrativeNotesHeader),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      company.notes!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: l10n.importCompaniesCopyFieldTooltip,
                    child: InkWell(
                      onTap: () => CopyHelper.copy(context, company.notes!),
                      child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
