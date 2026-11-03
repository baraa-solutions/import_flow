import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/container_load_plan_export_service.dart';
import '../../../../../core/utils/container_requirement_engine.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/purchase_order_model.dart';

class PoPlanner3dExportBar extends StatelessWidget {
  final GlobalKey repaintKey;
  final PurchaseOrderModel po;
  final List<ContainerPackingResult> plan;
  final String fleetSummary;
  final double totalPlanWeight;
  final double totalPlanVolume;
  final int totalPkgs;
  final bool isArabic;

  const PoPlanner3dExportBar({
    super.key,
    required this.repaintKey,
    required this.po,
    required this.plan,
    required this.fleetSummary,
    required this.totalPlanWeight,
    required this.totalPlanVolume,
    required this.totalPkgs,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppButton(
          label: l.poDownloadSimulationViewsPNG,
          icon: Icons.image_outlined,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: () async {
            await ContainerLoadPlanExportService.exportSimulationImage(
              context: context,
              repaintKey: repaintKey,
              displayName: '${po.displayName} - 3D Simulation',
              isArabic: isArabic,
            );
          },
        ),
        const SizedBox(width: 8),
        AppButton(
          label: l.poDownloadLoadingPlanPDF,
          icon: Icons.picture_as_pdf_outlined,
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: () async {
            await ContainerLoadPlanExportService.exportLoadingPlanPdf(
              context: context,
              repaintKey: repaintKey,
              displayName: po.displayName,
              poNumber: po.poNumber,
              companyName: po.companyName,
              supplierName: po.supplierName,
              plan: plan,
              fleetSummary: fleetSummary,
              totalPlanWeight: totalPlanWeight,
              totalPlanVolume: totalPlanVolume,
              totalPkgs: totalPkgs,
              isArabic: isArabic,
            );
          },
        ),
      ],
    );
  }
}
