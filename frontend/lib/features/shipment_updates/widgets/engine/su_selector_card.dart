import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/shipment_update_model.dart';
import '../../providers/shipment_updates_provider.dart';

class SuSelectorCard extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isAr;
  final AsyncValue<List<ImportFileModel>> importFilesState;
  final ShipmentUpdatesState updatesState;
  final int? selectedFileId;
  final ImportFileModel? selectedFile;
  final ValueChanged<int?> onShipmentSelected;
  final VoidCallback onReload;
  final VoidCallback onOpenDailyCheckin;
  final void Function(List<ShipmentUpdateLogModel>) onCopyTsv;

  const SuSelectorCard({
    super.key,
    required this.l10n,
    required this.isAr,
    required this.importFilesState,
    required this.updatesState,
    required this.selectedFileId,
    required this.selectedFile,
    required this.onShipmentSelected,
    required this.onReload,
    required this.onOpenDailyCheckin,
    required this.onCopyTsv,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: AppTheme.cardDecorationOf(context),
      child: importFilesState.when(
        loading: () => const LinearProgressIndicator(),
        error: (err, _) => CcStateView.error(
          message: l10n.shipmentUpdateErrorLoadingShipments(ApiErrorText.of(l10n, err)),
          actionLabel: l10n.retry,
          onAction: onReload,
        ),
        data: (files) {
          if (files.isEmpty) {
            return CcStateView.empty(
              message: l10n.shipmentUpdateNoShipmentsRegistered,
              icon: Icons.local_shipping_outlined,
            );
          }
          final logs = updatesState.logs;
          final shipmentCode = selectedFile?.customFileNumber ?? selectedFile?.importFileCode;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchableDropdownField<int>(
                value: selectedFileId,
                labelText: l10n.shipmentUpdateSelectShipmentPrompt,
                items: files.map((f) {
                  final sTitle = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
                  final pTitle = DisplayNameResolver.resolvePhaseName(f.currentModule, isArabic: isAr);
                  return SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: '$sTitle - ${f.supplierName} ($pTitle)',
                  );
                }).toList(),
                onChanged: onShipmentSelected,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CcUi.fit(AppButton(
                    label: l10n.shipmentUpdateComprehensiveDailyCheckinBtn,
                    icon: Icons.today,
                    onPressed: selectedFile == null ? null : onOpenDailyCheckin,
                  )),
                  CcUi.fit(AppButton(
                    label: l10n.shipmentUpdatesExportTsvBtn,
                    icon: Icons.copy_all_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: logs.isEmpty ? null : () => onCopyTsv(logs),
                  )),
                  CcUi.fit(AppButton(
                    label: l10n.shipmentUpdatesExportExcelBtn,
                    icon: Icons.table_view_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: logs.isEmpty
                        ? null
                        : () => MasterDataExportService.exportShipmentUpdatesToExcel(
                              context,
                              logs,
                              shipmentCode: shipmentCode,
                              isAr: isAr,
                            ),
                  )),
                  CcUi.fit(AppButton(
                    label: l10n.shipmentUpdatesExportPdfBtn,
                    icon: Icons.print_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: logs.isEmpty
                        ? null
                        : () => MasterDataExportService.printOrSaveShipmentUpdatesListPdf(
                              context,
                              logs,
                              shipmentCode: shipmentCode,
                              isAr: isAr,
                            ),
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
