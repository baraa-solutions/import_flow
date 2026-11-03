import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../../shipment_updates/models/shipment_update_model.dart';

/// Standalone card showing recent daily check-in logs and updates.
class OperationalDailyCheckinsCard extends StatelessWidget {
  final List<ImportFileModel> shipments;
  final List<ShipmentUpdateLogModel> logs;
  final bool isArabic;
  final VoidCallback? onAddDailyUpdate;

  const OperationalDailyCheckinsCard({
    super.key,
    required this.shipments,
    required this.logs,
    this.isArabic = true,
    this.onAddDailyUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 460;
            final headerButton = onAddDailyUpdate != null
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: onAddDailyUpdate,
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: Text(
                      l.addDailyUpdate,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                : const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth,
                        child: Row(
                          children: [
                            Icon(Icons.published_with_changes, color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.dailyCheckinsLog,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                            ),
                          ],
                        ),
                      ),
                      headerButton,
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.published_with_changes, color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.dailyCheckinsLog,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                      ),
                      const SizedBox(width: 8),
                      headerButton,
                    ],
                  ),
                const SizedBox(height: 10),
                if (logs.isEmpty)
                  Text(l.noDailyUpdates, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : Colors.grey))
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double itemWidth = constraints.maxWidth < 280 ? constraints.maxWidth : 260.0;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: logs.take(5).map((log) {
                          return Container(
                            padding: const EdgeInsets.all(10),
                            width: itemWidth,
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : Colors.white,
                              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: CopyableText(
                                        DisplayNameResolver.resolveShipmentTitleByCode(
                                          log.importFileCode,
                                          shipments: shipments,
                                          isArabic: isArabic,
                                        ),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(log.logDate, style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                CopyableText(
                                  '${DisplayNameResolver.resolvePhaseName(log.targetPhase, isArabic: isArabic)} — ${DisplayNameResolver.resolveUpdateCategory(log.updateCategory, isArabic: isArabic)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                                const SizedBox(height: 4),
                                CopyableText(
                                  log.note,
                                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.black87),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
