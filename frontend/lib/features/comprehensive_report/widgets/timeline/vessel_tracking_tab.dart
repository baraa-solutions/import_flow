import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/shipment_audit_timeline_model.dart';

/// Tab showing the 3-day vessel tracking pulse logs and updates.
class VesselTrackingTab extends StatelessWidget {
  final List<VesselTrackingPulseItemModel> pulses;
  final bool isDark;

  const VesselTrackingTab({
    super.key,
    required this.pulses,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (pulses.isEmpty) {
      return const Center(child: Text('لا توجد نبضات تتبع مسجلة لهذه الشحنة حتى الآن.'));
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
              ),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
              dataRowMinHeight: 40,
              dataRowMaxHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 14,
              columns: const [
                DataColumn(label: Text('# التحديث')),
                DataColumn(label: Text('تاريخ ووقت التحديث')),
                DataColumn(label: Text('الموقع الجغرافي للباخرة')),
                DataColumn(label: Text('الـ ETA المعلن')),
                DataColumn(label: Text('أيام الانحراف')),
                DataColumn(label: Text('حالة الرسو')),
                DataColumn(label: Text('الملاحظات المكتوبة من مسؤول الشحن والخط')),
              ],
              rows: pulses.map((p) {
                final isAta = p.isAtaConfirmed;
                return DataRow(
                  color: WidgetStateProperty.all(
                    isAta ? AppTheme.emerald.withValues(alpha: isDark ? 0.15 : 0.08) : Colors.transparent,
                  ),
                  cells: [
                    DataCell(
                      Text(
                        'تحديث ${p.updateSeq}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                    DataCell(
                      LtrText(p.trackingDate, style: const TextStyle(fontSize: 11)),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isAta ? Icons.anchor : Icons.navigation,
                              size: 14, color: isAta ? AppTheme.emerald : AppTheme.cobalt),
                          const SizedBox(width: 6),
                          Text(p.vesselLocation, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    DataCell(
                      LtrText(p.currentEta,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.cobalt)),
                    ),
                    DataCell(
                      p.delayDays == 0
                          ? const Text('0 يوم',
                              style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11))
                          : Text('+${p.delayDays} يوم تأخير',
                              style: const TextStyle(
                                  color: AppTheme.wcagCrimson, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    DataCell(
                      isAta
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration:
                                  BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(4)),
                              child: const Text('⚓ رسو مؤكد (ATA)',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          : const Text('إبحار نشط', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    ),
                    DataCell(
                      SizedBox(
                        width: 320,
                        child: CopyableTableCell(
                          value: p.remarks ?? '',
                          rowSummary: 'تحديث ${p.updateSeq} - ${p.vesselLocation}',
                          child: Text(
                            p.remarks ?? '-',
                            style: TextStyle(
                                fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800),
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
