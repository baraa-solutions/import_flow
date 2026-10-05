import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/api_error_text.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/cbm_calculator/models/cbm_calculator_model.dart';
import 'package:frontend/features/customs_consultation/models/customs_consultation_model.dart';
import 'package:frontend/features/customs_consultation/widgets/tariff_missing_widgets.dart';
import 'package:frontend/features/import_requirements/models/import_requirement_model.dart';
import 'package:frontend/features/import_requirements/widgets/prefill_messages_banner.dart';

import '../helpers/localized_app.dart';

const AppLocalizations _en = AppLocalizationsEn();
const AppLocalizations _ar = AppLocalizationsAr();

DioException _dioError(int status, Object? data) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: data),
    type: DioExceptionType.badResponse,
  );
}

CBMCalculationModel _calc(Map<String, dynamic> extra) => CBMCalculationModel.fromJson({
      'calc_code': 'CBM-1',
      ...extra,
    });

void main() {
  group('CBM calculator: coded recommendation', () {
    test('shipping method and container are shown as labels, never as codes', () {
      final c = _calc({
        'recommended_shipping_method': 'FCL',
        'recommended_container_type': 'C40_HC',
        'recommended_container_count': 2,
      });
      expect(c.shippingMethodLabel(_en), 'FCL Container');
      expect(c.shippingMethodLabel(_ar), 'حاوية كاملة (FCL)');
      expect(c.containerTypeLabel(_en), contains('High Cube'));
      expect(c.containerTypeLabel(_ar), contains('40'));
      expect(c.recommendedContainersLabel(_en), '2 x ${c.containerTypeLabel(_en)}');
      expect(c.containerTypeLabel(_en), isNot('C40_HC'));
    });

    test('air has no container', () {
      final c = _calc({'recommended_shipping_method': 'AIR', 'recommended_container_type': null});
      expect(c.isAirRecommended, isTrue);
      expect(c.shippingMethodLabel(_en), 'Air Freight');
      expect(c.containerTypeLabel(_en), '-');
      expect(c.recommendedContainersLabel(_en), '-');
    });

    test('rows saved before the codes (legacy labels) still render', () {
      final c = _calc({
        'recommended_shipping_method': 'LCL Ocean Freight (شحن بحري تجميعي)',
        'recommended_container_type': "40FT High Cube Containers (40' HC)",
      });
      expect(c.shippingMethodLabel(_en), 'LCL Ocean Freight');
      expect(c.containerTypeLabel(_en), contains('High Cube'));
      expect(c.isAirRecommended, isFalse);
    });

    test('"<n> x CODE" container text and the new int counts', () {
      final c = _calc({
        'smart_hybrid_containers': '3 x C40_HC',
        'flat_only_containers': '5 x C40_HC',
        'smart_hybrid_containers_count': 3,
        'flat_only_containers_count': 5,
      });
      expect(c.smartHybridContainersCount, 3);
      expect(c.flatOnlyContainersCount, 5);
      expect(c.smartHybridContainersLabel(_en), '3 x ${_en.domainEnumLabel('container_type', 'C40_HC')}');
      expect(containersText('1 x LCL', _ar), startsWith('1 x '));
      expect(containersText(null, _en), isNull);
      expect(containersText('free text', _en), 'free text');
      expect(containersText('2 x UNKNOWN', _en), '2 x UNKNOWN');
    });

    test('missing counts stay null (older rows)', () {
      final c = _calc({});
      expect(c.smartHybridContainersCount, isNull);
      expect(c.recommendedShippingMethod, isNull);
      expect(c.shippingMethodLabel(_en), '-');
    });

    test('local volumetric factor equals the backend default (x167)', () {
      expect(kAirVolumetricKgPerCbm, 167.0);
    });
  });

  group('Customs recalculation: TARIFF_MISSING', () {
    test('status and tariff_missing_lines_count are parsed', () {
      final r = CustomsRecalculationResponseModel.fromJson({
        'import_file_id': 1,
        'import_file_code': 'IMP-1',
        'tariff_missing_lines_count': 2,
        'comparison_lines': [
          {'item_name': 'A', 'hs_code': '', 'status': 'TARIFF_MISSING'},
          {'item_name': 'B', 'hs_code': '8501'},
        ],
      });
      expect(r.tariffMissingLinesCount, 2);
      expect(r.comparisonLines[0].isTariffMissing, isTrue);
      expect(r.comparisonLines[1].status, 'OK');
      expect(r.comparisonLines[1].isTariffMissing, isFalse);
    });

    test('both rates, currencies and the rate source are parsed and shown', () {
      final r = CustomsRecalculationResponseModel.fromJson({
        'import_file_id': 1,
        'exchange_rate': 49.5,
        'preliminary_exchange_rate': 48.25,
        'preliminary_currency': 'EUR',
        'final_currency': 'USD',
        'exchange_rate_source': 'manual',
      });
      expect(r.isManualRate, isTrue);
      expect(r.finalRateText, 'USD 49.5000');
      expect(r.preliminaryRateText, 'EUR 48.2500');
      final table = CustomsRecalculationResponseModel.fromJson({'import_file_id': 1, 'exchange_rate': 50});
      expect(table.isManualRate, isFalse);
      expect(table.preliminaryRateText, isNull);
      expect(table.finalRateText, '50.0000');
    });

    test('preliminary rate source is per side; the manual input applies only when currencies differ', () {
      final r = CustomsRecalculationResponseModel.fromJson({
        'import_file_id': 1,
        'preliminary_currency': 'EUR',
        'final_currency': 'USD',
        'exchange_rate_source': 'table',
        'preliminary_exchange_rate_source': 'manual',
      });
      expect(r.isManualRate, isFalse);
      expect(r.isPreliminaryManualRate, isTrue);
      expect(r.hasDifferentCurrencies, isTrue);
      final same = CustomsRecalculationResponseModel.fromJson({
        'import_file_id': 1,
        'preliminary_currency': 'USD',
        'final_currency': 'USD',
      });
      expect(same.hasDifferentCurrencies, isFalse);
      expect(same.isPreliminaryManualRate, isFalse);
    });

    test('CONSULTATION_EXISTS and CUSTOMS_MIXED_CURRENCY render from the catalog', () {
      final dup = _dioError(409, {
        'detail': {'code': 'CONSULTATION_EXISTS', 'message': 'عربي', 'consultation_code': 'CC-7', 'consultation_id': 7},
      });
      expect(ApiErrorText.of(_en, dup), contains('CC-7'));
      expect(ApiErrorText.of(_ar, dup), allOf(contains('CC-7'), isNot(contains('عربي'))));
      final mixed = _dioError(409, {
        'detail': {'code': 'CUSTOMS_MIXED_CURRENCY', 'message': 'م', 'currencies': 'USD, EUR'},
      });
      expect(ApiErrorText.of(_en, mixed), contains('USD, EUR'));
      expect(ApiErrorText.of(_ar, mixed), contains('USD, EUR'));
    });

    test('prefill currencies are optional (null-safe)', () {
      final p = ImportRequirementPrefillModel.fromJson({'import_file_id': 1, 'currency': null});
      expect(p.currency, isNull);
      final i = ImportRequirementHSCodeItemModel.fromJson({'hs_code': '8501'});
      expect(i.currency, isNull);
    });

    test('older responses without the new fields still parse', () {
      final r = CustomsRecalculationResponseModel.fromJson({'import_file_id': 1});
      expect(r.tariffMissingLinesCount, 0);
    });

    testWidgets('banner and badge render a warning in both languages', (tester) async {
      for (final locale in [AppLocales.english, AppLocales.arabic]) {
        await tester.pumpWidget(localizedApp(
          locale: locale,
          home: const Scaffold(
            body: Column(children: [TariffMissingBanner(count: 3), TariffMissingBadge()]),
          ),
        ));
        final l = locale == AppLocales.arabic ? _ar : _en;
        expect(find.text(l.tariffMissingLinesWarning(3)), findsOneWidget);
        expect(find.text(l.tariffMissingBadge), findsOneWidget);
      }
    });

    testWidgets('banner is hidden when no line is missing a tariff', (tester) async {
      await tester.pumpWidget(localizedApp(home: const Scaffold(body: TariffMissingBanner(count: 0))));
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('Import requirements: prefill contract', () {
    test('messages, empty hs_code_items and null defaults', () {
      final p = ImportRequirementPrefillModel.fromJson({
        'import_file_id': 7,
        'import_file_code': 'IMP-7',
        'hs_code_items': [],
        'coo_type': null,
        'inspection_body': null,
        'messages': [
          {'code': 'PREFILL_NO_HS', 'params': {'import_file_code': 'IMP-7'}},
          {'code': 'PREFILL_LINE_NO_HS', 'params': {'po_number': 'PO-1', 'item_code': 'X1'}},
          {'params': {}},
          'garbage',
        ],
      });
      expect(p.hsCodeItems, isEmpty);
      expect(p.cooType, isNull);
      expect(p.inspectionBody, isNull);
      expect(p.messages.map((m) => m.code), [PrefillMessage.noHs, PrefillMessage.lineNoHs]);
    });

    test('HS item keeps null unit / coo / inspection body / country', () {
      final i = ImportRequirementHSCodeItemModel.fromJson({'hs_code': '8501'});
      expect(i.unitOfMeasure, isNull);
      expect(i.cooType, isNull);
      expect(i.inspectionBody, isNull);
      expect(i.countryOfOrigin, isNull);
    });

    test('messages missing or not a list', () {
      expect(PrefillMessage.listFromJson(null), isEmpty);
      expect(PrefillMessage.listFromJson('x'), isEmpty);
    });

    test('prefill messages render from their code in both languages; unknown code is skipped', () {
      const noHs = PrefillMessage(code: PrefillMessage.noHs, params: {'import_file_code': 'IMP-7'});
      const line = PrefillMessage(code: PrefillMessage.lineNoHs, params: {'po_number': 'PO-1', 'item_code': 'X1'});
      expect(prefillMessageText(_en, noHs), contains('IMP-7'));
      expect(prefillMessageText(_ar, noHs), contains('IMP-7'));
      expect(prefillMessageText(_en, line), allOf(contains('PO-1'), contains('X1')));
      expect(prefillMessageText(_ar, const PrefillMessage(code: 'SOMETHING_NEW')), isNull);
    });

    testWidgets('banner lists the messages', (tester) async {
      await tester.pumpWidget(localizedApp(
        locale: AppLocales.english,
        home: const Scaffold(
          body: PrefillMessagesBanner(messages: [
            PrefillMessage(code: PrefillMessage.noHs, params: {'import_file_code': 'IMP-7'}),
          ]),
        ),
      ));
      expect(find.textContaining('IMP-7'), findsOneWidget);
    });
  });

  group('ApiErrorText', () {
    test('403 reads as a clear "no permission" message', () {
      final e = _dioError(403, {'detail': 'Forbidden'});
      expect(ApiErrorText.of(_en, e), _en.apiNoPermission);
      expect(ApiErrorText.of(_ar, e), _ar.apiNoPermission);
      expect(_en.apiNoPermission.toLowerCase(), contains('permission'));
    });

    test('409 CUSTOMS_FX_RATE_MISSING is rendered from the code', () {
      final e = _dioError(409, {
        'detail': {'code': 'CUSTOMS_FX_RATE_MISSING', 'message': 'عربي', 'currency': 'USD', 'on_date': '2026-09-01'},
      });
      expect(ApiErrorText.of(_en, e), allOf(contains('USD'), contains('2026')));
      expect(ApiErrorText.of(_ar, e), allOf(contains('USD'), contains('2026'), isNot(contains('عربي'))));
    });

    test('409 IR_ASSESSMENT_EXISTS is rendered from the code', () {
      final e = _dioError(409, {
        'detail': {'code': 'IR_ASSESSMENT_EXISTS', 'message': 'عربي', 'assessment_code': 'IRA-9', 'assessment_id': 9},
      });
      expect(ApiErrorText.code(e), 'IR_ASSESSMENT_EXISTS');
      expect(ApiErrorText.detail(e)!['assessment_id'], 9);
      expect(ApiErrorText.of(_en, e), contains('IRA-9'));
    });

    test('409 SCENARIO_SESSION_EXISTS is rendered from the code', () {
      final e = _dioError(409, {
        'detail': {'code': 'SCENARIO_SESSION_EXISTS', 'message': 'عربي', 'session_code': 'SES-4', 'session_id': 4},
      });
      expect(ApiErrorText.of(_en, e), contains('SES-4'));
      expect(ApiErrorText.of(_ar, e), allOf(contains('SES-4'), isNot(contains('عربي'))));
      expect(ApiErrorText.detail(e)!['session_id'], 4);
    });

    test('prefill messages carry a severity (default warning)', () {
      final m = PrefillMessage.listFromJson([
        {'code': 'PREFILL_NO_HS', 'params': {}, 'severity': 'error'},
        {'code': 'PREFILL_LINE_NO_HS'},
      ]);
      expect(m[0].severity, 'error');
      expect(m[1].severity, 'warning');
    });

    test('unknown code falls back to the backend message; plain detail is kept', () {
      expect(ApiErrorText.of(_en, _dioError(409, {'detail': {'code': 'NEW_CODE', 'message': 'hello'}})), 'hello');
      expect(ApiErrorText.of(_en, _dioError(422, {'detail': 'bad value'})), 'bad value');
      expect(ApiErrorText.of(_en, Exception('boom')), contains('boom'));
      expect(ApiErrorText.of(_en, Exception('boom'), fallback: 'x'), 'x');
    });

    test('PASSWORD_CHANGE_REQUIRED 403 is not reported as "no permission"', () {
      final e = _dioError(403, {
        'detail': {'code': 'PASSWORD_CHANGE_REQUIRED', 'message': 'Change password'},
      });
      expect(ApiErrorText.of(_en, e), isNot(_en.apiNoPermission));
    });
  });
}
