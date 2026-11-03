import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../experience_guide/widgets/smart_shipment_reference_card.dart';
import '../../import_files/models/import_file_model.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/comprehensive_dossier_model.dart';

/// Smart technical and reference guide card for the shipment.
class ReportSmartShipmentReferenceCard extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final List<PurchaseOrderModel> allPOs;

  const ReportSmartShipmentReferenceCard({
    super.key,
    required this.file,
    this.dossier,
    this.allPOs = const [],
  });

  @override
  Widget build(BuildContext context) {
    final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
    final double totalCbm = dossier != null && dossier!.totalCbm > 0
        ? dossier!.totalCbm
        : file.packingListsData.fold<double>(0.0, (s, p) => s + p.cbm);
    final double grossWeight = dossier != null && dossier!.grossWeightKg > 0
        ? dossier!.grossWeightKg
        : file.packingListsData.fold<double>(0.0, (s, p) => s + p.grossWeightKg);

    final smartRec = dossier?.smartRecommendation ??
        ContainerRequirementEngine.recommendShipmentMode(totalCbm: totalCbm, totalWeightKg: grossWeight).reasonAr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (smartRec.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: Row(
              children: [
                const Icon(Icons.recommend, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    smartRec,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E3A8A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    file.shipmentMode,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        SmartShipmentReferenceCard(
          importFileId: file.importFileId,
          file: file,
          dossier: dossier,
          linkedPOs: linkedPOs,
        ),
      ],
    );
  }
}
