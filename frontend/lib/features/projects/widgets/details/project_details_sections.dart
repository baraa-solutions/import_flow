import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/project_model.dart';
import 'project_audit_history_view.dart';
import 'project_details_formatters.dart';

class ProjectDetailsSections extends StatelessWidget {
  final ProjectModel project;

  const ProjectDetailsSections({super.key, required this.project});

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

  Widget _buildInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? highlightColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: highlightColor ?? (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: highlightColor ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Overview & Stakeholders
          _buildSectionHeader(
            context,
            Icons.business_center_outlined,
            isArabic ? 'بيانات المشروع والشركاء' : 'Project Details & Stakeholders',
          ),
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
                      child: _buildInfoField(
                        context: context,
                        label: l10n.importingCompaniesFieldLabel.replaceAll('*', '').trim(),
                        value: project.companyName ?? '—',
                        icon: Icons.domain,
                        highlightColor: AppTheme.cobalt,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoField(
                        context: context,
                        label: l10n.primarySupplierLabel.replaceAll('*', '').trim(),
                        value: project.supplierName ?? '—',
                        icon: Icons.flight_takeoff_rounded,
                        highlightColor: AppTheme.emerald,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoField(
                        context: context,
                        label: l10n.defaultIncotermLabel.replaceAll('*', '').trim(),
                        value: project.incotermCode ?? l10n.projectIncotermFallback,
                        icon: Icons.handshake_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoField(
                        context: context,
                        label: l10n.projectColShipmentCategories,
                        value: project.shipmentCategory
                            .split(',')
                            .map((c) => ProjectDetailsFormatters.getCategoryLabel(context, c))
                            .join(', '),
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoField(
                        context: context,
                        label: isArabic ? 'أوامر الشراء' : 'Purchase Orders',
                        value: '${project.poCount ?? 0}',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section 2: Budget & Financial Performance
          _buildSectionHeader(
            context,
            Icons.account_balance_wallet_outlined,
            isArabic ? 'الموازنة والتحليل المالي' : 'Budget & Financial Analysis',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.emerald.withValues(alpha: 0.08) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.emerald.withValues(alpha: 0.3) : const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoField(
                        context: context,
                        label: l10n.budgetUsdCol,
                        value: project.totalBudgetUsd != null
                            ? '${project.budgetCurrency} ${project.totalBudgetUsd!.toStringAsFixed(2)}'
                            : l10n.projectBudgetNotSet,
                        icon: Icons.monetization_on_outlined,
                        highlightColor: AppTheme.cobalt,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoField(
                        context: context,
                        label: isArabic ? 'الالتزامات والارتباطات' : 'Committed Budget',
                        value: project.totalCommittedUsd != null
                            ? '${project.budgetCurrency} ${project.totalCommittedUsd!.toStringAsFixed(2)}'
                            : '0.00 ${project.budgetCurrency}',
                        icon: Icons.lock_clock_outlined,
                        highlightColor: AppTheme.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoField(
                        context: context,
                        label: isArabic ? 'المتبقي من الموازنة' : 'Remaining Budget',
                        value: project.remainingBudgetUsd != null
                            ? '${project.budgetCurrency} ${project.remainingBudgetUsd!.toStringAsFixed(2)}'
                            : (project.totalBudgetUsd != null
                                ? '${project.budgetCurrency} ${project.totalBudgetUsd!.toStringAsFixed(2)}'
                                : '—'),
                        icon: Icons.savings_outlined,
                        highlightColor: AppTheme.emerald,
                      ),
                    ),
                  ],
                ),
                if (project.budgetUtilizationPercent != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        '${isArabic ? "نسبة استهلاك الموازنة" : "Budget Utilization"}: ${(project.budgetUtilizationPercent! * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: project.budgetUtilizationPercent!.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade300,
                            color: project.budgetUtilizationPercent! > 0.9
                                ? AppTheme.crimson
                                : (project.budgetUtilizationPercent! > 0.75 ? AppTheme.orange : AppTheme.emerald),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section 3: Timeline & Schedule
          _buildSectionHeader(
            context,
            Icons.event_note_outlined,
            isArabic ? 'الجدول الزمني والملاحظات' : 'Schedule & Notes',
          ),
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
                      child: _buildInfoField(
                        context: context,
                        label: l10n.targetEndDateLabel,
                        value: project.targetEndDate ?? '—',
                        icon: Icons.calendar_today_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoField(
                        context: context,
                        label: isArabic ? 'تاريخ الإنشاء' : 'Created Date',
                        value: project.createdAt != null
                            ? project.createdAt!.toLocal().toString().split(' ').first
                            : '—',
                        icon: Icons.history_toggle_off,
                      ),
                    ),
                  ],
                ),
                if (project.notes != null && project.notes!.isNotEmpty) ...[
                  const Divider(height: 18),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${l10n.projectNotesLabel}: ${project.notes}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Change History & Audit Trail
          _buildSectionHeader(context, Icons.history_edu_rounded, l10n.rowHistoryDialogTitle),
          const SizedBox(height: 10),
          ProjectAuditHistoryView(project: project),
        ],
      ),
    );
  }
}
