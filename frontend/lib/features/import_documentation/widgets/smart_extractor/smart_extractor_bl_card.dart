import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import 'smart_extractor_actions_bar.dart';
import 'smart_extractor_dropzone.dart';
import 'smart_extractor_field_chip.dart';

/// Full tab card for Bill of Lading / Air Waybill extraction and review.
class SmartExtractorBLCard extends StatelessWidget {
  final TextEditingController textController;
  final PlatformFile? pickedFile;
  final VoidCallback onPickFile;
  final VoidCallback onClearFile;
  final VoidCallback onExtract;
  final bool isExtracting;
  final Map<String, dynamic>? extractedBL;
  final List<dynamic> blContainers;
  final VoidCallback onApply;
  final bool isApplying;

  const SmartExtractorBLCard({
    super.key,
    required this.textController,
    required this.pickedFile,
    required this.onPickFile,
    required this.onClearFile,
    required this.onExtract,
    required this.isExtracting,
    required this.extractedBL,
    required this.blContainers,
    required this.onApply,
    required this.isApplying,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartExtractorDropzone(
            title: l.smartExtractorBlCardTitle,
            hint: l.smartExtractorBlCardHint,
            textController: textController,
            pickedFile: pickedFile,
            onPickFile: onPickFile,
            onClearFile: onClearFile,
            onExtract: onExtract,
            isLoading: isExtracting,
            extractButtonLabel: l.smartExtractorExtractBlButton,
          ),
          if (extractedBL != null) ...[
            const SizedBox(height: 16),
            SmartExtractorBLSummaryCard(bl: extractedBL!),
            const SizedBox(height: 16),
            SmartExtractorBLContainersTable(containers: blContainers),
            const SizedBox(height: 16),
            SmartExtractorBLActionBar(
              onApply: onApply,
              isApplying: isApplying,
            ),
          ],
        ],
      ),
    );
  }
}

/// Extracted Bill of Lading (Ocean) or Air Waybill (Air) summary card.
class SmartExtractorBLSummaryCard extends StatelessWidget {
  final Map<String, dynamic> bl;

  const SmartExtractorBLSummaryCard({
    super.key,
    required this.bl,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isAir = bl['bl_type'] == 'AIR_WAYBILL';
    final isPrepaid = bl['freight_payment_term'] == 'FREIGHT_PREPAID';
    final defaultPkg = isArabic ? 'طرد' : 'Pkgs';
    final pkgType = bl['package_type']?.toString().trim();
    final packagesDisplay =
        '${bl['total_packages_count'] ?? '-'} ${pkgType != null && pkgType.isNotEmpty ? pkgType : defaultPkg}';

    return Card(
      elevation: 0,
      color: isAir ? AppTheme.orangeLight : AppTheme.emeraldLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            BorderSide(color: isAir ? AppTheme.orange : AppTheme.emeraldBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAir ? Icons.airplanemode_active : Icons.directions_boat,
                  color: isAir ? AppTheme.orange : AppTheme.emerald,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isAir
                      ? l.smartExtractorAirWaybillTitle
                      : l.smartExtractorOceanBlTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.charcoal,
                  ),
                ),
                const Spacer(),
                AppStatusBadge(
                  label: isPrepaid
                      ? l.smartExtractorPaymentPrepaid
                      : l.smartExtractorPaymentCollect,
                  severity: isPrepaid ? AppSeverity.info : AppSeverity.warning,
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldBlNo,
                  value: '${bl['bl_number'] ?? '-'}',
                  isHighlight: true,
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldAcidNo,
                  value: '${bl['acid_number'] ?? '-'}',
                  isHighlight: true,
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldCarrier,
                  value: '${bl['carrier_name'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: isAir
                      ? l.smartExtractorFieldFlightNo
                      : l.smartExtractorFieldVesselVoyage,
                  value: isAir
                      ? '${bl['flight_number'] ?? '-'}'
                      : '${bl['vessel_name'] ?? '-'} / ${bl['voyage_number'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldPol,
                  value: '${bl['loading_port'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldPod,
                  value: '${bl['discharge_port'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldTotalGrossWeight,
                  value: '${bl['total_gross_weight_kg'] ?? '-'} KG',
                  isHighlight: true,
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldTotalCbm,
                  value: '${bl['total_cbm'] ?? '-'} CBM',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldPackagesCount,
                  value: packagesDisplay,
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldShipper,
                  value: '${bl['shipper'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldConsignee,
                  value: '${bl['consignee'] ?? '-'}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Extracted containers table for B/L documents.
class SmartExtractorBLContainersTable extends StatelessWidget {
  final List<dynamic> containers;

  const SmartExtractorBLContainersTable({
    super.key,
    required this.containers,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_in_ar_outlined,
                    color: AppTheme.charcoal, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.smartExtractorContainersTableTitle(containers.length),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (containers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text(l.smartExtractorNoContainersFound)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        AppTheme.surfaceAltOf(context)),
                    columnSpacing: 24,
                    columns: [
                      const DataColumn(label: Text('#')),
                      DataColumn(label: Text(l.smartExtractorColContainerNo)),
                      DataColumn(label: Text(l.smartExtractorColSealNo)),
                      DataColumn(label: Text(l.smartExtractorColContainerType)),
                      DataColumn(
                          label: Text(l.smartExtractorColGrossWeightKg)),
                    ],
                    rows: List.generate(containers.length, (idx) {
                      final c = containers[idx] as Map<String, dynamic>;
                      final idxStr = '${idx + 1}';
                      final cNo = '${c['container_no'] ?? '-'}';
                      final sealNo = '${c['seal_no'] ?? '-'}';
                      final cType = '${c['container_type'] ?? '40HC'}';
                      final gw = '${c['gross_weight_kg'] ?? '-'}';
                      final rowSummary =
                          '$idxStr\t$cNo\t$sealNo\t$cType\t$gw';

                      return DataRow(cells: [
                        DataCell(
                          CopyableTableCell(
                            value: idxStr,
                            rowSummary: rowSummary,
                            child: Text(idxStr),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: cNo,
                            rowSummary: rowSummary,
                            child: Text(
                              cNo,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: sealNo,
                            rowSummary: rowSummary,
                            child: Text(sealNo),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: cType,
                            rowSummary: rowSummary,
                            child: Text(cType),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: gw,
                            rowSummary: rowSummary,
                            child: Text(gw),
                          ),
                        ),
                      ]);
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
