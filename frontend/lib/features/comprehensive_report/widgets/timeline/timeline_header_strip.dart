import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/shipment_audit_timeline_model.dart';

/// Header row for the shipment audit timeline dialog with file code and action buttons.
class TimelineHeaderStrip extends StatelessWidget {
  final ShipmentAuditTimelineModel data;
  final bool isDark;
  final VoidCallback onCopyAllTable;
  final VoidCallback onExportExcel;
  final VoidCallback onPrintPdf;

  const TimelineHeaderStrip({
    super.key,
    required this.data,
    required this.isDark,
    required this.onCopyAllTable,
    required this.onExportExcel,
    required this.onPrintPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.history_toggle_off, color: AppTheme.cobalt, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'محضر ورادار التتبع الزمني الشامل للشحنة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      data.importFileCode,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  if (data.customFileNumber != null)
                    Text(
                      '(${data.customFileNumber})',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'المورد: ${data.supplierName} │ الخط: ${data.shippingLineName ?? "-"} │ البوليصة: ${data.billOfLadingNo ?? "-"} │ ميناء الوصول: ${data.portOfDischarge ?? "-"} │ الحاويات: ${data.containersSummary ?? "-"}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('نسخ الجدول'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cobalt,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: onCopyAllTable,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_download, size: 16),
              label: const Text('تصدير Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: onExportExcel,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: const Text('طباعة / PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.charcoal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: onPrintPdf,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
