import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/widgets/delivery_order_payment_dialog.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CS-02: DeliveryOrderPaymentDialog Widget Tests', () {
    testWidgets('CS-02 starts with empty DO number, fee, and free days when not on file', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 77,
        importFileCode: 'IMP-2026-0077',
        customFileNumber: 'CF-7788',
        companyName: 'Al-Madina Trading',
        supplierName: 'Mediterranean Logistics Corp',
        portOfDischarge: 'Alexandria Port',
        deliveryOrderNo: null,
        targetFreeDays: null,
        currentModule: 'Phase 6 - Customs Preparation',
        currentStage: 'Customs Broker Authorized',
        progressPercent: 81.0,
        nextAction: 'سداد إذن التسليم الملاحي واستلام D/O (CS-02)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
      );

      final fakeLines = [
        PartnerModel(
          providerId: 22,
          partnerCode: 'MSK-01',
          partnerName: 'Maersk Line Egypt',
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
            allPartnersProvider.overrideWith((ref) => FakeShippingPartnersNotifier(fakeLines)),
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

      // Ensure no invented DO-LINE or fixed fees like 12500 are present
      expect(find.textContaining('DO-LINE'), findsNothing);
      expect(find.textContaining('12500'), findsNothing);

      // Verify fields exist
      expect(find.byKey(const Key('doNumberField')), findsOneWidget);
      expect(find.byKey(const Key('doFeesField')), findsOneWidget);
      expect(find.byKey(const Key('freeDaysField')), findsOneWidget);

      // Verify fields start empty
      final doNumField = tester.widget<TextFormField>(find.byKey(const Key('doNumberField')));
      expect(doNumField.controller?.text, isEmpty);

      final feesField = tester.widget<TextFormField>(find.byKey(const Key('doFeesField')));
      expect(feesField.controller?.text, isEmpty);

      final freeDaysField = tester.widget<TextFormField>(find.byKey(const Key('freeDaysField')));
      expect(freeDaysField.controller?.text, isEmpty);

      // Tapping submit triggers validation errors for required fields
      await tester.tap(find.byKey(const Key('submitDeliveryOrderBtn')));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال رقم إذن التسليم الملاحي'), findsOneWidget);
      expect(find.text('يرجى إدخال قيمة مصاريف التوكيل'), findsOneWidget);
      expect(find.text('يرجى تحديد أيام السماح'), findsOneWidget);
    });
  });
}

class FakeShippingPartnersNotifier extends AllPartnersNotifier {
  final List<PartnerModel> _fakeList;

  FakeShippingPartnersNotifier(this._fakeList) : super(dio: Dio()) {
    state = AsyncValue.data(_fakeList);
  }

  @override
  Future<void> fetchPartners() async {
    state = AsyncValue.data(_fakeList);
  }
}
