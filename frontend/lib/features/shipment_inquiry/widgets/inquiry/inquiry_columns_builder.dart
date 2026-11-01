import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../services/shipment_inquiry_export_service.dart';

/// Helper to build columns for Shipment Inquiry EnterpriseDataTable
class InquiryColumnsBuilder {
  static Color getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('مكتمل') || s.contains('completed') || s.contains('cleared') || s.contains('مفرج')) {
      return AppTheme.emerald;
    }
    if (s.contains('جار') || s.contains('in_progress') || s.contains('active') || s.contains('قيد')) {
      return AppTheme.cobalt;
    }
    if (s.contains('متأخر') || s.contains('delayed') || s.contains('overdue')) {
      return AppTheme.crimson;
    }
    if (s.contains('مسود') || s.contains('draft')) {
      return Colors.blueGrey;
    }
    return AppTheme.orange;
  }

  static Color getIncotermColor(String inco) {
    switch (inco.toUpperCase()) {
      case 'EXW':
        return Colors.orange.shade800;
      case 'FOB':
        return AppTheme.cobalt;
      case 'CIF':
      case 'CIP':
        return AppTheme.emerald;
      case 'DDP':
        return Colors.purple.shade700;
      default:
        return AppTheme.charcoal;
    }
  }

  static List<EnterpriseColumn<ImportFileModel>> buildColumns({
    required BuildContext context,
    required AppLocalizations l,
    required void Function(ImportFileModel file) onOpenDetails,
    required void Function(ImportFileModel file) onOpenClone,
    required void Function(ImportFileModel file) onPrintSingleShipment,
  }) {
    return [
      EnterpriseColumn<ImportFileModel>(
        id: 'actions',
        title: l.inqColActions,
        width: 170,
        isSortable: false,
        isSearchable: false,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          final rowTsvSummary = '${row.shipmentName}\t${file.importFileCode}\t${row.fileDate}\t${row.supplierName}\t${row.companyName}\t${row.itemAndHs}\t${row.route}\t${row.shippingMode}\t${row.incoterm}\t${row.freightCost.toStringAsFixed(0)} ${row.currency}\t${row.finalCost.toStringAsFixed(0)} ${row.finalCostCurrency}\t${row.status}';

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, color: AppTheme.charcoal, size: 18),
                tooltip: l.inqActionDetails,
                onPressed: () => onOpenDetails(file),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 18),
                tooltip: l.inqActionClone,
                onPressed: () => onOpenClone(file),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined, color: AppTheme.crimson, size: 18),
                tooltip: l.inqPrintRowTooltip,
                onPressed: () => onPrintSingleShipment(file),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppTheme.emerald, size: 18),
                tooltip: l.inqCopyRowTooltip,
                onPressed: () {
                  CopyHelper.copy(
                    context,
                    rowTsvSummary,
                    customMessage: l.inqCopiedRowSuccess,
                  );
                },
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'shipmentName',
        title: l.inqColShipmentName,
        width: 220,
        exportValue: (file) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return '${row.shipmentName} (${file.importFileCode})';
        },
        searchValue: (file) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return '${row.shipmentName} ${file.importFileCode}';
        },
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                row.shipmentName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LtrText(
                    file.importFileCode,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => CopyHelper.copy(
                      context,
                      file.importFileCode,
                      customMessage: l.inqCopiedCodeSuccess,
                    ),
                    child: Tooltip(
                      message: l.inqCopyCodeTooltip,
                      child: Icon(
                        Icons.copy_rounded,
                        size: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'date',
        title: l.inqColDate,
        width: 120,
        exportValue: (file) => ShipmentInquiryReportRow.fromImportFile(file, l).fileDate,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Text(
            row.fileDate.isNotEmpty ? row.fileDate : '-',
            style: const TextStyle(fontSize: 12),
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'supplier',
        title: l.inqColSupplier,
        width: 180,
        exportValue: (file) => ShipmentInquiryReportRow.fromImportFile(file, l).supplierName,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.business_outlined, size: 15, color: AppTheme.cobalt),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  row.supplierName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'importer',
        title: l.inqColImporter,
        width: 160,
        exportValue: (file) => ShipmentInquiryReportRow.fromImportFile(file, l).companyName,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              row.companyName,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'itemAndHs',
        title: l.inqColItemAndHs,
        width: 160,
        exportValue: (file) => ShipmentInquiryReportRow.fromImportFile(file, l).itemAndHs,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Text(
            row.itemAndHs,
            style: const TextStyle(fontSize: 12),
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'route',
        title: l.inqColRoute,
        width: 150,
        exportValue: (file) => ShipmentInquiryReportRow.fromImportFile(file, l).route,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.alt_route_rounded, size: 15, color: Colors.teal),
              const SizedBox(width: 6),
              Text(
                row.route,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'shippingMode',
        title: l.inqColShippingMode,
        width: 130,
        exportValue: (file) => ShipmentInquiryReportRow.fromImportFile(file, l).shippingMode,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_boat_outlined, size: 15, color: AppTheme.cobalt),
              const SizedBox(width: 6),
              Text(
                row.shippingMode,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'incoterm',
        title: l.inqColIncoterm,
        width: 120,
        exportValue: (file) => ShipmentInquiryReportRow.fromImportFile(file, l).incoterm,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: getIncotermColor(row.incoterm).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: getIncotermColor(row.incoterm).withValues(alpha: 0.4)),
            ),
            child: Text(
              row.incoterm,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: getIncotermColor(row.incoterm),
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'freightCost',
        title: l.inqColFreightCost,
        width: 130,
        isNumeric: true,
        exportValue: (file) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return '${row.freightCost.toStringAsFixed(0)} ${row.currency}';
        },
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Text(
            '${row.freightCost.toStringAsFixed(0)} ${row.currency}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'finalCost',
        title: l.inqColFinalCost,
        width: 130,
        isNumeric: true,
        exportValue: (file) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return '${row.finalCost.toStringAsFixed(0)} ${row.finalCostCurrency}';
        },
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Text(
            '${row.finalCost.toStringAsFixed(0)} ${row.finalCostCurrency}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          );
        },
      ),
      EnterpriseColumn<ImportFileModel>(
        id: 'status',
        title: l.inqColStatus,
        width: 130,
        exportValue: (file) => ShipmentInquiryReportRow.fromImportFile(file, l).status,
        cellBuilder: (context, file, index) {
          final row = ShipmentInquiryReportRow.fromImportFile(file, l);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: getStatusColor(row.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: getStatusColor(row.status).withValues(alpha: 0.35)),
            ),
            child: Text(
              row.status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: getStatusColor(row.status),
              ),
            ),
          );
        },
      ),
    ];
  }
}
