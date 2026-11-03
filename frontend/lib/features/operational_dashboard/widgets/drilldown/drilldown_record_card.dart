import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import 'drilldown_models.dart';

class DrilldownRecordCard extends StatelessWidget {
  final DrillDownItem item;
  final Color themeColor;
  final bool isArabic;
  final bool isDark;
  final void Function(DrillDownItem) onCopySingleRecord;
  final String Function(DrillDownItem) formatBadgeShipment;

  const DrilldownRecordCard({
    super.key,
    required this.item,
    required this.themeColor,
    required this.isArabic,
    required this.isDark,
    required this.onCopySingleRecord,
    required this.formatBadgeShipment,
  });

  static Color getStatusColor(String? type) {
    switch (type) {
      case 'danger':
        return AppTheme.crimson;
      case 'warning':
        return AppTheme.orange;
      case 'success':
        return AppTheme.emerald;
      case 'info':
      default:
        return AppTheme.cobalt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final statusColor = getStatusColor(item.statusColorType);

    return Card(
      elevation: 1.5,
      color: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title + Status + Copy Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CopyableText(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: isDark ? 0.6 : 0.4)),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      color: isDark ? Colors.tealAccent.shade100 : statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 16, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                  tooltip: l.drillDownCopiedItemToast,
                  onPressed: () => onCopySingleRecord(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),

            if (item.shipmentCode != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: isDark ? 0.22 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? AppTheme.cobalt.withValues(alpha: 0.4) : Colors.transparent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 14, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                    const SizedBox(width: 6),
                    Text(
                      formatBadgeShipment(item),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Divider(height: 20, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),

            // Middle Grid: What / Who / By When
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _buildInfoBlock(
                  icon: Icons.checklist_rtl_rounded,
                  label: l.drillDownLabelWhat,
                  value: item.nextAction ?? item.title,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
                _buildInfoBlock(
                  icon: Icons.person_outline_rounded,
                  label: l.drillDownLabelWho,
                  value: item.who,
                  color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                ),
                _buildInfoBlock(
                  icon: Icons.event_available_rounded,
                  label: l.drillDownLabelWhen,
                  value: item.byWhen,
                  color: isDark ? Colors.orange.shade300 : AppTheme.orange,
                ),
              ],
            ),

            // Data Gaps Alert
            if (item.dataGaps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 15, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: item.dataGaps.map((gap) {
                          return Text(
                            '⚠️ ${l.drillDownDataGapBadge}: $gap',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons Row
            if (item.onAction != null || item.onSecondaryAction != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.onSecondaryAction != null && item.secondaryActionLabel != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                        side: BorderSide(color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.touch_app_rounded, size: 14),
                      label: Text(
                        item.secondaryActionLabel!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        item.onSecondaryAction!();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (item.onAction != null && item.actionLabel != null) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      label: Text(
                        item.actionLabel!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        item.onAction!();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBlock({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                CopyableText(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  showIcon: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
