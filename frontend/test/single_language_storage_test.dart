import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/localization/domain_enum_labels.dart';
import 'package:frontend/core/localization/stored_text.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/hold_shipment_at_stage_dialog.dart';
import 'package:frontend/core/widgets/table_row_clone_helper.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

import 'helpers/localized_app.dart';

/// Phase A of docs/plans/single-language-storage-plan.md: values the app
/// writes are codes / English, whatever the UI language.

const _ar = AppLocalizationsAr();
const _en = AppLocalizationsEn();

Map<String, dynamic> _fileJson() => {
      'import_file_id': 95,
      'import_file_code': 'IMP-2026-0095',
      'company_id': 1,
      'company_name': 'Delta Industrial Machinery LLC',
      'supplier_id': 2,
      'supplier_name': 'Bavaria Tech GmbH',
      'status': 'Active',
      'created_at': '2026-09-18T08:00:00Z',
      'updated_at': '2026-09-18T13:00:00Z',
    };

/// Dio that answers every request locally and records POST bodies.
Dio _fakeDio(List<RequestOptions> posts) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    if (options.method == 'POST') {
      posts.add(options);
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        ..._fileJson(),
        'status': 'On Hold',
      }));
    } else {
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: <dynamic>[]));
    }
  }));
  return dio;
}

void main() {
  group('DomainEnums', () {
    test('every code has a non-empty ar and en label', () {
      for (final entry in DomainEnums.codes.entries) {
        for (final code in entry.value) {
          expect(_ar.domainEnumLabel(entry.key, code), isNotEmpty, reason: '${entry.key}.$code ar');
          expect(_en.domainEnumLabel(entry.key, code), isNotEmpty, reason: '${entry.key}.$code en');
        }
      }
    });

    test('codes are UPPER_SNAKE (currency ISO)', () {
      final pattern = RegExp(r'^[A-Z0-9]+(_[A-Z0-9]+)*$');
      for (final codes in DomainEnums.codes.values) {
        for (final code in codes) {
          expect(pattern.hasMatch(code), isTrue, reason: code);
        }
      }
    });

    test('legacy labels map to their code', () {
      const cases = {
        DomainEnumType.releaseType: {'نهائي وبات (Final Green Release)': 'FINAL_GREEN'},
        DomainEnumType.paymentMethod: {
          'E-Finance / Sadad': 'SADAD_EFINANCE',
          'Sadad / E-Finance': 'SADAD_EFINANCE',
          'Bank Transfer / تحويل بنكي': 'BANK_TRANSFER',
        },
        DomainEnumType.dutyBank: {'البنك الأهلي المصري (NBE)': 'NBE', 'أخرى': 'OTHER'},
        DomainEnumType.clearanceExpenseCategory: {
          'Customs Broker Fees (أتعاب التخليص الجمركي)': 'BROKER_FEES',
        },
        DomainEnumType.truckType: {'Flatbed Trailer (تريلا مسطح)': 'FLATBED'},
        DomainEnumType.regulatoryBody: {
          'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)': 'GOEIC',
          'مصلحة الكيمياء المصرية (Chemistry Dept)': 'CHEMISTRY_DEPT',
        },
        DomainEnumType.inspectionYard: {'قرية البضائع - مطار القاهرة الدولي': 'CAIRO_AIRPORT_CARGO'},
        DomainEnumType.depot: {'Dekheila Yard (ساحة حاويات الدخيلة)': 'DEKHEILA_YARD'},
        DomainEnumType.clearanceServiceCategory: {
          'Clearance Fee': 'CLEARANCE_FEE',
          'أتعاب التخليص الجمركي': 'CLEARANCE_FEE',
          'Port & Demurrage Charges': 'PORT_CHARGES',
        },
        DomainEnumType.currency: {'جنيه': 'EGP'},
        DomainEnumType.brokerExpenseCategory: {'Port & Handling (موانئ وتعتيق وتفريغ)': 'PORT_HANDLING'},
        DomainEnumType.brokerUnit: {'Per Invoice (لكل فاتورة)': 'PER_INVOICE', 'per_container': 'PER_CONTAINER'},
        DomainEnumType.holdReason: {'تعليق إداري مؤقت للشحنة': 'ADMIN_HOLD'},
        DomainEnumType.skipReasonCategory: {'Other / أخرى': 'OTHER'},
      };
      cases.forEach((type, map) {
        map.forEach((legacy, code) {
          expect(DomainEnums.legacyToCode(type, legacy), code, reason: '$type: $legacy');
        });
      });
    });

    test('codes are idempotent, unknown values pass through', () {
      expect(DomainEnums.legacyToCode(DomainEnumType.releaseType, 'FINAL_GREEN'), 'FINAL_GREEN');
      expect(DomainEnums.legacyToCode(DomainEnumType.releaseType, 'something typed'), isNull);
      expect(DomainEnums.legacyToCode(DomainEnumType.releaseType, null), isNull);
      expect(DomainEnums.label(_ar, DomainEnumType.truckType, 'نقل خاص'), 'نقل خاص');
      expect(DomainEnums.label(_en, DomainEnumType.truckType, null, fallback: '-'), '-');
    });

    test('legacy rows display in the current language', () {
      const legacy = 'نهائي وبات (Final Green Release)';
      expect(DomainEnums.label(_en, DomainEnumType.releaseType, legacy), 'Final Green Release');
      expect(DomainEnums.label(_ar, DomainEnumType.releaseType, legacy), 'إفراج نهائي وبات');
      expect(DomainEnums.label(_en, DomainEnumType.clearanceExpenseCategory, 'Customs Broker Fees (أتعاب التخليص الجمركي)'),
          'Customs Broker Fees');
    });

    test('code argument wins over the stored text (hold_reason_code)', () {
      expect(
        DomainEnums.label(_ar, DomainEnumType.holdReason, 'Temporary administrative hold', code: 'ADMIN_HOLD'),
        'تعليق إداري مؤقت للشحنة',
      );
      expect(DomainEnums.englishLabel(DomainEnumType.holdReason, 'AWAITING_BANK_FORM4'), 'Awaiting bank Form 4 issuance');
    });

    test('initialCode falls back for empty / unknown values', () {
      expect(DomainEnums.initialCode(DomainEnumType.paymentMethod, null, 'SADAD_EFINANCE'), 'SADAD_EFINANCE');
      expect(DomainEnums.initialCode(DomainEnumType.paymentMethod, 'CBE Direct / خصم البنك المركزي', 'X'), 'CBE_DIRECT');
    });

    test('backend keyword aggregation still matches expense category codes', () {
      // modules/customs_clearance/service.py sums by lower-case keywords.
      bool has(String code, List<String> keys) => keys.any(code.toLowerCase().contains);
      const clearance = ['broker', 'أتعاب', 'تخليص', 'clearance'];
      const port = ['port', 'نولون', 'wharfage', 'storage', 'أرضيات', 'موانئ'];
      const handling = ['handling', 'stevedoring', 'عتالة', 'تفريغ', 'حمالة'];
      final codes = DomainEnums.codesOf(DomainEnumType.clearanceExpenseCategory);
      expect(codes, containsAll(['BROKER_FEES', 'PORT_DUES_WHARFAGE', 'STEVEDORING_HANDLING', 'STORAGE_DEMURRAGE']));
      expect(has('BROKER_FEES', clearance), isTrue);
      expect(has('PORT_DUES_WHARFAGE', port), isTrue);
      expect(has('STORAGE_DEMURRAGE', port), isTrue);
      expect(has('STEVEDORING_HANDLING', handling), isTrue);
      // Each code lands in at most one bucket (no double counting).
      for (final code in codes) {
        final hits = [has(code, clearance), has(code, port), has(code, handling)].where((h) => h).length;
        expect(hits, lessThanOrEqualTo(1), reason: code);
      }
    });
  });

  group('stored defaults are English', () {
    test('storedText is the English localization', () {
      expect(storedText.isArabic, isFalse);
      expect(storedText.calculationSessionTitle, _en.calculationSessionTitle);
    });

    test('clone suffixes are fixed constants', () {
      expect(TableRowCloneHelper.copySuffix, ' (Copy)');
      expect(TableRowCloneHelper.copyCodeSuffix, '-COPY');
      expect(TableRowCloneHelper.withCopySuffix('Title'), 'Title (Copy)');
      expect(TableRowCloneHelper.withCodeSuffix('PO-1'), 'PO-1-COPY');
      expect(TableRowCloneHelper.withCodeSuffix(null), isNull);
      expect(TableRowCloneHelper.withCopySuffix(''), '');
    });

    testWidgets('row clone appends the English suffix under the Arabic locale', (tester) async {
      final items = <Map<String, dynamic>>[
        {'id': 1, 'title': 'بند'},
      ];
      await tester.pumpWidget(localizedApp(
        locale: AppLocales.arabic,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TableRowCloneHelper.cloneMapRow(
                context: context,
                items: items,
                sourceIndex: 0,
                onListUpdated: () {},
                titleKey: 'title',
              ),
              child: const Text('clone'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('clone'));
      await tester.pump();
      expect(items, hasLength(2));
      expect(items[1]['title'], 'بند (Copy)');
      expect(items[1]['id'], isNull);
    });
  });

  group('hold request', () {
    test('predefined reason sends the code and the English label', () {
      final req = buildHoldRequest(
        reasonText: 'تعليق إداري مؤقت للشحنة',
        selectedReasonCode: 'ADMIN_HOLD',
        displayedReasonLabel: 'تعليق إداري مؤقت للشحنة',
        stageName: 'سداد الضرائب',
        stageNameEn: 'Duty Payment',
        stageCode: 'STEP_17',
      );
      expect(req.holdReasonCode, 'ADMIN_HOLD');
      expect(req.holdReason, 'Temporary administrative hold');
      expect(req.stageName, 'Duty Payment');
      expect(req.stepName, 'STEP_17');
    });

    test('edited or free text is sent as typed with no code', () {
      final req = buildHoldRequest(
        reasonText: 'تعليق إداري مؤقت للشحنة - لحين رد العميل',
        selectedReasonCode: 'ADMIN_HOLD',
        displayedReasonLabel: 'تعليق إداري مؤقت للشحنة',
        stageName: 'Duty Payment',
        stageNameEn: null,
        stageCode: '',
      );
      expect(req.holdReasonCode, isNull);
      expect(req.holdReason, 'تعليق إداري مؤقت للشحنة - لحين رد العميل');
      expect(req.stageName, 'Duty Payment');
      expect(req.stepName, isNull);
    });

    for (final locale in [AppLocales.arabic, AppLocales.english]) {
      testWidgets('dialog request body is language-independent (${locale.languageCode})', (tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final posts = <RequestOptions>[];
        final l = locale.languageCode == 'ar' ? _ar : _en;
        await tester.pumpWidget(ProviderScope(
          overrides: [dioProvider.overrideWithValue(_fakeDio(posts))],
          child: localizedApp(
            locale: locale,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => HoldShipmentAtStageDialog.show(
                    context,
                    importFile: ImportFileModel.fromJson(_fileJson()),
                    stageName: locale.languageCode == 'ar' ? 'سداد الضرائب والرسوم الجمركية' : 'Duty Payment',
                    stageNameEn: 'Duty Payment',
                    stageCode: 'STEP_17',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l.domainEnumLabel(DomainEnumType.holdReason, 'AWAITING_BANK_FORM4')!).first);
        await tester.pump();
        await tester.tap(find.text(l.confirmHoldActionBtn));
        await tester.pumpAndSettle();

        expect(posts, hasLength(1));
        final body = posts.single.data as Map<String, dynamic>;
        expect(posts.single.path, endsWith('/import-files/95/hold'));
        expect(body['hold_reason_code'], 'AWAITING_BANK_FORM4');
        expect(body['hold_reason'], 'Awaiting bank Form 4 issuance');
        expect(body['stage_name'], 'Duty Payment');
        expect(body['step_name'], 'STEP_17');
      });
    }
  });

  group('ImportFileModel hold_reason_code', () {
    test('parses the new field and tolerates old JSON', () {
      final coded = ImportFileModel.fromJson({..._fileJson(), 'hold_reason_code': 'ADMIN_HOLD'});
      expect(coded.holdReasonCode, 'ADMIN_HOLD');
      expect(coded.toJson()['hold_reason_code'], 'ADMIN_HOLD');
      final legacy = ImportFileModel.fromJson(_fileJson());
      expect(legacy.holdReasonCode, isNull);
    });
  });
}
