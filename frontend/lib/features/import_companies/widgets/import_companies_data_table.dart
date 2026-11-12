import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/import_company_model.dart';
import 'import_companies_filter_toolbar.dart';

/// جدول وقائمة الشركات المستوردة الموحدة
class ImportCompaniesDataTable extends StatelessWidget {
  final List<ImportCompanyModel> companies;
  final void Function(ImportCompanyModel company) onView;
  final void Function(ImportCompanyModel company) onEdit;
  final void Function(ImportCompanyModel company) onPrint;
  final void Function(ImportCompanyModel company) onToggleActive;
  final void Function(ImportCompanyModel company) onHistory;

  const ImportCompaniesDataTable({
    super.key,
    required this.companies,
    required this.onView,
    required this.onEdit,
    required this.onPrint,
    required this.onToggleActive,
    required this.onHistory,
  });

  Widget _buildExpiryBadge(BuildContext context, int daysLeft, String label) {
    final l10n = context.l10n;
    Color bg;
    Color fg;
    String statusText;

    if (daysLeft < 0) {
      bg = AppTheme.crimson.withValues(alpha: 0.15);
      fg = AppTheme.crimson;
      statusText = l10n.expiryExpired;
    } else if (daysLeft <= 30) {
      bg = AppTheme.orange.withValues(alpha: 0.15);
      fg = AppTheme.orange;
      statusText = l10n.expiryDaysLeft(daysLeft);
    } else {
      bg = AppTheme.emerald.withValues(alpha: 0.15);
      fg = AppTheme.emerald;
      statusText = l10n.expiryValidDays(daysLeft);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        '$label: $statusText',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCopyableIdBadge({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.cobalt),
          const SizedBox(width: 4),
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
          if (value.isNotEmpty && value != '-') ...[
            const SizedBox(width: 4),
            Tooltip(
              message: '${l10n.importCompaniesCopyFieldTooltip}: $label',
              child: InkWell(
                onTap: () => CopyHelper.copy(context, value),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyRow(BuildContext context, ImportCompanyModel company) {
    final l10n = context.l10n;
    final isActive = company.isActive;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        RowContextMenuHelper.showContextMenu(
          context: context,
          globalPosition: details.globalPosition,
          codeToCopy: company.importerId,
          onView: () => onView(company),
          onEdit: () => onEdit(company),
          onHistory: () => onHistory(company),
          isActive: isActive,
          onToggleActive: () => onToggleActive(company),
        );
      },
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              // Quick Copy Summary Button
              Tooltip(
                message: l10n.importCompanyCopySummaryBtn,
                child: IconButton(
                  icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
                  onPressed: () {
                    final summary = ImportCompaniesFilterToolbar.buildCompanySummary(context, company);
                    CopyHelper.copy(context, summary, customMessage: l10n.importCompanyCopySummarySuccess);
                  },
                ),
              ),
              const SizedBox(width: 4),

              // Standard 4-Action Row Pill: View, Edit, Print, Delete
              RowActionsPill(
                onView: () => onView(company),
                onEdit: () => onEdit(company),
                onPrint: () => onPrint(company),
                onDelete: () => onToggleActive(company),
                deleteTooltip: isActive ? l10n.deactivateCompanyTooltip : l10n.activateCompanyTooltip,
              ),
              const SizedBox(width: 8),
              // Icon Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isActive ? AppTheme.cobalt : Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.business, color: isActive ? AppTheme.cobalt : Colors.grey),
              ),
              const SizedBox(width: 16),

              // Name & Status Badge
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: SelectableText(
                            company.importerName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isActive ? AppTheme.charcoal : Colors.grey.shade700,
                              decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: l10n.importCompaniesCopyFieldTooltip,
                          child: InkWell(
                            onTap: () => CopyHelper.copy(context, company.importerName),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Active/Deactive Badge
                        AppStatusBadge(
                          label: isActive ? l10n.statusActive : l10n.statusInactive,
                          severity: isActive ? AppSeverity.success : AppSeverity.danger,
                          size: AppStatusBadgeSize.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildCopyableIdBadge(
                          context: context,
                          label: l10n.importerCardIdLabelShort,
                          value: company.importerId,
                          icon: Icons.badge_outlined,
                        ),
                        _buildCopyableIdBadge(
                          context: context,
                          label: l10n.vatTaxIdLabelShort,
                          value: company.vatId,
                          icon: Icons.receipt_long_outlined,
                        ),
                        _buildCopyableIdBadge(
                          context: context,
                          label: l10n.commercialRegLabelShort,
                          value: company.registrationNumber,
                          icon: Icons.app_registration_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Expiry Cards
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildExpiryBadge(context, company.daysUntilImporterIdExpiry, l10n.badgeImportId),
                    const SizedBox(height: 4),
                    _buildExpiryBadge(context, company.daysUntilVatExpiry, l10n.badgeVatExpiry),
                    const SizedBox(height: 4),
                    _buildExpiryBadge(context, company.daysUntilRegExpiry, l10n.badgeComReg),
                    if (company.soonestCertificateExpiry != null) ...[
                      const SizedBox(height: 4),
                      CertificateExpiryBadge(
                        key: ValueKey('companyCertExpiry_${company.companyId}'),
                        expiry: company.soonestCertificateExpiry,
                        isArabic: Localizations.localeOf(context).languageCode == 'ar',
                        prefix: Localizations.localeOf(context).languageCode == 'ar' ? 'الشهادات' : 'Certificates',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: companies.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return _buildCompanyRow(context, companies[index]);
          },
        ),
      ),
    );
  }
}
