import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/export/export_language.dart';
import 'package:frontend/core/export/export_language_resolver.dart';
import 'package:frontend/core/export/export_translations.dart';
import 'package:frontend/core/export/widgets/export_language_dialog.dart';
import 'package:frontend/core/services/master_data_export_service.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ExportLanguage & Preferences Tests', () {
    test('ExportLanguage resolves from code correctly', () {
      expect(ExportLanguage.fromCode('ar'), ExportLanguage.ar);
      expect(ExportLanguage.fromCode('en'), ExportLanguage.en);
      expect(ExportLanguage.fromCode('english'), ExportLanguage.en);
      expect(ExportLanguage.fromCode(null), ExportLanguage.ar);
      expect(ExportLanguage.fromCode('unknown'), ExportLanguage.ar);
    });

    test('ExportLanguage persists and loads default option', () async {
      expect(await ExportLanguage.getSavedDefaultOption(), ExportLanguage.optionAsk);

      await ExportLanguage.saveDefaultOption(ExportLanguage.optionAr);
      expect(await ExportLanguage.getSavedDefaultOption(), ExportLanguage.optionAr);

      await ExportLanguage.saveDefaultOption(ExportLanguage.optionEn);
      expect(await ExportLanguage.getSavedDefaultOption(), ExportLanguage.optionEn);
    });

    test('ExportLanguage persists and loads last chosen language', () async {
      expect(await ExportLanguage.getLastChosenLanguage(), isNull);

      await ExportLanguage.saveLastChosenLanguage(ExportLanguage.en);
      expect(await ExportLanguage.getLastChosenLanguage(), ExportLanguage.en);

      await ExportLanguage.saveLastChosenLanguage(ExportLanguage.ar);
      expect(await ExportLanguage.getLastChosenLanguage(), ExportLanguage.ar);
    });
  });

  group('ExportTranslations & Single-Language Strictness Tests', () {
    test('ExportTranslations dictionary has no bilingual composite parenthesis strings', () {
      // Check that Arabic and English keys do not contain bilingual parenthesis mixes
      final testKeys = [
        'importer_card_title',
        'importer_card_subtitle',
        'active_record',
        'inactive_record',
        'doc_importer_card',
        'doc_vat_card',
        'doc_commercial_register',
        'cert_wipo',
        'cert_euipo',
        'cert_global_brand',
        'cert_iso9001',
      ];

      for (final key in testKeys) {
        final ar = ExportTranslations.tr(key, lang: ExportLanguage.ar);
        final en = ExportTranslations.tr(key, lang: ExportLanguage.en);

        // Neither should have "(Importer Card)" or "(Active)" composite patterns
        expect(ar.contains('(') && ar.contains('Active'), isFalse,
            reason: 'Key $key in Arabic contains un-isolated English parenthesis');
        expect(en.contains('(') && en.contains('سجل'), isFalse,
            reason: 'Key $key in English contains un-isolated Arabic parenthesis');
      }
    });

    test('Validity and Expiry calculations generate clean, single-language strings', () {
      // Arabic validity with days
      final arValF = ExportTranslations.validityWithDays(1586, lang: ExportLanguage.ar, feminine: true);
      expect(arValF, 'سارية (1586 يوم)');

      final arValM = ExportTranslations.validityWithDays(1586, lang: ExportLanguage.ar, feminine: false);
      expect(arValM, 'سارٍ (1586 يوم)');

      // English validity with days
      final enVal = ExportTranslations.validityWithDays(1586, lang: ExportLanguage.en);
      expect(enVal, 'Valid (1586 days)');

      // Expired statuses
      expect(ExportTranslations.expiredStatus(lang: ExportLanguage.ar, feminine: true), 'منتهية الصلاحية');
      expect(ExportTranslations.expiredStatus(lang: ExportLanguage.ar, feminine: false), 'منتهي الصلاحية');
      expect(ExportTranslations.expiredStatus(lang: ExportLanguage.en), 'Expired');

      // Short validity for Excel
      expect(ExportTranslations.shortValidity(true, lang: ExportLanguage.ar, feminine: true), 'سارية');
      expect(ExportTranslations.shortValidity(false, lang: ExportLanguage.ar, feminine: true), 'منتهية');
      expect(ExportTranslations.shortValidity(true, lang: ExportLanguage.ar, feminine: false), 'سارٍ');
      expect(ExportTranslations.shortValidity(false, lang: ExportLanguage.ar, feminine: false), 'منتهٍ');
      expect(ExportTranslations.shortValidity(true, lang: ExportLanguage.en), 'Valid');
      expect(ExportTranslations.shortValidity(false, lang: ExportLanguage.en), 'Expired');
    });

    test('Certificate registration and quality formatting is strictly separated', () {
      // WIPO / Brand
      expect(
        ExportTranslations.formatRegisteredStatus(hasRegistration: true, registrationNumber: null, lang: ExportLanguage.ar),
        'مسجل',
      );
      expect(
        ExportTranslations.formatRegisteredStatus(hasRegistration: true, registrationNumber: null, lang: ExportLanguage.en),
        'Registered',
      );
      expect(
        ExportTranslations.formatRegisteredStatus(hasRegistration: false, registrationNumber: null, lang: ExportLanguage.ar),
        'غير مسجل',
      );
      expect(
        ExportTranslations.formatRegisteredStatus(hasRegistration: false, registrationNumber: null, lang: ExportLanguage.en),
        'Not Registered',
      );

      // ISO
      expect(
        ExportTranslations.formatCertifiedStatus(hasCertificate: true, certificateNumber: null, lang: ExportLanguage.ar),
        'معتمد',
      );
      expect(
        ExportTranslations.formatCertifiedStatus(hasCertificate: true, certificateNumber: null, lang: ExportLanguage.en),
        'Certified',
      );
      expect(
        ExportTranslations.formatCertifiedStatus(hasCertificate: false, certificateNumber: null, lang: ExportLanguage.ar),
        'غير معتمد',
      );
      expect(
        ExportTranslations.formatCertifiedStatus(hasCertificate: false, certificateNumber: null, lang: ExportLanguage.en),
        'Not Certified',
      );
    });
  });

  group('ExportLanguageResolver Behavior Tests', () {
    test('Directionality and alignments match target language', () {
      const resAr = ExportLanguageResolver(lang: ExportLanguage.ar);
      expect(resAr.isArabic, isTrue);
      expect(resAr.textDirection, TextDirection.rtl);

      const resEn = ExportLanguageResolver(lang: ExportLanguage.en);
      expect(resEn.isArabic, isFalse);
      expect(resEn.textDirection, TextDirection.ltr);
    });

    test('bidiIsolate wraps Latin characters and digits in Arabic mode with LRI/PDI', () {
      const resAr = ExportLanguageResolver(lang: ExportLanguage.ar);
      const latinAddress = '7 HOSNI OSMAN ST. SEFARAT DISTRICT 11471 NASR CITY, CAIRO';
      final isolated = resAr.bidiIsolate(latinAddress);

      // Must start with LRI (\u2066) and end with PDI (\u2069)
      expect(isolated.startsWith('\u2066'), isTrue);
      expect(isolated.endsWith('\u2069'), isTrue);
      expect(isolated.contains(latinAddress), isTrue);

      // English mode does not add bidi characters
      const resEn = ExportLanguageResolver(lang: ExportLanguage.en);
      final enAddress = resEn.bidiIsolate(latinAddress);
      expect(enAddress.contains('\u2066'), isFalse);
      expect(enAddress, latinAddress);
    });

    test('buildFileName creates localized file names without invalid characters', () {
      const resAr = ExportLanguageResolver(lang: ExportLanguage.ar);
      final arName = resAr.buildFileName(
        prefixKey: 'importer_file_name_prefix',
        identifier: 'IMP-123456',
        extension: 'pdf',
      );
      expect(arName.startsWith('بطاقة_بيانات_الشركة_IMP-123456_'), isTrue);
      expect(arName.endsWith('.pdf'), isTrue);

      const resEn = ExportLanguageResolver(lang: ExportLanguage.en);
      final enName = resEn.buildFileName(
        prefixKey: 'importer_file_name_prefix',
        identifier: 'IMP-123456',
        extension: 'csv',
      );
      expect(enName.startsWith('Company_Data_Card_IMP-123456_'), isTrue);
      expect(enName.endsWith('.csv'), isTrue);
    });
  });

  group('ExportLanguageDialog Widget Tests', () {
    testWidgets('ExportLanguageDialog renders Arabic and English options with remember checkbox', (tester) async {
      ExportLanguage? selectedLang;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedLang = await ExportLanguageDialog.show(ctx, forcePrompt: true);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('تحديد لغة التحميل والتصدير'), findsOneWidget);
      expect(find.text('اللغة العربية (Arabic)'), findsOneWidget);
      expect(find.text('English (الإنجليزية)'), findsOneWidget);
      expect(find.text('تذكر اختياري كلغة افتراضية للتصدير'), findsOneWidget);
      expect(find.text('تأكيد وتنزيل'), findsOneWidget);

      // Switch to English and confirm
      await tester.tap(find.text('English (الإنجليزية)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تأكيد وتنزيل'));
      await tester.pumpAndSettle();

      expect(selectedLang, ExportLanguage.en);
    });

    testWidgets('ExportLanguageDialog respects saved default without opening dialog when configured', (tester) async {
      await ExportLanguage.saveDefaultOption(ExportLanguage.optionEn);

      ExportLanguage? selectedLang;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selectedLang = await ExportLanguageDialog.show(ctx);
                },
                child: const Text('Export Now'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Export Now'));
      await tester.pumpAndSettle();

      // No modal should be open!
      expect(find.text('تحديد لغة التحميل والتصدير'), findsNothing);
      expect(selectedLang, ExportLanguage.en);
    });
  });
}
