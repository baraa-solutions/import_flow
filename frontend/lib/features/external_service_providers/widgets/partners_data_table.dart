import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../models/partner_model.dart';
import 'table/partner_actions_cell.dart';
import 'table/partner_info_cells.dart';
import 'table/partner_registration_badges_cell.dart';

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
                                child: PartnerActionsCell(
                                  partner: partner,
                                  onEdit: onEdit,
                                  onView: onView,
                                  onStatementOfAccount: onStatementOfAccount,
                                  onScorecard: onScorecard,
                                  onPrint: onPrint,
                                  onToggleActive: onToggleActive,
                                ),
                              ),

                              // Code
                              _cell(
                                child: PartnerCodeCell(partnerCode: partner.partnerCode),
                              ),

                              // Partner Name & Categories
                              _cell(
                                child: PartnerNameCategoryCell(partner: partner),
                              ),

                              // Registration & Identifiers
                              _cell(
                                child: PartnerRegistrationBadgesCell(partner: partner),
                              ),

                              // Contact Details
                              _cell(
                                child: PartnerContactCell(partner: partner),
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
