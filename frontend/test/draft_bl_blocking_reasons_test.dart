import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';

void main() {
  final coded = [
    {'code': 'DOC_DRAFT_BLOCKING_FIELD_EMPTY', 'params': {'field_enum_draft_bl_field': 'BOOKING_NO'}},
    {'code': 'DOC_DRAFT_BLOCKING_CRITICAL_MISMATCH', 'params': {'field_enum_draft_bl_field': 'CONSIGNEE'}},
  ];
  const stored = ['Critical field is empty: Booking Number', 'Critical mismatch in Consignee'];

  test('coded reasons render in English and Arabic', () {
    final en = displayBlockingReasons(AppLocalizationsEn(), stored, coded);
    expect(en, stored.map((s) => s.replaceAll('Consignee', 'Consignee Name, Address & Phone')).toList());
    final ar = displayBlockingReasons(AppLocalizationsAr(), stored, coded, forExport: true);
    expect(ar[0], 'حقل حرج فارغ: رقم الحجز (Booking Number)');
    expect(ar[1], 'اختلاف حرج في المستورد / المرسل إليه (Consignee)');
  });

  test('null coded list falls back to stored text', () {
    expect(displayBlockingReasons(AppLocalizationsAr(), stored, null), stored);
  });

  test('parseBlockingReasonsCoded', () {
    expect(parseBlockingReasonsCoded(null), isNull);
    expect(parseBlockingReasonsCoded(coded)!.length, 2);
  });
}
