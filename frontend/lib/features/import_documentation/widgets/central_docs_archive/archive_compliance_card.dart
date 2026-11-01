import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class ArchiveComplianceCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const ArchiveComplianceCard({
    super.key,
    required this.data,
  });

  Widget _buildComplianceChip(
    BuildContext context, {
    required String label,
    required String statusText,
    required bool isRequired,
    required IconData icon,
  }) {
    final bg = isRequired ? AppTheme.severityBackgroundOf(context, AppSeverity.info) : AppTheme.severityBackgroundOf(context, AppSeverity.success);
    final border = isRequired ? AppTheme.cobaltBorder : AppTheme.emeraldBorder;
    final fg = isRequired ? AppTheme.severityForegroundOf(context, AppSeverity.info) : AppTheme.severityForegroundOf(context, AppSeverity.success);

    return InkWell(
      onTap: () => CopyHelper.copy(context, '$label: $statusText'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label: $statusText',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.copy_rounded, size: 12, color: fg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reqSummary = data['import_requirements_summary'] as Map<String, dynamic>? ?? {};
    final tariffAlert = data['tariff_exemption_alert']?.toString();
    final goeicAlert = data['goeic_inspection_alert']?.toString();
    final decreeAlert = data['decree_43_alert']?.toString();

    final hsCode = reqSummary['hs_code']?.toString() ?? 'N/A';
    final commodity = reqSummary['commodity_description']?.toString() ?? '';
    final origin = reqSummary['country_of_origin']?.toString() ?? '';
    final cooRequired = reqSummary['coo_required'] as bool? ?? false;
    final cooType = reqSummary['coo_type']?.toString() ?? 'Standard COO';
    final inspRequired = reqSummary['inspection_required'] as bool? ?? false;
    final inspAgency = reqSummary['inspection_body']?.toString() ?? 'COTECNA / SGS';
    final decree43 = reqSummary['decree_43_applicable'] as bool? ?? false;
    final whiteList = reqSummary['white_list_verified'] as bool? ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.rule_folder, color: AppTheme.cobalt, size: 20),
                    ),
                    Text(
                      l10n.complianceReportHeader,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => CopyHelper.copy(
                    context,
                    l10n.complianceSummaryTag(origin.isNotEmpty ? origin : 'N/A', hsCode, commodity.isNotEmpty ? commodity : 'N/A'),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.emeraldBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.complianceSummaryTag(origin.isNotEmpty ? origin : 'N/A', hsCode, commodity.isNotEmpty ? commodity : 'N/A'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.severityForegroundOf(context, AppSeverity.success)),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 13, color: AppTheme.severityForegroundOf(context, AppSeverity.success)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (tariffAlert != null && tariffAlert.isNotEmpty) ...[
              InkWell(
                onTap: () => CopyHelper.copy(context, tariffAlert),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.orange, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: AppTheme.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tariffAlert,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy_rounded, size: 15, color: AppTheme.charcoal),
                    ],
                  ),
                ),
              ),
            ],
            if (goeicAlert != null && goeicAlert.isNotEmpty) ...[
              InkWell(
                onTap: () => CopyHelper.copy(context, goeicAlert),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cobaltBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: AppTheme.cobalt, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          goeicAlert,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.severityForegroundOf(context, AppSeverity.info)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_rounded, size: 15, color: AppTheme.severityForegroundOf(context, AppSeverity.info)),
                    ],
                  ),
                ),
              ),
            ],
            if (decreeAlert != null && decreeAlert.isNotEmpty) ...[
              InkWell(
                onTap: () => CopyHelper.copy(context, decreeAlert),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cobaltBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.domain_verification, color: AppTheme.wcagCobalt, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          decreeAlert,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.severityForegroundOf(context, AppSeverity.info)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_rounded, size: 15, color: AppTheme.severityForegroundOf(context, AppSeverity.info)),
                    ],
                  ),
                ),
              ),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildComplianceChip(
                  context,
                  label: l10n.chipCooLabel,
                  statusText: cooRequired ? l10n.cooRequiredText(cooType) : l10n.cooNotRequiredText,
                  isRequired: cooRequired,
                  icon: Icons.public,
                ),
                _buildComplianceChip(
                  context,
                  label: l10n.chipVocLabel,
                  statusText: inspRequired ? l10n.inspRequiredText(inspAgency) : l10n.inspNotRequiredText,
                  isRequired: inspRequired,
                  icon: Icons.security,
                ),
                _buildComplianceChip(
                  context,
                  label: l10n.chipDecree43Label,
                  statusText: decree43 ? (whiteList ? l10n.decree43WhiteListed : l10n.decree43RegistrationRequired) : l10n.decree43NotApplicable,
                  isRequired: decree43 && !whiteList,
                  icon: Icons.factory,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
