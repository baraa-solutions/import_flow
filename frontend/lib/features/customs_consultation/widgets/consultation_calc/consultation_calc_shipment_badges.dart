import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/models/import_file_model.dart';

/// Badges displaying shipment Incoterm, Port of Loading, and Port of Discharge.
class ConsultationCalcShipmentBadges extends StatelessWidget {
  final ImportFileModel? file;

  const ConsultationCalcShipmentBadges({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final selFile = file;
    if (selFile == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.cobaltLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.cobaltBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping_outlined,
                  size: 14, color: AppTheme.cobalt),
              const SizedBox(width: 4),
              Text(
                'Incoterm: ${selFile.incotermCode.isNotEmpty ? selFile.incotermCode : "FOB"}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.wcagCobalt,
                ),
              ),
            ],
          ),
        ),
        if (selFile.portOfLoading != null && selFile.portOfLoading!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.emeraldLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.emeraldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight_takeoff,
                    size: 14, color: AppTheme.emerald),
                const SizedBox(width: 4),
                Text(
                  selFile.portOfLoading!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.wcagEmerald,
                  ),
                ),
              ],
            ),
          ),
        if (selFile.portOfDischarge != null &&
            selFile.portOfDischarge!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.orangeLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.orange),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight_land, size: 14, color: AppTheme.orange),
                const SizedBox(width: 4),
                Text(
                  selFile.portOfDischarge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.wcagOrange,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
