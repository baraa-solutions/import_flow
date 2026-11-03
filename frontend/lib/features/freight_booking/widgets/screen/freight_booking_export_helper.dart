import 'package:flutter/material.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../models/freight_booking_model.dart';

class FreightBookingExportHelper {
  static List<String> tsvHeaders(AppLocalizations l) => [
        l.freightBookingColBookingCode,
        l.freightBookingColImportFile,
        l.freightBookingColConfirmationNo,
        l.freightBookingShippingLineLabel,
        l.freightBookingForwarderLabel,
        l.freightBookingPolLabel,
        l.freightBookingPodLabel,
        l.freightBookingVesselNameInput,
        l.freightBookingVoyageNoInput,
        l.freightBookingEtdLabel,
        l.freightBookingEtaLabel,
        l.freightBookingColContainers,
        l.freightBookingColTotalFreight,
        l.freightBookingColStatus,
      ];

  static List<String> tsvRow(ShipmentBookingModel b) => [
        b.bookingCode,
        b.importFileCode ?? '',
        b.bookingConfirmationNo ?? '',
        b.shippingLineName ?? '',
        b.freightForwarderName ?? '',
        b.polName ?? '',
        b.podName ?? '',
        b.vesselName ?? '',
        b.voyageNumber ?? '',
        b.etd != null && b.etd!.length >= 10 ? b.etd!.substring(0, 10) : '',
        b.eta != null && b.eta!.length >= 10 ? b.eta!.substring(0, 10) : '',
        b.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', '),
        CcFormat.fixed(b.totalFreightCostUsd),
        b.status,
      ];

  static void copyBookingRowTsv({
    required BuildContext context,
    required ShipmentBookingModel bkg,
    required AppLocalizations l,
  }) {
    TableCopyHelper.copyRow(
      context,
      tsvRow(bkg),
      headers: tsvHeaders(l),
      includeHeaders: true,
      customMessage: l.copyBookingRowSuccess,
    );
  }

  static void copyBookingsTableTsv({
    required BuildContext context,
    required List<ShipmentBookingModel> bookings,
    required AppLocalizations l,
  }) {
    TableCopyHelper.copyTable(
      context,
      tsvHeaders(l),
      bookings.map(tsvRow).toList(),
      customMessage: l.copyBookingsTableSuccess,
    );
  }

  static Future<void> exportBookingsExcel({
    required BuildContext context,
    required List<ShipmentBookingModel> bookings,
    required AppLocalizations l,
  }) async {
    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Freight Booking',
      importFileNameOrCode: 'Registry',
      headers: tsvHeaders(l),
      rows: bookings.map(tsvRow).toList(),
    );
  }

  static Future<void> exportBookingsPdf({
    required BuildContext context,
    required List<ShipmentBookingModel> bookings,
    required AppLocalizations l,
  }) async {
    final headers = [
      l.freightBookingColBookingCode,
      l.freightBookingColConfirmationNo,
      l.freightBookingShippingLineLabel,
      l.freightBookingColRoute,
      l.freightBookingColContainers,
      l.freightBookingColTotalFreight,
      l.freightBookingColStatus,
    ];
    final rows = bookings.map((b) => [
      b.bookingCode,
      b.bookingConfirmationNo ?? '—',
      b.shippingLineName ?? '—',
      '${b.polName ?? "-"} -> ${b.podName ?? "-"}',
      b.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', '),
      b.totalFreightCostUsd == null ? CcFormat.unknown : '\$${b.totalFreightCostUsd!.toStringAsFixed(2)}',
      b.status,
    ]).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Freight Booking',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: 'Freight Bookings Registry',
        subtitle: 'Sorour Logistics ERP — سجل حجوزات الشحن والناقلين',
        metadata: {
          'Total Bookings': bookings.length.toString(),
          'Confirmed': bookings.where((b) => b.status == 'Confirmed' || b.status == 'Amended').length.toString(),
          'Total USD': '\$${bookings.fold(0.0, (acc, b) => acc + (b.totalFreightCostUsd ?? 0)).toStringAsFixed(2)}',
        },
      ),
    );
  }
}
