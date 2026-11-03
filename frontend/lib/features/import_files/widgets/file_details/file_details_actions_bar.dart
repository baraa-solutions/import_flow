// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/unified_dossier_export_menu.dart';
import '../../models/import_file_model.dart';
import '../../../comprehensive_report/models/comprehensive_dossier_model.dart';
import '../../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../../customs_clearance/models/customs_clearance_model.dart';
import '../../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../close_shipment_dialog.dart';
import '../create_partial_batch_dialog.dart';
import '../freight_rfq_dialog.dart';

/// ⚡ Action toolbar and bottom status buttons for Import File Details
/// Displays quick export tools via UnifiedDossierExportMenu / FileSaveHelper,
/// Freight RFQ, Edit, Stop Shipment, Create Partial Batch, and Close actions.
class FileDetailsActionsBar extends ConsumerWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final ShipmentUpdatesState updatesState;
  final AsyncValue<List<CustomsClearanceModel>> clearanceState;
  final AsyncValue<List<WarehouseReceivingModel>> warehouseState;
  final VoidCallback? onEditPressed;
  final VoidCallback onClose;

  const FileDetailsActionsBar({
    super.key,
    required this.file,
    this.dossier,
    required this.updatesState,
    required this.clearanceState,
    required this.warehouseState,
    this.onEditPressed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isAr = ref.watch(localeProvider).languageCode == 'ar' || Localizations.localeOf(context).languageCode == 'ar';
    final clr = clearanceState.valueOrNull?.firstOrNull;
    final wh = warehouseState.valueOrNull?.firstOrNull;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Compact Export Menu
        UnifiedDossierExportMenu(
          file: file,
          dossier: dossier,
          logs: updatesState.logs,
          clearance: clr,
          warehouse: wh,
          displayMode: UnifiedExportDisplayMode.dropdown,
        ),
        AppButton(
          label: l.freightRfqTooltip,
          icon: Icons.mark_email_unread_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () {
            FreightRfqDialog.show(
              context,
              importFileId: file.importFileId,
              importFileCode: file.importFileCode,
              customFileNumber: file.customFileNumber,
            );
          },
        ),
        if (file.status != 'Closed' && onEditPressed != null)
          AppButton(
            label: l.editImportFile,
            icon: Icons.edit,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () {
              Navigator.pop(context);
              onEditPressed!();
            },
          ),
        if (file.status != 'Closed')
          AppButton(
            label: l.stopShipmentAtThisStageBtn,
            icon: Icons.pause_circle_outline,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (c) => CloseShipmentDialog(
                  importFileId: file.importFileId,
                  importFileCode: file.customFileNumber ?? file.importFileCode,
                  currentPhaseName: file.currentStage,
                ),
              );
            },
          ),
        if (file.status != 'Closed')
          AppButton(
            label: isAr ? 'إنشاء دفعة جزئية' : 'Create Partial Batch',
            icon: Icons.call_split_rounded,
            variant: AppButtonVariant.warning,
            size: AppButtonSize.small,
            onPressed: () async {
              final created = await showDialog<ImportFileModel>(
                context: context,
                builder: (c) => CreatePartialBatchDialog(parentFile: file),
              );
              if (created != null && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        AppButton(
          label: l.close,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          onPressed: onClose,
        ),
      ],
    );
  }
}
