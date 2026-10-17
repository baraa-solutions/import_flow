import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';

void main() {
  group('Screen 62: Customs Clearance - Final Duty Payment & Release Localization Tests', () {
    const AppLocalizations ar = AppLocalizationsAr();
    const AppLocalizations en = AppLocalizationsEn();

    final List<String Function(AppLocalizations)> getters = [
      (l) => l.finalDutyScreenTitle,
      (l) => l.finalDutyScreenSubtitle,
      (l) => l.finalDutySummaryHeader,
      (l) => l.finalDutyKpiTotalPayable,
      (l) => l.finalDutyKpiOutstanding,
      (l) => l.finalDutyKpiTotalPaid,
      (l) => l.finalDutyKpiPendingPayment,
      (l) => l.finalDutyKpiNetVariance,
      (l) => l.finalDutyExportTsvBtn,
      (l) => l.finalDutyExportExcelBtn,
      (l) => l.finalDutyPrintPdfBtn,
      (l) => l.finalDutyCopyDossierBtn,
      (l) => l.finalDutyCopiedDossierSuccess,
      (l) => l.finalDutyCopiedTsvSuccess,
      (l) => l.finalDutyCopiedExcelSuccess,
      (l) => l.finalDutyCopyRowSummaryBtn,
      (l) => l.finalDutyCopyRowSummarySuccess,
      (l) => l.finalDutyCopyFieldTooltip,
      (l) => l.finalDutySearchHint,
      (l) => l.finalDutyFilterAll,
      (l) => l.finalDutyFilterPaid,
      (l) => l.finalDutyFilterPending,
      (l) => l.finalDutyFilterReleased,
      (l) => l.finalDutyEmptyRecords,
      (l) => l.finalDutyColBankReceipt,
      (l) => l.finalDutyColReleasePermit,
      (l) => l.finalDutyCurrencyEgp,
      (l) => l.finalDutyStatusPaidVerified,
      (l) => l.finalDutyStatusPendingPayment,
      (l) => l.finalDutyStatusReleased,
      (l) => l.finalDutyDossierHeader,
      (l) => l.finalDutyDossierKpiSummary,
      (l) => l.finalDutyDossierRecordsDetails,
      (l) => l.finalDutyPdfTitle,
      (l) => l.finalDutyPdfSubtitle,
    ];

    test('All Screen 62 getters return non-empty strings in both AR and EN', () {
      for (final getter in getters) {
        expect(getter(ar), isNotEmpty);
        expect(getter(en), isNotEmpty);
      }
    });

    test('Arabic strings contain strictly ZERO Latin characters [a-zA-Z]', () {
      final latinRegex = RegExp(r'[a-zA-Z]');
      for (final getter in getters) {
        final val = getter(ar);
        expect(
          latinRegex.hasMatch(val),
          isFalse,
          reason: 'String "$val" contains forbidden Latin characters',
        );
      }
    });

    test('Arabic strings contain strictly ZERO bilingual slashes [/]', () {
      for (final getter in getters) {
        final val = getter(ar);
        expect(
          val.contains('/'),
          isFalse,
          reason: 'String "$val" contains forbidden slash /',
        );
      }
    });
  });
}
