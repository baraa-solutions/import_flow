import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class CustomsInspectionResultCards extends StatelessWidget {
  final String? selectedResult;
  final ValueChanged<String> onSelected;

  const CustomsInspectionResultCards({
    super.key,
    required this.selectedResult,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final results = <({String id, String label, String desc, AppSeverity severity, IconData icon})>[
      (
        id: 'Conforming',
        label: l.ccInsResConforming,
        desc: l.ccInsResConformingDesc,
        severity: AppSeverity.success,
        icon: Icons.check_circle_rounded,
      ),
      (
        id: 'Shortage',
        label: l.ccInsResShortage,
        desc: l.ccInsResShortageDesc,
        severity: AppSeverity.warning,
        icon: Icons.remove_circle_outline_rounded,
      ),
      (
        id: 'Surplus',
        label: l.ccInsResSurplus,
        desc: l.ccInsResSurplusDesc,
        severity: AppSeverity.info,
        icon: Icons.add_circle_outline_rounded,
      ),
      (
        id: 'Discrepancy',
        label: l.ccInsResDiscrepancy,
        desc: l.ccInsResDiscrepancyDesc,
        severity: AppSeverity.danger,
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: results.map((result) {
        final isSelected = selectedResult == result.id;
        final color = AppTheme.severityForegroundOf(context, result.severity);
        return Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onSelected(result.id),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Container(
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.severityBackgroundOf(context, result.severity)
                      : AppTheme.surfaceOf(context),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.borderOf(context),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          result.icon,
                          size: 18,
                          color: isSelected ? color : AppTheme.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            result.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : AppTheme.textPrimaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
