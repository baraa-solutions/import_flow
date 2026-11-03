import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/delivery_order_payment_dialog.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CS-02: Delivery Order Payment & Receipt Model & Serialization Tests', () {
    test('CustomsClearanceModel parses and serializes delivery order payment fields correctly', () {
      final json = {
        'customs_clearance_id': 202,
        'clearance_code': 'CLR-2026-0202',
        'import_file_id': 77,
        'customs_office_name': 'Alexandria Port Customs',
        'delivery_order_number': 'DO-MAEU-2026-9912',
        'delivery_order_date': '2026-09-18T11:00:00Z',
        'delivery_order_expiry': '2026-10-02T11:00:00Z',
        'free_days_allowed': 14,
        'shipping_agent_id': 15,
        'shipping_agent_name': 'Maersk Line Egypt',
        'delivery_order_fees': 14500.0,
        'delivery_order_currency': 'EGP',
        'delivery_order_payment_ref': 'RCPT-MSK-44001',
        'delivery_order_paid_at': '2026-09-18T11:00:00Z',
        'delivery_order_status': 'Paid & Received',
        'delivery_order_file_url': 'https://storage.sorourlogistics.com/docs/do_scan.pdf',
        'delivery_order_notes': 'تم استلام أصل إذن التسليم بعد سداد المصاريف إلكترونياً',
        'status': 'D/O Received - Ready for 46',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T11:00:00Z',
      };

      final record = CustomsClearanceModel.fromJson(json);

      expect(record.customsClearanceId, 202);
      expect(record.clearanceCode, 'CLR-2026-0202');
      expect(record.importFileId, 77);
      expect(record.deliveryOrderNumber, 'DO-MAEU-2026-9912');
      expect(record.deliveryOrderDate, '2026-09-18T11:00:00Z');
      expect(record.deliveryOrderExpiry, '2026-10-02T11:00:00Z');
      expect(record.freeDaysAllowed, 14);
      expect(record.shippingAgentId, 15);
      expect(record.shippingAgentName, 'Maersk Line Egypt');
      expect(record.deliveryOrderFees, 14500.0);
      expect(record.deliveryOrderCurrency, 'EGP');
      expect(record.deliveryOrderPaymentRef, 'RCPT-MSK-44001');
      expect(record.deliveryOrderStatus, 'Paid & Received');
      expect(record.deliveryOrderFileUrl, contains('do_scan.pdf'));
      expect(record.deliveryOrderNotes, contains('إلكترونياً'));

      final serialized = record.toJson();
      expect(serialized['delivery_order_number'], 'DO-MAEU-2026-9912');
      expect(serialized['delivery_order_fees'], 14500.0);
      expect(serialized['delivery_order_currency'], 'EGP');
      expect(serialized['delivery_order_payment_ref'], 'RCPT-MSK-44001');
      expect(serialized['delivery_order_status'], 'Paid & Received');
      expect(serialized['shipping_agent_id'], 15);
    });

    test('ImportFileModel parses and serializes delivery order tracking fields correctly', () {
      final json = {
        'import_file_id': 77,
        'import_file_code': 'IMP-2026-0077',
        'custom_file_number': 'Industrial Polymers',
        'company_name': 'Al-Nour Chemicals Co.',
        'supplier_name': 'Bavaria Chem GmbH',
        'bl_number': 'MAEU123456789',
        'delivery_order_no': 'DO-MAEU-2026-9912',
        'delivery_order_date': '2026-09-18T11:00:00Z',
        'delivery_order_expiry_date': '2026-10-02T11:00:00Z',
        'delivery_order_status': 'PAID_AND_RECEIVED',
        'current_module': 'Phase 6 - Customs Preparation',
        'current_stage': 'Delivery Order Paid & Received (سداد إذن التسليم الملاحي)',
        'progress_percent': 83.0,
        'next_action': 'قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T11:00:00Z',
      };

      final file = ImportFileModel.fromJson(json);

      expect(file.importFileId, 77);
      expect(file.deliveryOrderNo, 'DO-MAEU-2026-9912');
      expect(file.deliveryOrderStatus, 'PAID_AND_RECEIVED');
      expect(file.deliveryOrderDate, '2026-09-18T11:00:00Z');
      expect(file.deliveryOrderExpiryDate, '2026-10-02T11:00:00Z');
      expect(file.progressPercent, 83.0);
      expect(file.nextAction, contains('CS-03'));

      final serialized = file.toJson();
      expect(serialized['delivery_order_no'], 'DO-MAEU-2026-9912');
      expect(serialized['delivery_order_status'], 'PAID_AND_RECEIVED');
      expect(serialized['delivery_order_date'], '2026-09-18T11:00:00Z');
    });
  });

  group('CS-02: DeliveryOrderPaymentDialog Widget Tests', () {
    testWidgets('Renders DeliveryOrderPaymentDialog with form fields, shipment details, and buttons', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 77,
        importFileCode: 'IMP-2026-0077',
        customFileNumber: 'Industrial Polymers',
        companyName: 'Al-Nour Chemicals Co.',
        supplierName: 'Bavaria Chem GmbH',
        portOfDischarge: 'El Dekheila Port (non TMT)',
        targetFreeDays: 14,
        currentModule: 'Phase 6 - Customs Preparation',
        currentStage: 'Customs Broker Authorized',
        progressPercent: 80.0,
        nextAction: 'سداد إذن التسليم الملاحي واستلام D/O (CS-02)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
      );

      final fakeShippingLines = [
        PartnerModel(
          providerId: 15,
          partnerCode: 'LINE-MSK',
          partnerName: 'ميرسك إيجيبت للملاحة (Maersk Line)',
          partnerType: 'Shipping Line',
          country: 'Egypt',
          paymentType: 'Cash',
          creditLimit: 0,
          rating: 4.8,
          isActive: true,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allPartnersProvider.overrideWith((ref) => FakeAllPartnersNotifier(fakeShippingLines)),
          ],
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: DeliveryOrderPaymentDialog(file: sampleFile),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Shipment Details
      expect(find.text('سداد إذن التسليم الملاحي واستلامه (CS-02)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0077'), findsWidgets);
      expect(find.textContaining('Al-Nour Chemicals Co.'), findsOneWidget);
      expect(find.textContaining('Industrial Polymers'), findsOneWidget);
      expect(find.textContaining('Bavaria Chem GmbH'), findsOneWidget);

      // Verify Form Fields
      expect(find.byKey(const Key('shippingAgentDropdown')), findsOneWidget);
      expect(find.byKey(const Key('doNumberField')), findsOneWidget);
      expect(find.byKey(const Key('doFeesField')), findsOneWidget);
      expect(find.byKey(const Key('paymentRefField')), findsOneWidget);
      expect(find.byKey(const Key('fileUrlField')), findsOneWidget);
      expect(find.byKey(const Key('notesField')), findsOneWidget);
      expect(find.byKey(const Key('submitDeliveryOrderBtn')), findsOneWidget);
    });
  });
}

class FakeAllPartnersNotifier extends AllPartnersNotifier {
  final List<PartnerModel> _fakeList;

  FakeAllPartnersNotifier(this._fakeList) : super(dio: Dio()) {
    state = AsyncValue.data(_fakeList);
  }

  @override
  Future<void> fetchPartners() async {
    state = AsyncValue.data(_fakeList);
  }
}
