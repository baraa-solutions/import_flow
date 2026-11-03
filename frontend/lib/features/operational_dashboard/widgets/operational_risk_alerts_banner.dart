import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../../smart_tasks/models/smart_task_model.dart';
import 'operational_format_helper.dart';

/// Standalone Risk Alerts Banner highlighting critical shipments & regulatory compliance tasks.
class OperationalRiskAlertsBanner extends StatelessWidget {
  final List<ImportFileModel> shipments;
  final List<SmartTaskModel> regTasks;
  final bool isArabic;

  const OperationalRiskAlertsBanner({
    super.key,
    required this.shipments,
    required this.regTasks,
    this.isArabic = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final criticals = shipments.where((s) => s.priority == 'Critical' || s.priority == 'High').toList();

    if (criticals.isEmpty && regTasks.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? Colors.amber.shade700.withValues(alpha: 0.5) : Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 460;
            final maxChipTextWidth = (constraints.maxWidth - 90).clamp(60.0, 320.0);

            final badgeWidget = regTasks.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3B1E22) : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rule_folder, size: 12, color: AppTheme.crimson),
                        const SizedBox(width: 4),
                        Text(
                          l.pendingRegRequirementsCount(regTasks.length),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade200 : AppTheme.crimson),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth,
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppTheme.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.riskAlertsCenter,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (regTasks.isNotEmpty) badgeWidget,
                    ],
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.orange, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.riskAlertsCenter,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                      ),
                      const SizedBox(width: 8),
                      badgeWidget,
                    ],
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...regTasks.take(3).map((t) {
                      final title = t.displayTitle(context.l10n);
                      return GestureDetector(
                        onDoubleTap: () => CopyHelper.copy(context, title),
                        onSecondaryTap: () => CopyHelper.copy(context, title),
                        child: Tooltip(
                          message: l.copyTooltip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF3B1E22) : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? Colors.red.shade800 : Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 14),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxChipTextWidth),
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade200 : AppTheme.crimson),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    ...criticals.take(3).map((s) {
                      final text = '${s.primaryNameWithCode} — ${s.displayStage(context.l10n, (t) => OperationalFormatHelper.formatStageName(t, isArabic: isArabic))}';
                      return GestureDetector(
                        onDoubleTap: () => CopyHelper.copy(context, text),
                        onSecondaryTap: () => CopyHelper.copy(context, text),
                        child: Tooltip(
                          message: l.copyTooltip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? AppTheme.darkBorderLight : Colors.amber.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning, color: AppTheme.orange, size: 14),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxChipTextWidth),
                                  child: Text(
                                    text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
