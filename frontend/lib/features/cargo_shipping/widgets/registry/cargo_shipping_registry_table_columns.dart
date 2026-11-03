import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../warehouse_receiving/widgets/ops_ui_kit.dart';
import '../../models/cargo_shipping_model.dart';

List<EnterpriseColumn<CargoShippingModel>> buildCargoShippingColumns({
  required BuildContext context,
  required AppLocalizations l,
  required Map<int, dynamic> importFilesMap,
  required void Function(CargoShippingModel) onEditRecord,
  required void Function(CargoShippingModel) onCloneRecord,
  required void Function(CargoShippingModel) onToggleActive,
  required void Function(CargoShippingModel) onCopyRow,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    EnterpriseColumn<CargoShippingModel>(
      id: 'actions',
      title: l.actions,
      width: 210,
      cellBuilder: (ctx, rec, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.cobalt),
            tooltip: l.edit,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            onPressed: () => onEditRecord(rec),
          ),
          IconButton(
            key: Key('cloneShippingRowBtn_${rec.cargoShippingCode}'),
            icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
            tooltip: l.cshCloneBtn,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            onPressed: () => onCloneRecord(rec),
          ),
          IconButton(
            icon: Icon(
              rec.isActive ? Icons.delete_outline : Icons.restore,
              size: 16,
              color: rec.isActive ? AppTheme.crimson : AppTheme.emerald,
            ),
            tooltip: rec.isActive ? l.delete : l.restore,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            onPressed: () => onToggleActive(rec),
          ),
          IconButton(
            key: Key('copyShippingRowBtn_${rec.cargoShippingCode}'),
            icon: const Icon(Icons.content_copy_outlined, size: 16, color: AppTheme.charcoal),
            tooltip: l.copy,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            onPressed: () => onCopyRow(rec),
          ),
        ],
      ),
    ),
    EnterpriseColumn<CargoShippingModel>(
      id: 'shipping_code',
      title: l.cshColCode,
      width: 170,
      exportValue: (rec) => rec.cargoShippingCode,
      sortComparator: (a, b) => a.cargoShippingCode.compareTo(b.cargoShippingCode),
      cellBuilder: (ctx, rec, _) => InkWell(
        onTap: () => onEditRecord(rec),
        child: LtrText(
          rec.cargoShippingCode,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.cobalt,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    ),
    EnterpriseColumn<CargoShippingModel>(
      id: 'import_file',
      title: l.cshColImportFile,
      width: 220,
      exportValue: (rec) {
        final matchingFile = importFilesMap[rec.importFileId];
        final fileCode = matchingFile?.primaryNameWithCode ?? rec.importFileCode ?? 'IMP-${rec.importFileId}';
        final companyName = (matchingFile?.companyName.isNotEmpty == true && matchingFile?.companyName != 'N/A')
            ? matchingFile!.companyName
            : (rec.companyName != null && rec.companyName!.isNotEmpty && rec.companyName != 'N/A' ? rec.companyName! : l.importCompanies);
        return fileCode.isNotEmpty ? '$fileCode - $companyName' : companyName;
      },
      cellBuilder: (ctx, rec, _) {
        final matchingFile = importFilesMap[rec.importFileId];
        final fileCode = matchingFile?.primaryNameWithCode ?? rec.importFileCode ?? 'IMP-${rec.importFileId}';
        final companyName = (matchingFile?.companyName.isNotEmpty == true && matchingFile?.companyName != 'N/A')
            ? matchingFile!.companyName
            : (rec.companyName != null && rec.companyName!.isNotEmpty && rec.companyName != 'N/A' ? rec.companyName! : l.importCompanies);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              fileCode,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                fontSize: 12.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (companyName.isNotEmpty)
              Text(
                companyName,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        );
      },
    ),
    EnterpriseColumn<CargoShippingModel>(
      id: 'supplier',
      title: l.foreignSupplier,
      width: 180,
      exportValue: (rec) {
        final matchingFile = importFilesMap[rec.importFileId];
        return (matchingFile?.supplierName.isNotEmpty == true && matchingFile?.supplierName != 'N/A') ? matchingFile!.supplierName : '';
      },
      cellBuilder: (ctx, rec, _) {
        final matchingFile = importFilesMap[rec.importFileId];
        final supplierName = (matchingFile?.supplierName.isNotEmpty == true && matchingFile?.supplierName != 'N/A') ? matchingFile!.supplierName : '—';
        return Text(
          supplierName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        );
      },
    ),
    EnterpriseColumn<CargoShippingModel>(
      id: 'shipment_type',
      title: l.cshColShipType,
      width: 110,
      exportValue: (rec) => rec.shipmentType,
      cellBuilder: (ctx, rec, _) => Chip(
        label: Text(rec.shipmentType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: rec.shipmentType == 'FCL' ? AppTheme.emerald.withValues(alpha: 0.15) : AppTheme.orange.withValues(alpha: 0.15),
        side: BorderSide.none,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    ),
    EnterpriseColumn<CargoShippingModel>(
      id: 'containers_summary',
      title: l.cshColContainers,
      width: 180,
      cellBuilder: (ctx, rec, _) {
        if (rec.shipmentType == 'FCL') {
          final count = rec.containersLoadingData.length;
          final gated = rec.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
          return Text('$count ${l.cshColContainers} ($gated ${l.cshColGateIn})', style: const TextStyle(fontSize: 11.5));
        } else {
          final wh = rec.lclTrackingData?.cfsWarehouseName ?? '—';
          return Text(wh, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5));
        }
      },
    ),
    EnterpriseColumn<CargoShippingModel>(
      id: 'status',
      title: l.cshColStatus,
      width: 150,
      exportValue: (rec) => rec.status,
      cellBuilder: (ctx, rec, _) {
        final statusLabel = rec.status == 'Completed'
            ? l.cargoShippingStatusCompleted
            : (rec.status == 'Cargo Ready' ? l.cargoShippingStatusCargoReady : rec.status);
        final isCompleted = rec.status == 'Completed';
        return OpsStatusChip(
          label: statusLabel,
          severity: isCompleted ? AppSeverity.success : AppSeverity.info,
          icon: isCompleted ? Icons.check_circle_outline : Icons.local_shipping_outlined,
        );
      },
    ),
    EnterpriseColumn<CargoShippingModel>(
      id: 'sla_status',
      title: l.cshColSla,
      width: 140,
      cellBuilder: (ctx, rec, _) {
        final hasBreach = rec.containersLoadingData.any((c) => c.isSlaBreached) || (rec.lclTrackingData?.isSlaBreached ?? false);
        return OpsStatusChip(
          label: hasBreach ? l.cargoShippingSlaBreachedFilter : l.cargoShippingSlaOnTimeFilter,
          severity: hasBreach ? AppSeverity.danger : AppSeverity.success,
          icon: hasBreach ? Icons.alarm_off : Icons.timer_outlined,
        );
      },
    ),
    EnterpriseColumn<CargoShippingModel>(
      id: 'date',
      title: l.invoiceDateCol,
      width: 130,
      exportValue: (rec) => rec.createdAt.split('T').first,
      cellBuilder: (ctx, rec, _) => LtrText(
        rec.createdAt.isNotEmpty ? rec.createdAt.split('T').first : '—',
        style: const TextStyle(fontSize: 11.5),
      ),
    ),
  ];
}
