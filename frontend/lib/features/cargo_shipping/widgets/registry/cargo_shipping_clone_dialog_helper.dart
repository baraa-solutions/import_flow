import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/cargo_container_defaults.dart';
import '../../models/cargo_shipping_model.dart';
import '../search_and_clone_cargo_shipping_dialog.dart';

class CargoShippingCloneDialogHelper {
  static void openSearchAndCloneDialog({
    required BuildContext context,
    required List<CargoShippingModel> records,
    required void Function(CargoShippingModel) onSelectRecord,
  }) {
    final l = context.l10n;
    final isAr = l.isArabic;
    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AppLocalizationsProvider(
          locale: isAr ? const Locale('ar') : const Locale('en'),
          child: Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: SearchAndCloneCargoShippingDialog(
              records: records,
              onSelectRecord: onSelectRecord,
            ),
          ),
        ),
      ),
    );
  }

  static void showCloneReviewDialog({
    required BuildContext context,
    required CargoShippingModel rec,
    void Function(
      CargoShippingModel sourceRec,
      String newCode,
      List<ContainerLoadingModel> clonedContainers,
    )? onCloneRecordToForm,
  }) {
    final l = context.l10n;
    final isAr = l.isArabic;
    final newDraftCode = 'SHP-DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final containerSummary = rec.containersLoadingData.isNotEmpty
        ? rec.containersLoadingData.map((c) => '${c.quantity}x ${c.containerType}').join(', ')
        : (rec.shipmentType == 'LCL' ? l.cshLclConsolidation : l.cshStandard40hc);

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AppLocalizationsProvider(
          locale: isAr ? const Locale('ar') : const Locale('en'),
          child: Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: CloneEntityReviewDialog(
              entityType: l.cshCloneEntityType,
              sourceCode: rec.cargoShippingCode,
              suggestedNewCode: newDraftCode,
              sourceTitle: '${rec.importFileCode ?? "IMP-${rec.importFileId}"} - ${rec.companyName ?? ""}',
              copiedFieldsSummary: {
                l.cshCloneFieldShipmentType: rec.shipmentType,
                l.cshCloneFieldContainers: containerSummary,
                l.cshCloneFieldVgm: l.cshWeightKg(
                  rec.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg).toStringAsFixed(0),
                ),
                if (rec.shipmentType == 'LCL' && rec.lclTrackingData?.cfsWarehouseName != null)
                  l.cshCloneFieldCfs: rec.lclTrackingData!.cfsWarehouseName ?? '',
              },
              mandatorilyResetFields: [
                l.cshCloneReset1,
                l.cshCloneReset2,
                l.cshCloneReset3,
                l.cshCloneReset4,
                l.cshCloneReset5,
              ],
              allowCopyLineItems: true,
              allowCopyAttachments: false,
              onConfirm: ({
                required String newCode,
                required String newTitle,
                required bool copyLineItems,
                required bool copyAttachments,
                String? notes,
              }) async {
                final nowIso = DateTime.now().toIso8601String();
                final List<ContainerLoadingModel> clonedContainers = [];

                if (copyLineItems && rec.containersLoadingData.isNotEmpty) {
                  for (final c in rec.containersLoadingData) {
                    final dupUnits = blankUnits(c.individualUnits.length);
                    clonedContainers.add(
                      ContainerLoadingModel(
                        containerType: c.containerType,
                        quantity: c.quantity,
                        containerNo: '',
                        sealNo: '',
                        tareWeightKg: c.tareWeightKg,
                        netWeightKg: c.netWeightKg,
                        grossWeightKg: c.grossWeightKg,
                        vgmStatus: 'Pending',
                        containerAssignmentDate: nowIso,
                        trackingStatus: 'ASSIGNED',
                        individualUnits: dupUnits,
                      ),
                    );
                  }
                }

                if (onCloneRecordToForm != null) {
                  onCloneRecordToForm(rec, newCode, clonedContainers);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    AppTheme.snackBar(context, '${l.cloneCargoShippingTooltip}: $newCode', severity: AppSeverity.info),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
