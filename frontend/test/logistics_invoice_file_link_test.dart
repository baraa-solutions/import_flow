import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/logistics_invoices/widgets/invoice_form/invoice_form_basic_fields.dart';

/// Trello XpHTWi9u: a logistics invoice is bound to an import file picked from a searchable list
/// (never a typed numeric id defaulting to 1) and shows the file's project / cost center.
ImportFileModel _file(int id, String code, {String? projects}) => ImportFileModel.fromJson({
      'import_file_id': id,
      'import_file_code': code,
      'company_name': 'Sorour Logistics',
      'supplier_name': 'Supplier $id',
      'current_module': 'Closure',
      'current_stage': 'Phase 6',
      'next_action': 'Settle invoices',
      'project_names': projects,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

Widget _fields({int? shipmentId, bool isEditMode = false, ValueChanged<int?>? onChanged}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: InvoiceFormBasicFields(
          isArabic: false,
          isEditMode: isEditMode,
          partnerType: 'freight',
          onPartnerTypeChanged: (_) {},
          invoiceNumberCtrl: TextEditingController(),
          partnerNameCtrl: TextEditingController(),
          shipmentId: shipmentId,
          importFiles: [
            _file(11, 'IMP-2026-0011', projects: 'Sokhna Solar Plant'),
            _file(12, 'IMP-2026-0012'),
          ],
          blNumberCtrl: TextEditingController(),
          onShipmentIdChanged: onChanged ?? (_) {},
          onBlNumberChanged: (_) {},
          currency: 'USD',
          onCurrencyChanged: (_) {},
          exchangeRate: 50.0,
          onExchangeRateChanged: (_) {},
          onFetchCbeRate: () {},
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('no file is pre-selected and no project badge is shown', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_fields());
    expect(find.byKey(const ValueKey('invoiceImportFileField')), findsOneWidget);
    expect(find.text('IMP-2026-0011'), findsNothing);
    expect(find.byKey(const ValueKey('invoiceProjectBadge')), findsNothing);
  });

  testWidgets('the selected file shows its code and its project / cost center', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_fields(shipmentId: 11));
    expect(find.text('IMP-2026-0011'), findsOneWidget);
    expect(find.text('Project / Cost Center: Sokhna Solar Plant'), findsOneWidget);
  });

  testWidgets('a file without a project shows no badge', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_fields(shipmentId: 12));
    expect(find.text('IMP-2026-0012'), findsOneWidget);
    expect(find.byKey(const ValueKey('invoiceProjectBadge')), findsNothing);
  });
}
