import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/shipment_audit_timeline_model.dart';

/// Tab showing the 36 critical milestones matrix and operational timeline audit notes.
class MilestonesTableTab extends StatelessWidget {
  final List<MilestoneAuditItemModel> milestones;
  final bool isDark;

  const MilestonesTableTab({
    super.key,
    required this.milestones,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1150),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
              ),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
              dataRowMinHeight: 38,
              dataRowMaxHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 14,
              columns: const [
                DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('المحطة والحدث الزمني')),
                DataColumn(label: Text('المرحلة')),
                DataColumn(label: Text('المخطط')),
                DataColumn(label: Text('الفعلي')),
                DataColumn(label: Text('الفارق')),
                DataColumn(label: Text('مدة الإنجاز')),
                DataColumn(label: Text('الحالة')),
                DataColumn(label: Text('الملاحظات والتوجيهات التشغيلية')),
              ],
              rows: milestones.map((m) {
                final isCrit = m.isCriticalWatchpoint;
                final isOverdue = m.varianceDays > 0;

                Color rowBgColor = Colors.transparent;
                if (isCrit) {
                  rowBgColor = AppTheme.cobalt.withValues(alpha: isDark ? 0.15 : 0.08);
                } else if (isOverdue && m.status != 'COMPLETED') {
                  rowBgColor = AppTheme.wcagCrimson.withValues(alpha: isDark ? 0.15 : 0.06);
                }

                return DataRow(
                  color: WidgetStateProperty.all(rowBgColor),
                  cells: [
                    DataCell(
                      Text(
                        '${m.seq}',
                        style: TextStyle(
                          fontWeight: isCrit ? FontWeight.bold : FontWeight.normal,
                          color: isCrit ? AppTheme.cobalt : null,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCrit) ...[
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            m.nameAr,
                            style: TextStyle(
                              fontWeight: isCrit ? FontWeight.bold : FontWeight.w600,
                              fontSize: 12,
                              color: isCrit ? (isDark ? Colors.lightBlueAccent : AppTheme.cobalt) : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('P${m.phaseNumber}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      LtrText(
                        m.plannedDate ?? '-',
                        style: TextStyle(
                            fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                      ),
                    ),
                    DataCell(
                      LtrText(
                        m.actualDate ?? '-',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: m.actualDate != null ? FontWeight.bold : FontWeight.normal,
                          color: m.actualDate != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                        ),
                      ),
                    ),
                    DataCell(
                      m.varianceDays == 0
                          ? const Text('0',
                              style: TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold))
                          : Text(
                              '+${m.varianceDays} يوم',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.wcagCrimson, fontWeight: FontWeight.bold),
                            ),
                    ),
                    DataCell(
                      Text(
                        m.tatDisplay ?? '-',
                        style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(AppStatusBadge.fromStatus(status: m.status)),
                    DataCell(
                      SizedBox(
                        width: 320,
                        child: CopyableTableCell(
                          value: m.notes ?? '',
                          rowSummary: '${m.seq} - ${m.nameAr}',
                          child: Text(
                            m.notes ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
