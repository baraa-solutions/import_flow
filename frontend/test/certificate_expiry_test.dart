import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/certificate_expiry.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';

/// Trello TJ6Guorp: certificate & Nafeza token expiry with a days-remaining badge.
void main() {
  final today = DateTime(2026, 6, 15, 23, 30);

  group('CertificateExpiry', () {
    test('days are counted on calendar days', () {
      expect(CertificateExpiry.daysLeft(DateTime(2026, 6, 16, 0, 5), today: today), 1);
      expect(CertificateExpiry.daysLeft(null, today: today), isNull);
    });

    // Egypt DST 2027 starts on Fri 30 Apr (23-hour day) and ends on Thu 28 Oct (25-hour day).
    // Run under `TZ=Africa/Cairo flutter test` as well as the default zone.
    test('DST spring-forward does not lose a day', () {
      expect(CertificateExpiry.daysLeft(DateTime(2027, 5, 1), today: DateTime(2027, 4, 1)), 30);
      expect(CertificateExpiry.daysLeft(DateTime(2027, 5, 1), today: DateTime(2027, 4, 29, 22)), 2);
      expect(CertificateExpiry.daysLeft(DateTime(2027, 4, 30), today: DateTime(2027, 5, 1)), -1);
      expect(CertificateExpiry.state(DateTime(2027, 4, 30), today: DateTime(2027, 5, 1, 9)),
          CertificateExpiryState.expired);
      expect(CertificateExpiry.label(DateTime(2027, 4, 30), isArabic: false, today: DateTime(2027, 5, 1)), 'Expired');
    });

    test('DST fall-back does not add a day', () {
      expect(CertificateExpiry.daysLeft(DateTime(2027, 11, 1), today: DateTime(2027, 10, 1)), 31);
      expect(CertificateExpiry.daysLeft(DateTime(2027, 10, 29), today: DateTime(2027, 10, 27, 23, 59)), 2);
      expect(CertificateExpiry.daysLeft(DateTime(2027, 10, 28), today: DateTime(2027, 10, 29)), -1);
      expect(CertificateExpiry.daysLeft(DateTime(2027, 10, 28), today: DateTime(2027, 10, 28, 23)), 0);
    });

    test('state boundaries: expired < 0 <= expiring soon <= 30 < valid', () {
      expect(CertificateExpiry.state(null, today: today), CertificateExpiryState.notSet);
      expect(CertificateExpiry.state(DateTime(2026, 6, 14), today: today), CertificateExpiryState.expired);
      expect(CertificateExpiry.state(DateTime(2026, 6, 15), today: today), CertificateExpiryState.expiringSoon);
      expect(CertificateExpiry.state(DateTime(2026, 7, 15), today: today), CertificateExpiryState.expiringSoon);
      expect(CertificateExpiry.state(DateTime(2026, 7, 16), today: today), CertificateExpiryState.valid);
    });

    test('labels in both languages', () {
      expect(CertificateExpiry.label(DateTime(2026, 6, 25), isArabic: true, today: today), 'متبقي للتجديد 10 يوم');
      expect(CertificateExpiry.label(DateTime(2026, 6, 25), isArabic: false, today: today), 'Renew in 10 d');
      expect(CertificateExpiry.label(DateTime(2026, 6, 1), isArabic: true, today: today), 'منتهي');
      expect(CertificateExpiry.label(null, isArabic: false, today: today), 'Not configured');
    });

    test('soonest ignores nulls', () {
      expect(CertificateExpiry.soonest([null, DateTime(2027, 1, 1), DateTime(2026, 9, 1)]), DateTime(2026, 9, 1));
      expect(CertificateExpiry.soonest([null]), isNull);
    });

    test('severity colours', () {
      expect(certificateExpirySeverity(CertificateExpiryState.expired), AppSeverity.danger);
      expect(certificateExpirySeverity(CertificateExpiryState.expiringSoon), AppSeverity.warning);
      expect(certificateExpirySeverity(CertificateExpiryState.valid), AppSeverity.success);
    });
  });

  group('models', () {
    final base = {
      'company_id': 1,
      'importer_name': 'Co',
      'country': 'Egypt',
      'address': 'Cairo',
      'importer_id': 'IMP-1',
      'importer_id_expiry': '2027-01-01',
      'vat_id': 'V',
      'vat_id_expiry': '2027-01-01',
      'registration_number': 'R',
      'registration_expiry': '2027-01-01',
      'is_active': true,
      'has_wipo': true,
      'wipo_expiry': '2026-12-01',
      'has_iso_9001': false,
      'iso_9001_expiry': '2026-07-01',
      'nafeza_token_expiry': '2026-10-01',
    };

    test('company parses, serializes and picks the soonest enabled expiry', () {
      final c = ImportCompanyModel.fromJson(base);
      expect(c.wipoExpiry, DateTime(2026, 12, 1));
      expect(c.toJson()['nafeza_token_expiry'], '2026-10-01');
      // ISO 9001 is not enabled, so its earlier date is ignored.
      expect(c.soonestCertificateExpiry, DateTime(2026, 10, 1));
    });

    test('rows saved before the feature have no expiry and no badge', () {
      final c = ImportCompanyModel.fromJson({...base}..removeWhere((k, _) => k.endsWith('_expiry') && k != 'importer_id_expiry' && k != 'vat_id_expiry' && k != 'registration_expiry'));
      expect(c.soonestCertificateExpiry, isNull);
    });

    test('supplier round-trips certificate expiries', () {
      final s = SupplierModel.fromJson({
        'supplier_id': 3,
        'supplier_code': 'SUP-3',
        'company_name': 'Exporter',
        'has_euipo': true,
        'euipo_expiry': '2026-08-01',
      });
      expect(s.euipoExpiry, DateTime(2026, 8, 1));
      expect(s.toJson()['euipo_expiry'], '2026-08-01');
      expect(s.soonestCertificateExpiry, DateTime(2026, 8, 1));
    });
  });

  testWidgets('badge renders the remaining days', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CertificateExpiryBadge(
          expiry: DateTime.now().add(const Duration(days: 400)),
          isArabic: false,
          prefix: 'Certificates',
        ),
      ),
    ));
    expect(find.textContaining('Certificates: Valid ('), findsOneWidget);
  });
}
