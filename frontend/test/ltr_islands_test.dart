import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/copyable_data_helper.dart';
import 'package:frontend/core/widgets/custom_text_field.dart';
import 'package:frontend/core/widgets/enterprise_data_table/enterprise_data_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';

class _Row {
  const _Row(this.code, this.amount);
  final String code;
  final String amount;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LTR islands inside the Arabic (RTL) app', () {
    testWidgets('CustomTextField: textDirection ltr applies to the value only', (tester) async {
      final ctrl = TextEditingController(text: '8536.41.00');
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: Column(children: [
            CustomTextField(controller: ctrl, label: 'رمز HS', textDirection: TextDirection.ltr),
            CustomTextField(controller: TextEditingController(), label: 'الوصف'),
          ]),
        ),
      ));

      final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      expect(fields[0].textDirection, TextDirection.ltr);
      // Without the param the field follows the ambient RTL direction.
      expect(Directionality.of(tester.element(find.byType(EditableText).at(1))), TextDirection.rtl);
      expect(fields[1].textDirection, isNull); // null = ambient (RTL)
      // Label stays Arabic/RTL.
      expect(Directionality.of(tester.element(find.text('رمز HS'))), TextDirection.rtl);
    });

    testWidgets('CustomTextField: required message is localized (Arabic)', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: CustomTextField(
              controller: TextEditingController(),
              label: 'رقم الحاوية',
              isRequired: true,
            ),
          ),
        ),
      ));
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('هذا الحقل مطلوب'), findsOneWidget);
    });

    testWidgets('CopyableText: textDirection is forwarded (plain and selectable)', (tester) async {
      await tester.pumpWidget(localizedApp(
        home: const Scaffold(
          body: Column(children: [
            CopyableText('-1,250.00', textDirection: TextDirection.ltr),
            CopyableText('MSCU1234567', textDirection: TextDirection.ltr, isSelectable: true),
            CopyableText('نص عادي'),
          ]),
        ),
      ));

      expect(tester.widget<Text>(find.text('-1,250.00')).textDirection, TextDirection.ltr);
      expect(tester.widget<SelectableText>(find.byType(SelectableText)).textDirection, TextDirection.ltr);
      expect(tester.widget<Text>(find.text('نص عادي')).textDirection, isNull);
    });

    testWidgets('EnterpriseDataTable: isNumeric cells are LTR, text cells follow RTL', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: EnterpriseDataTable<_Row>(
            data: const [_Row('شحنة', '-1,250.00')],
            columns: [
              EnterpriseColumn<_Row>(
                id: 'code',
                title: 'الاسم',
                cellBuilder: (_, r, __) => Text(r.code),
              ),
              EnterpriseColumn<_Row>(
                id: 'amount',
                title: 'المبلغ',
                isNumeric: true,
                cellBuilder: (_, r, __) => Text(r.amount),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(Directionality.of(tester.element(find.text('-1,250.00'))), TextDirection.ltr);
      expect(Directionality.of(tester.element(find.text('شحنة'))), TextDirection.rtl);
    });

    test('EnterpriseColumn defaults to the reading start and non-numeric', () {
      final col = EnterpriseColumn<_Row>(id: 'x', title: 'x', cellBuilder: (_, __, ___) => const SizedBox());
      expect(col.alignment, AlignmentDirectional.centerStart);
      expect(col.isNumeric, isFalse);
      expect(col.copyWith(isNumeric: true).isNumeric, isTrue);
    });
  });
}
