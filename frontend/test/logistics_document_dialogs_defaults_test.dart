import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/logistics_invoices/widgets/advance_payment_dialog.dart';
import 'package:frontend/features/logistics_invoices/widgets/document_party_selectors.dart';
import 'package:frontend/features/logistics_invoices/widgets/insurance_policy_dialog.dart';

/// Clearance advances and insurance policies open blank: no default file id 1, no made-up broker /
/// insurer / amount, and file + partner are picked from searchable lists (Trello yeYQfMBC / XpHTWi9u).
class _Files extends ImportFilesNotifier {
  _Files() : super(Dio()) {
    state = AsyncValue.data([
      ImportFileModel.fromJson({
        'import_file_id': 21,
        'import_file_code': 'IMP-2026-0021',
        'company_name': 'Co',
        'supplier_name': 'Sup',
        'current_module': 'm',
        'current_stage': 's',
        'next_action': 'n',
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      }),
    ]);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

class _Partners extends AllPartnersNotifier {
  _Partners() : super(dio: Dio());

  @override
  Future<void> fetchPartners() async {
    state = AsyncValue.data([
      PartnerModel(providerId: 1, partnerCode: 'BRK', partnerName: 'Delta Customs Brokers', partnerType: 'Customs Broker'),
      PartnerModel(providerId: 2, partnerCode: 'INS', partnerName: 'Misr Insurance', partnerType: 'Insurance Company'),
      PartnerModel(providerId: 3, partnerCode: 'FWD', partnerName: 'Global Forwarding', partnerType: 'Freight Forwarder'),
    ]);
  }
}

Future<void> _pump(WidgetTester tester, Widget dialog) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      importFilesProvider.overrideWith((ref) => _Files()),
      allPartnersProvider.overrideWith((ref) => _Partners()),
    ],
    child: MaterialApp(home: Scaffold(body: dialog)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('partner type filter keeps only the requested kind', () {
    final broker = PartnerModel(providerId: 1, partnerCode: 'B', partnerName: 'B', partnerType: 'Customs Broker');
    final insurer = PartnerModel(providerId: 2, partnerCode: 'I', partnerName: 'I', partnerType: 'Insurance Company');
    const brokerKeys = ['customs', 'broker', 'clearance', 'مستخلص', 'مخلص'];
    expect(PartnerSelectField.matchesType(broker, brokerKeys), isTrue);
    expect(PartnerSelectField.matchesType(insurer, brokerKeys), isFalse);
    expect(PartnerSelectField.matchesType(insurer, const ['insurance', 'تأمين']), isTrue);
  });

  testWidgets('clearance advance opens blank and requires file, broker and amount', (tester) async {
    await _pump(tester, const AdvancePaymentDialog());

    expect(find.text('IMP-2026-0021'), findsNothing);
    expect(find.text('Customs Clearance Partner'), findsNothing);
    expect(find.text('50000'), findsNothing);

    await tester.tap(find.text('Disburse Advance'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(2)); // import file + broker
    expect(find.text('Enter an amount greater than zero'), findsOneWidget);
  });

  testWidgets('a caller with a file context pre-selects that file only', (tester) async {
    await _pump(tester, const AdvancePaymentDialog(defaultShipmentId: 21));
    expect(find.text('IMP-2026-0021'), findsOneWidget);
  });

  testWidgets('insurance policy opens without a made-up insurer, policy number or insured value', (tester) async {
    await _pump(tester, const InsurancePolicyDialog());

    expect(find.text('Misr Insurance Co.'), findsNothing);
    expect(find.text('55000.0'), findsNothing);
    expect(find.text('Sorour Logistics / Financing Bank'), findsNothing);
    expect(find.textContaining('POL-'), findsNothing);

    await tester.tap(find.text('Issue Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);
  });
}
