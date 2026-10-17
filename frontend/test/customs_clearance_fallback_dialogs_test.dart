import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/customs_clearance/widgets/clearance_screen_dialogs.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_ui.dart';

import 'helpers/localized_app.dart';

class _CapturingNotifier extends CustomsClearanceNotifier {
  _CapturingNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  Map<String, dynamic>? payPayload;
  Map<String, dynamic>? releasePayload;

  @override
  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search, int skip = 0, int limit = 200}) async {
    state = const AsyncValue.data([]);
  }

  @override
  Future<CustomsClearanceModel?> submitDutyPayment(int recordId, Map<String, dynamic> payload) async {
    payPayload = payload;
    return null;
  }

  @override
  Future<CustomsClearanceModel?> completeRelease(int recordId, Map<String, dynamic> payload) async {
    releasePayload = payload;
    return null;
  }
}

CustomsClearanceModel _record() => CustomsClearanceModel(
      customsClearanceId: 7,
      clearanceCode: 'CLR-2026-0007',
      importFileId: 9,
      totalDutyPayable: 1000,
      actualDutyTotal: 1000,
      createdAt: '2026-08-23T00:00:00Z',
      updatedAt: '2026-08-23T00:00:00Z',
      owner: 'Admin',
    );

Future<void> _pump(WidgetTester tester, _CapturingNotifier notifier, Widget dialog) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [customsClearanceProvider.overrideWith((ref) => notifier)],
      child: localizedApp(home: Scaffold(body: dialog)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('CcFormat groups thousands and signs variances', () {
    expect(CcFormat.money(1234567.5), '1,234,567.50');
    expect(CcFormat.money(0), '0.00');
    expect(CcFormat.money(-999.999), '-1,000.00');
    expect(CcFormat.signedMoney(12), '+12.00');
    expect(CcFormat.signedMoney(-35.5), '-35.50');
    expect(CcFormat.date(DateTime(2026, 3, 5)), '2026-03-05');
  });

  testWidgets('pay-duty dialog sends the payment date (default today) and no bank when none picked',
      (tester) async {
    final notifier = _CapturingNotifier();
    await _pump(tester, notifier, ClearanceDutyPaymentFallbackDialog(record: _record()));

    expect(find.byKey(const Key('ccPaymentDateField')), findsOneWidget);
    expect(find.byKey(const Key('ccPayingBankField')), findsOneWidget);

    // Receipt number is the only required field the user has to fill.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'REC-77');
    await tester.tap(find.byType(AppButton).last);
    await tester.pumpAndSettle();

    final p = notifier.payPayload!;
    expect(p['bank_receipt_no'], 'REC-77');
    expect(p.containsKey('paying_bank_name'), isFalse);
    expect((p['payment_date'] as String).substring(0, 10), CcFormat.date(DateTime.now()));
  });

  testWidgets('complete-release dialog requires permit and sends the release date', (tester) async {
    final notifier = _CapturingNotifier();
    await _pump(tester, notifier, ClearanceFinalReleaseFallbackDialog(record: _record()));

    expect(find.byKey(const Key('ccReleaseDateField')), findsOneWidget);

    // Initial permit is empty, tap confirm triggers validator
    await tester.tap(find.byType(AppButton).last);
    await tester.pumpAndSettle();
    expect(notifier.releasePayload, isNull);

    // Enter valid permit number
    final permitField = find.byType(TextFormField).first;
    await tester.enterText(permitField, 'REL-CLR-2026-0007');
    await tester.tap(find.byType(AppButton).last);
    await tester.pumpAndSettle();

    final p = notifier.releasePayload!;
    expect(p['release_permit_no'], 'REL-CLR-2026-0007');
    expect((p['release_date'] as String).substring(0, 10), CcFormat.date(DateTime.now()));
  });
}
