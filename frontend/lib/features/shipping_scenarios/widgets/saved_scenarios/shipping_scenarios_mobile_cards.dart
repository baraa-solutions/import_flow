import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/row_actions_pill.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/shipping_scenario_model.dart';

class ShippingScenariosMobileCards extends StatelessWidget {
  final List<ShippingEvaluationModel> sessions;
  final List<ImportFileModel> importFiles;
  final void Function(ShippingEvaluationModel sess) onView;
  final void Function(ShippingEvaluationModel sess) onEdit;
  final void Function(ShippingEvaluationModel sess) onClone;
  final void Function(ShippingEvaluationModel sess) onPrint;
  final void Function(ShippingEvaluationModel sess) onDeleteOrRestore;

  const ShippingScenariosMobileCards({
    super.key,
    required this.sessions,
    required this.importFiles,
    required this.onView,
    required this.onEdit,
    required this.onClone,
    required this.onPrint,
    required this.onDeleteOrRestore,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 24),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final sess = sessions[index];
        final rawFileCode =
            sess.importFileCode ?? (sess.importFileId != null ? 'IMP-${sess.importFileId}' : null);
        final shipmentTitle = (rawFileCode != null && rawFileCode != '—')
            ? DisplayNameResolver.resolveShipmentTitleByCode(
                rawFileCode,
                shipments: importFiles,
                isArabic: isArabic,
              )
            : null;

        return Card(
          elevation: 2,
          color: !sess.isActive
              ? (AppTheme.crimsonLight)
              : (isDark ? AppTheme.darkCardBackground : AppTheme.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: !sess.isActive
                  ? AppTheme.crimson.withValues(alpha: 0.4)
                  : (isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Icon + Code + Active Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.cobalt.withValues(alpha: 0.15),
                      child: const Icon(Icons.alt_route, color: AppTheme.cobalt, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CopyableText(
                        sess.sessionCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.cobalt,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppStatusBadge(
                      label: sess.isActive ? l.activeStatus : context.l10n.ssInactive,
                      severity: sess.isActive ? AppSeverity.success : AppSeverity.danger,
                      size: AppStatusBadgeSize.small,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                if (sess.title != null && sess.title!.isNotEmpty) ...[
                  Text(
                    sess.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Linked Import File / PO
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (rawFileCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '📁 $rawFileCode${shipmentTitle != null ? " ($shipmentTitle)" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.cobalt,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (sess.poNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'PO: ${sess.poNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.emerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Metrics wrap: Options count, Transit, WH Date, Recommended Carrier
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkInputBackground : AppTheme.charcoal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l.optionsCount(sess.items.length),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                        ),
                      ),
                    ),
                    if (sess.avgExpectedTransitDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⏱️ ${sess.avgExpectedTransitDays.toStringAsFixed(1)} d',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cobalt,
                          ),
                        ),
                      ),
                    if (sess.recommendedScenarioProvider != null &&
                        sess.recommendedScenarioProvider!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '⭐ ${sess.recommendedScenarioProvider}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                    if (sess.cargoReadyDate.isNotEmpty)
                      Text(
                        '📅 CRD: ${sess.cargoReadyDate}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Actions Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    RowActionsPill(
                      onView: () => onView(sess),
                      onEdit: () => onEdit(sess),
                      onClone: () => onClone(sess),
                      onPrint: () => onPrint(sess),
                      onDelete: () => onDeleteOrRestore(sess),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
