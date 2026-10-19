import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/services/freight_booking_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FreightBookingPdfService (FE04-T06)', () {
    const l = AppLocalizationsEn();

    final sampleBooking = ShipmentBookingModel(
      bookingId: 77,
      bookingCode: 'BK-2026-0077',
      bookingConfirmationNo: 'CONF-77-MSC',
      importFileId: 15,
      importFileCode: 'IMP-2026-0015',
      shippingLineName: 'MSC Mediterranean Shipping',
      freightForwarderName: 'Kuehne + Nagel',
      polName: 'Port of Ningbo',
      podName: 'Port of Alexandria',
      vesselName: 'MSC OSCAR',
      voyageNumber: '2604E',
      etd: '2026-10-15T00:00:00Z',
      eta: '2026-11-05T00:00:00Z',
      atd: '2026-10-16T00:00:00Z',
      expectedWarehouseArrivalDate: '2026-11-12T00:00:00Z',
      billOfLadingNo: 'MEDU12345678',
      totalFreightCostUsd: 4800.0,
      originalFreightCostUsd: 5200.0,
      costSavingsUsd: 400.0,
      status: 'Sailed',
      transitTimeDays: 21,
      departureDelayDays: 1,
      isActive: true,
      containersData: [
        ContainerAllocationModel(
          containerType: '40HC',
          quantity: 2,
          individualContainers: [
            SingleContainerItemModel(
              containerNumber: 'MSCU1234567',
              sealNumber: 'SEAL-001',
            ),
            SingleContainerItemModel(
              containerNumber: 'MSCU7654321',
              sealNumber: 'SEAL-002',
            ),
          ],
        ),
      ],
      costChargesData: [
        BookingChargeModel(
          chargeType: 'Ocean Freight (40HC)',
          unit: 'Container',
          rate: 2200.0,
          total: 4400.0,
          currency: 'USD',
        ),
        BookingChargeModel(
          chargeType: 'B/L Fee',
          unit: 'Bill',
          rate: 400.0,
          total: 400.0,
          currency: 'USD',
        ),
      ],
      createdAt: '2026-10-01T00:00:00Z',
      updatedAt: '2026-10-16T00:00:00Z',
    );

    test('build produces valid non-empty PDF bytes', () async {
      final bytes = await FreightBookingPdfService.build(
        booking: sampleBooking,
        l: l,
        fileCode: 'IMP-2026-0015',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));

      // Standard PDF magic header check: '%PDF-'
      final header = ascii.decode(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });
  });
}
