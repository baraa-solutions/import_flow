import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_broker_authorization_dialog.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CS-01: Customs Broker Electronic Authorization Model & Serialization Tests', () {
    test('CustomsClearanceModel parses and serializes broker delegation fields correctly', () {
      final json = {
        'customs_clearance_id': 101,
        'clearance_code': 'CLR-2026-0101',
        'import_file_id': 55,
        'declaration_46_no': null,
        'customs_office_name': 'Alexandria Port Customs',
        'broker_id': 18,
        'broker_name': 'شركة الأهرام للتخليص الجمركي',
        'delegation_number': 'DEL-2026-ALEX-01',
        'delegation_date': '2026-09-18T10:00:00Z',
        'delegation_status': 'Authorized',
        'authorization_notes': 'تفويض رسمي معتمد عبر منظومة نافذة MTS',
        'mandate_letter_code': 'LET-2026-0045',
        'channel_type': 'Red Channel',
        'status': 'Broker Authorized - Ready for 46',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T10:00:00Z',
      };

      final record = CustomsClearanceModel.fromJson(json);

      expect(record.customsClearanceId, 101);
      expect(record.clearanceCode, 'CLR-2026-0101');
      expect(record.importFileId, 55);
      expect(record.brokerId, 18);
      expect(record.brokerName, 'شركة الأهرام للتخليص الجمركي');
      expect(record.delegationNumber, 'DEL-2026-ALEX-01');
      expect(record.delegationStatus, 'Authorized');
      expect(record.authorizationNotes, contains('نافذة'));
      expect(record.mandateLetterCode, 'LET-2026-0045');

      final serialized = record.toJson();
      expect(serialized['broker_id'], 18);
      expect(serialized['broker_name'], 'شركة الأهرام للتخليص الجمركي');
      expect(serialized['delegation_number'], 'DEL-2026-ALEX-01');
      expect(serialized['delegation_status'], 'Authorized');
      expect(serialized['mandate_letter_code'], 'LET-2026-0045');
    });

    test('ImportFileModel parses customs broker delegation columns correctly', () {
      final json = {
        'import_file_id': 55,
        'import_file_code': 'IMP-2026-0055',
        'custom_file_number': 'Medical Devices',
        'company_name': 'Al-Amal Medical Supplies',
        'supplier_name': 'Siemens Healthineers',
        'broker_id': 18,
        'broker_name': 'شركة الأهرام للتخليص الجمركي',
        'customs_broker_delegation_no': 'DEL-2026-ALEX-01',
        'customs_broker_delegated_at': '2026-09-18T10:00:00Z',
        'customs_broker_authorization_status': 'Authorized',
        'current_module': 'Phase 6 - Customs Preparation',
        'current_stage': 'Customs Broker Authorized (تفويض المخلص الجمركي)',
        'progress_percent': 80.0,
        'next_action': 'سداد إذن التسليم الملاحي واستلام D/O (CS-02)',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T10:00:00Z',
      };

      final file = ImportFileModel.fromJson(json);

      expect(file.brokerId, 18);
      expect(file.brokerName, 'شركة الأهرام للتخليص الجمركي');
      expect(file.customsBrokerDelegationNo, 'DEL-2026-ALEX-01');
      expect(file.customsBrokerDelegatedAt, '2026-09-18T10:00:00Z');
      expect(file.customsBrokerAuthorizationStatus, 'Authorized');
      expect(file.progressPercent, 80.0);
      expect(file.nextAction, contains('CS-02'));

      final serialized = file.toJson();
      expect(serialized['customs_broker_delegation_no'], 'DEL-2026-ALEX-01');
      expect(serialized['customs_broker_delegated_at'], '2026-09-18T10:00:00Z');
      expect(serialized['customs_broker_authorization_status'], 'Authorized');
    });
  });

  group('CS-01: CustomsBrokerAuthorizationDialog Widget Tests', () {
    testWidgets('Renders CustomsBrokerAuthorizationDialog with form fields, title, and buttons', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 55,
        importFileCode: 'IMP-2026-0055',
        customFileNumber: 'Medical Devices',
        companyName: 'Al-Amal Medical Supplies',
        supplierName: 'Siemens Healthineers',
        brokerId: null,
        brokerName: null,
        portOfDischarge: 'Alexandria Port Customs',
        currentModule: 'Phase 5 - Sailing & CargoX',
        currentStage: 'Original Documents Collected',
        progressPercent: 75.0,
        nextAction: 'تعيين المخلص الجمركي والتفويض الإلكتروني (CS-01)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
      );

      final fakeBrokers = [
        PartnerModel(
          providerId: 10,
          partnerCode: 'BRK-01',
          partnerName: 'شركة النيل للتخليص الجمركي',
          partnerType: 'Customs Broker',
          clearanceLicenseNumber: 'LIC-2026-99',
          authorizedPorts: 'Alexandria',
          country: 'Egypt',
          paymentType: 'Cash',
          creditLimit: 0,
          rating: 4.5,
          isActive: true,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allPartnersProvider.overrideWith((ref) => FakeAllPartnersNotifier(fakeBrokers)),
          ],
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: CustomsBrokerAuthorizationDialog(file: sampleFile),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & File details
      expect(find.text('تعيين المخلص الجمركي والتفويض الإلكتروني (CS-01)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0055'), findsOneWidget);
      expect(find.textContaining('Siemens Healthineers'), findsOneWidget);

      // Verify Form Fields
      expect(find.byKey(const Key('delegationNumberField')), findsOneWidget);
      expect(find.byKey(const Key('customsOfficeDropdown')), findsOneWidget);
      expect(find.byKey(const Key('generateMandateLetterCheckbox')), findsOneWidget);
      expect(find.byKey(const Key('authorizationNotesField')), findsOneWidget);
      expect(find.byKey(const Key('confirmBrokerAuthorizationBtn')), findsOneWidget);
    });

    testWidgets('Renders CustomsBrokerAuthorizationDialog in English when locale is en', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 55,
        importFileCode: 'IMP-2026-0055',
        customFileNumber: 'Medical Devices',
        companyName: 'Al-Amal Medical Supplies',
        supplierName: 'Siemens Healthineers',
        brokerId: null,
        brokerName: null,
        portOfDischarge: 'Alexandria Port Customs',
        currentModule: 'Phase 5 - Sailing & CargoX',
        currentStage: 'Original Documents Collected',
        progressPercent: 75.0,
        nextAction: '(CS-01) Assign Customs Broker',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
      );

      final fakeBrokers = [
        PartnerModel(
          providerId: 10,
          partnerCode: 'BRK-01',
          partnerName: 'Nile Customs Clearance Co.',
          partnerType: 'Customs Broker',
          clearanceLicenseNumber: 'LIC-2026-99',
          authorizedPorts: 'Alexandria',
          country: 'Egypt',
          paymentType: 'Cash',
          creditLimit: 0,
          rating: 4.5,
          isActive: true,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allPartnersProvider.overrideWith((ref) => FakeAllPartnersNotifier(fakeBrokers)),
          ],
          child: AppLocalizationsProvider(
            locale: const Locale('en'),
            child: MaterialApp(
              locale: const Locale('en'),
              home: Scaffold(
                body: CustomsBrokerAuthorizationDialog(file: sampleFile),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & File details in English
      expect(find.text('(CS-01) Assign Customs Broker & E-Authorization'), findsOneWidget);
      expect(find.textContaining('Supplier: Siemens Healthineers'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('(CS-01) Approve & Authorize Broker'), findsOneWidget);
    });

    testWidgets('CS-01 starts with empty delegation number when not on file and does not invent DEL-', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 55,
        importFileCode: 'IMP-2026-0055',
        customFileNumber: 'Medical Devices',
        companyName: 'Al-Amal Medical Supplies',
        supplierName: 'Siemens Healthineers',
        brokerId: null,
        brokerName: null,
        customsBrokerDelegationNo: null,
        portOfDischarge: 'Alexandria Port Customs',
        currentModule: 'Phase 5 - Sailing & CargoX',
        currentStage: 'Original Documents Collected',
        progressPercent: 75.0,
        nextAction: 'تعيين المخلص الجمركي والتفويض الإلكتروني (CS-01)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
      );

      final fakeBrokers = [
        PartnerModel(
          providerId: 10,
          partnerCode: 'BRK-01',
          partnerName: 'شركة النيل للتخليص الجمركي',
          partnerType: 'Customs Broker',
          clearanceLicenseNumber: 'LIC-2026-99',
          authorizedPorts: 'Alexandria',
          country: 'Egypt',
          paymentType: 'Cash',
          creditLimit: 0,
          rating: 4.5,
          isActive: true,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allPartnersProvider.overrideWith((ref) => FakeAllPartnersNotifier(fakeBrokers)),
          ],
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: CustomsBrokerAuthorizationDialog(file: sampleFile),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the delegation number text field starts empty
      final delegationField = tester.widget<TextFormField>(find.byKey(const Key('delegationNumberField')));
      expect(delegationField.controller?.text, isEmpty);

      // Tap confirm button without filling delegation number
      await tester.tap(find.byKey(const Key('confirmBrokerAuthorizationBtn')));
      await tester.pumpAndSettle();

      // Expect validation error
      expect(find.text('رقم التفويض الإلكتروني إلزامي'), findsOneWidget);
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
