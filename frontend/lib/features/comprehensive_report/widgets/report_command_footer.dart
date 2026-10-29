import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';

/// Quick operational command and decision footer bar for the Comprehensive Report.
class ReportOperationalCommandFooter extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final VoidCallback? onRequestRfq;
  final VoidCallback? onEditFile;
  final VoidCallback? onStopShipment;
  final VoidCallback? onRecalculateCost;
  final VoidCallback? onCreatePartialBatch;

  const ReportOperationalCommandFooter({
    super.key,
    required this.file,
    this.dossier,
    this.onRequestRfq,
    this.onEditFile,
    this.onStopShipment,
    this.onRecalculateCost,
    this.onCreatePartialBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.tune, color: AppTheme.charcoal, size: 20),
            const SizedBox(width: 8),
            const Text(
              'مركز القرارات والتحكم التشغيلي السريع للشحنة:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
            const SizedBox(width: 24),
            // 1. Request RFQ
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.request_quote_outlined, size: 15),
              label: const Text('طلب عروض أسعار شحن (RFQ)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: onRequestRfq,
            ),
            const SizedBox(width: 8),
            // 2. Edit Import File
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.edit_note, size: 15),
              label: const Text('تعديل وتحديث الملف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: onEditFile,
            ),
            const SizedBox(width: 8),
            // 3. Stop Shipment
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.crimson,
                side: const BorderSide(color: AppTheme.crimson),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 15),
              label: const Text('إيقاف الشحنة مرحلياً', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: onStopShipment,
            ),
            const SizedBox(width: 8),
            // 4. Recalculate Landed Cost
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.charcoal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('إعادة احتساب تكلفة الوصول', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: onRecalculateCost,
            ),
            if (file.status != 'Closed' && onCreatePartialBatch != null) ...[
              const SizedBox(width: 8),
              // 5. Create Partial Batch
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.call_split_rounded, size: 15),
                label: const Text('إنشاء دفعة جزئية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: onCreatePartialBatch,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
