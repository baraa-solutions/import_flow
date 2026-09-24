import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/app_update/models/update_format.dart';

void main() {
  const ar = AppLocalizationsAr();
  const en = AppLocalizationsEn();
  // 202.8 MiB
  final bytes = (202.8 * 1024 * 1024).round();

  test('formatMegabytes: one decimal, western digits', () {
    expect(formatMegabytes(bytes), '202.8');
    expect(formatMegabytes(0), '0.0');
    expect(formatMegabytes(-5), '0.0');
    expect(formatMegabytes(1024 * 1024), '1.0');
  });

  test('size label in English and Arabic', () {
    expect(formatUpdateSize(en, bytes), '202.8 MB');
    expect(formatUpdateSize(ar, bytes), '202.8 ميجابايت');
  });

  test('download progress label in English and Arabic', () {
    final half = bytes ~/ 2;
    expect(formatUpdateProgress(en, half, bytes), 'Downloading… 101.4 of 202.8 MB');
    expect(formatUpdateProgress(ar, half, bytes), 'جاري التنزيل… 101.4 من 202.8 ميجابايت');
  });

  test('timestamp formatting', () {
    expect(formatUpdateTimestamp(null), '-');
    expect(formatUpdateTimestamp(DateTime(2026, 9, 4, 7, 5)), '2026-09-04 07:05');
  });
}
