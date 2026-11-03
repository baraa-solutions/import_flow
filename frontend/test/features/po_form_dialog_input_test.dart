// Field regressions on the "New Purchase Order" dialog (CTO report on v2.3.0):
//  1. a new PO must open with the master-data pickers EMPTY (no first-record pre-fill);
//  2. numeric fields must keep focus while typing (no per-keystroke key / controller churn);
//  3. Unit Price takes decimals; Net / Gross Wt take up to 16 decimals and the payload keeps the value;
//  5. a failed save (403) keeps the dialog usable and does not turn the PO list into an error page.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/widgets/searchable_dropdown_field.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/incoterms/models/incoterm_model.dart';
import 'package:frontend/features/incoterms/providers/incoterms_provider.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/purchase_orders/utils/po_row_list.dart';
import 'package:frontend/features/purchase_orders/widgets/po_decimal_field.dart';
import 'package:frontend/features/purchase_orders/widgets/po_form_dialog.dart';
import 'package:frontend/features/purchase_orders/widgets/po_form/po_form_items_tab.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pl03_purchase_order_test.dart'
    show
        MockCurrenciesNotifier,
        MockCustomsTariffNotifier,
        MockImportCompaniesNotifier,
        MockImportFilesNotifier,
        MockIncotermsNotifier,
        MockProjectsNotifier,
        MockSuppliersNotifier;

/// Captures the PO sent on save. With [forbidden] the REAL provider save runs against a Dio
/// that answers 403, exactly like the backend permission check.
class _CapturingPoNotifier extends PurchaseOrdersNotifier {
  _CapturingPoNotifier(Ref ref, {this.forbidden = false}) : super(_dio(forbidden), ref) {
    state = PurchaseOrdersState(purchaseOrders: const [], isLoading: false);
  }

  final bool forbidden;
  PurchaseOrderModel? saved;

  static Dio _dio(bool forbidden) {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 403, data: {'detail': 'Not enough permissions'}),
        type: DioExceptionType.badResponse,
      ));
    }));
    return dio;
  }

  @override
  Future<void> fetchPurchaseOrders() async {}

  @override
  Future<Object?> createPurchaseOrder(PurchaseOrderModel po) async {
    saved = po;
    if (!forbidden) return null;
    return super.createPurchaseOrder(po);
  }
}

class _EnLocale extends LocaleNotifier {
  _EnLocale() : super() {
    state = const Locale('en');
  }
  @override
  Future<void> toggleLocale() async {}
}

final _companies = [
  ImportCompanyModel(
    companyId: 1,
    importerName: 'Delta Industrial Supplies',
    address: '10th of Ramadan',
    country: 'Egypt',
    importerId: 'IMP-1122',
    importerIdExpiry: DateTime.now().add(const Duration(days: 365)),
    vatId: '123456789',
    vatIdExpiry: DateTime.now().add(const Duration(days: 365)),
    registrationNumber: '98765',
    registrationExpiry: DateTime.now().add(const Duration(days: 365)),
  ),
];

final _suppliers = [
  SupplierModel(
    supplierId: 10,
    supplierCode: 'SUP-010',
    companyName: 'Siemens Industrial GmbH',
    supplierType: 'Manufacturer',
    registrationType: 'CargoX',
    foreignExporterId: 'EXP-9900',
    foreignExporterCountry: 'Germany',
    foreignExporterCountryCode: 'DE',
    address: 'Munich, Germany',
  ),
];

final _projects = [
  ProjectModel(
    projectId: 100,
    projectCode: 'PRJ-100',
    projectName: 'Chiller Plant',
    projectOwner: 'Owner',
    companyId: 1,
    supplierId: 10,
    incotermId: 1,
    totalBudgetUsd: 100000.0,
    totalCommittedUsd: 0.0,
    poCount: 0,
    remainingBudgetUsd: 100000.0,
  ),
];

final _incoterms = [
  IncotermModel.fromJson({
    'incoterm_id': 1,
    'incoterm_code': 'FOB',
    'incoterm_name': 'Free On Board',
    'version': '2020',
    'is_active': true,
  }),
];

final _currencies = [
  CurrencyModel(
    currencyId: 1,
    currencyCode: 'USD',
    currencyName: 'US Dollar',
    currencySymbol: '\$',
    exchangeRates: [
      ExchangeRateModel(
        currencyId: 1,
        commercialRate: 48.5,
        customsRate: 48.5,
        effectiveDate: '2020-01-01',
      ),
    ],
  ),
  CurrencyModel(
    currencyId: 2,
    currencyCode: 'EUR',
    currencyName: 'Euro',
    currencySymbol: '€',
    exchangeRates: [],
  ),
];

Future<_CapturingPoNotifier> _pumpNewPoDialog(WidgetTester tester,
    {bool forbidden = false, Size size = const Size(1600, 1100)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => _EnLocale()),
        purchaseOrdersProvider.overrideWith((ref) => _CapturingPoNotifier(ref, forbidden: forbidden)),
        importCompaniesProvider.overrideWith((ref) => MockImportCompaniesNotifier(_companies)),
        suppliersProvider.overrideWith((ref) => MockSuppliersNotifier(_suppliers)),
        projectsProvider.overrideWith((ref) => MockProjectsNotifier(_projects)),
        incotermsProvider.overrideWith((ref) => MockIncotermsNotifier(ref, _incoterms)),
        currenciesProvider.overrideWith((ref) => MockCurrenciesNotifier(_currencies)),
        customsTariffProvider.overrideWith((ref) => MockCustomsTariffNotifier(ref, const [])),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier(const [])),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(
          body: AppLocalizationsProvider(
            locale: Locale('en'),
            child: POFormDialog(po: null),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(POFormDialog))).read(purchaseOrdersProvider.notifier)
      as _CapturingPoNotifier;
}

SearchableDropdownField _dropdown(WidgetTester tester, String labelStart) {
  final f = find.byWidgetPredicate((w) => w is SearchableDropdownField && w.labelText.startsWith(labelStart));
  expect(f, findsOneWidget, reason: 'dropdown "$labelStart"');
  return tester.widget<SearchableDropdownField>(f);
}

Finder _textField(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );

/// Focuses [field] once, then types [text] one character at a time through the SAME input
/// connection (what a user does). If the field is rebuilt as a new widget mid-typing the
/// connection is lost and the remaining characters never arrive.
Future<void> _typeCharByChar(WidgetTester tester, Finder field, String text) async {
  await tester.showKeyboard(field);
  await tester.pump();
  tester.testTextInput.updateEditingValue(const TextEditingValue(text: ''));
  await tester.pump();
  for (var i = 1; i <= text.length; i++) {
    final prefix = text.substring(0, i);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(text: prefix, selection: TextSelection.collapsed(offset: prefix.length)),
    );
    await tester.pump();
  }
}

/// The line total inside the items tab (the summary bar repeats the PO total).
Finder _lineTotal(String text) =>
    find.descendant(of: find.byType(POFormItemsTab), matching: find.text(text));

String _fieldText(WidgetTester tester, Finder field) => tester.widget<TextField>(field).controller!.text;

bool _fieldHasFocus(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText))).focusNode.hasFocus;

Future<void> _pick(WidgetTester tester, String labelStart, String itemLabel) async {
  final f = find.byWidgetPredicate((w) => w is SearchableDropdownField && w.labelText.startsWith(labelStart));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemLabel).last);
  await tester.pumpAndSettle();
}

Future<void> _selectAllRequired(WidgetTester tester) async {
  await _pick(tester, 'Project', 'PRJ-100 (Chiller Plant)');
  await _pick(tester, 'Importing Company', 'Delta Industrial Supplies');
  await _pick(tester, 'Supplier', 'Siemens Industrial GmbH');
  await _pick(tester, 'Incoterm', 'FOB (Free On Board)');
  await _pick(tester, 'Currency', 'USD (US Dollar)');
  await _pick(tester, 'Payment Terms', 'Letter of Credit');
}

Future<void> _save(WidgetTester tester) async {
  final l = AppLocalizations.of(tester.element(find.byType(POFormDialog)));
  await tester.tap(find.text(l.savePurchaseOrderBtn));
  await tester.pumpAndSettle();
  // Invoice / packing discrepancies open a justification dialog first.
  final justification = find.descendant(of: find.byType(AlertDialog).last, matching: find.byType(TextField));
  if (find.byType(AlertDialog).evaluate().length > 1 && justification.evaluate().isNotEmpty) {
    await tester.enterText(justification.first, 'test justification');
    await tester.pumpAndSettle();
    final buttons = find.descendant(of: find.byType(AlertDialog).last, matching: find.byType(InkWell));
    await tester.tap(buttons.last);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('PoRowList keys', () {
    test('an in-place copyWith edit keeps the row key; new / inserted rows get their own', () {
      final rows = PoRowList<POLineItemModel>([
        POLineItemModel(descriptionAr: 'a', quantity: 1, unitPrice: 1),
        POLineItemModel(descriptionAr: 'b', quantity: 1, unitPrice: 1),
      ]);
      final k0 = PoRowList.keyOf(rows[0]);
      final k1 = PoRowList.keyOf(rows[1]);
      expect(k0, isNot(k1));

      rows[0] = rows[0].copyWith(unitPrice: 2.5);
      expect(PoRowList.keyOf(rows[0]), k0);

      rows.insert(1, rows[0].copyWith(clearId: true)); // clone
      expect(PoRowList.keyOf(rows[1]), isNot(k0));
      rows.removeAt(1);
      expect(PoRowList.keyOf(rows[1]), k1, reason: 'removing a row never moves keys between rows');

      rows.replaceAsNew(0, rows[0].copyWith(descriptionAr: 'filled'));
      expect(PoRowList.keyOf(rows[0]), isNot(k0));
    });
  });

  group('PoDecimalField.formatForEditing', () {
    test('keeps full precision, drops a trailing .0, never uses an exponent', () {
      expect(PoDecimalField.formatForEditing(100), '100');
      expect(PoDecimalField.formatForEditing(123.45), '123.45');
      expect(PoDecimalField.formatForEditing(410.1234567), '410.1234567');
      expect(PoDecimalField.formatForEditing(0.0000001), '0.0000001');
    });
  });

  testWidgets('new PO opens with Project / Company / Supplier / Incoterm / Currency / Country / Payment Terms empty',
      (tester) async {
    await _pumpNewPoDialog(tester);

    expect(_dropdown(tester, 'Project').value, isNull);
    expect(_dropdown(tester, 'Importing Company').value, isNull);
    expect(_dropdown(tester, 'Supplier').value, isNull);
    expect(_dropdown(tester, 'Incoterm').value, isNull);
    expect(_dropdown(tester, 'Currency').value, isNull);
    expect(_dropdown(tester, 'Country of Origin').value, isNull);
    expect(_dropdown(tester, 'Payment Terms').value, isNull);
    // The "not specified" placeholder is not rendered as if it were a chosen country.
    expect(find.text('-- غير محدد (Auto / غير محدد) --'), findsNothing);
  });

  testWidgets('saving a new PO with no master data picked is blocked by the required-field check', (tester) async {
    final notifier = await _pumpNewPoDialog(tester);
    await _save(tester);
    expect(notifier.saved, isNull);
    expect(find.byType(POFormDialog), findsOneWidget);
  });

  testWidgets('typing "123.45" into Unit Price is continuous (focus kept) and keeps the decimal value', (tester) async {
    await _pumpNewPoDialog(tester);
    final price = _textField('Unit Price');
    await tester.ensureVisible(price);

    await _typeCharByChar(tester, price, '123.45');

    expect(_fieldText(tester, price), '123.45');
    expect(_fieldHasFocus(tester, price), isTrue, reason: 'the field must not be rebuilt/unfocused while typing');
    // Default line has qty 100: the line total proves the model holds 123.45.
    expect(_lineTotal('USD 12345.00'), findsOneWidget);
  });

  testWidgets('Qty keeps focus while typing several digits', (tester) async {
    await _pumpNewPoDialog(tester);
    final qty = _textField('Quantity');
    await tester.ensureVisible(qty);

    await _typeCharByChar(tester, qty, '250');

    expect(_fieldText(tester, qty), '250');
    expect(_fieldHasFocus(tester, qty), isTrue);
    expect(_lineTotal('USD 2500.00'), findsOneWidget); // 250 x default price 10
  });

  testWidgets('Net Wt / Gross Wt accept 16 decimals and the saved payload keeps the value', (tester) async {
    final notifier = await _pumpNewPoDialog(tester);
    await _selectAllRequired(tester);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await tester.pumpAndSettle();

    const typed = '410.1234567890123456';
    final net = _textField('Net Wt (KG)');
    await tester.ensureVisible(net);
    await _typeCharByChar(tester, net, typed);
    expect(_fieldText(tester, net), typed, reason: 'the typed text is never reformatted / rounded');
    expect(_fieldHasFocus(tester, net), isTrue);

    final gross = _textField('Gross Wt (KG)');
    await tester.ensureVisible(gross);
    await _typeCharByChar(tester, gross, '415.5');
    expect(_fieldText(tester, gross), '415.5');

    // A 17th decimal is refused by the input formatter.
    await _typeCharByChar(tester, net, '1.12345678901234567');
    expect(_fieldText(tester, net), '1.1234567890123456');
    await _typeCharByChar(tester, net, typed);

    await _save(tester);

    final saved = notifier.saved;
    expect(saved, isNotNull, reason: 'save must reach the provider');
    final row = saved!.packingListItems.first.toJson();
    expect(row['net_weight_unit_kg'], double.parse(typed));
    expect(row['gross_weight_unit_kg'], 415.5);
  });

  for (final size in const [Size(1366, 900), Size(390, 844)]) {
    testWidgets('packing tab (and the dialog title bar) lay out without overflow at ${size.width.toInt()} px',
        (tester) async {
      // Switch to the packing tab at desktop width first, then resize: only the title bar and the
      // packing tab are laid out at the target width (the line-items tab is out of this scope).
      await _pumpNewPoDialog(tester, size: const Size(1366, 900));
      await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
      await tester.pumpAndSettle();
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      // Any RenderFlex overflow is reported as a FlutterError and fails the test.
      expect(tester.takeException(), isNull);
      expect(find.text('Net Wt (KG)'), findsOneWidget);
    });
  }

  testWidgets('gross-weight pill follows the edited unit weight (not a stale stored total)', (tester) async {
    await _pumpNewPoDialog(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await tester.pumpAndSettle();
    // Default packing row: 10 packages. 10 x 7.25 = 72.5 kg.
    final gross = _textField('Gross Wt (KG)');
    await tester.ensureVisible(gross);
    await _typeCharByChar(tester, gross, '7.25');
    expect(find.text('72.5 kg'), findsWidgets);
  });

  testWidgets('a 403 on save keeps the dialog open and usable and leaves the PO list state clean', (tester) async {
    final notifier = await _pumpNewPoDialog(tester, forbidden: true);
    await _selectAllRequired(tester);

    await _save(tester);

    expect(notifier.saved, isNotNull);
    expect(find.byType(POFormDialog), findsOneWidget, reason: 'dialog stays open after a failed save');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(notifier.state.error, isNull, reason: 'a failed save must not replace the PO list with an error page');

    // Still editable and the save button is enabled again (not stuck in loading).
    final price = _textField('Unit Price');
    await tester.ensureVisible(price);
    await _typeCharByChar(tester, price, '7.5');
    expect(_fieldText(tester, price), '7.5');
  });

  testWidgets('no exchange rate means Save is blocked and the field shows the red helper text (FE01-T03)', (tester) async {
    final notifier = await _pumpNewPoDialog(tester);
    await _pick(tester, 'Project', 'PRJ-100 (Chiller Plant)');
    await _pick(tester, 'Importing Company', 'Delta Industrial Supplies');
    await _pick(tester, 'Supplier', 'Siemens Industrial GmbH');
    await _pick(tester, 'Incoterm', 'FOB (Free On Board)');
    await _pick(tester, 'Currency', 'EUR (Euro)');
    await _pick(tester, 'Payment Terms', 'Letter of Credit');

    // Verify helper text is shown indicating missing exchange rate
    expect(find.textContaining('No exchange rate found for EUR'), findsOneWidget);

    await _save(tester);

    expect(notifier.saved, isNull, reason: 'Save must be blocked when exchange rate is missing');
    expect(find.byType(POFormDialog), findsOneWidget, reason: 'Dialog must remain open');
    expect(find.text('Exchange rate is required and must be greater than zero'), findsOneWidget);
  });
}
