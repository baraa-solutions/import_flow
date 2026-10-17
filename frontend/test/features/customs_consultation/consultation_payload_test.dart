import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/customs_consultation/utils/customs_consultation_payload_builder.dart';

void main() {
  group('CustomsConsultationPayloadBuilder Tests (FE01-T02)', () {
    test('Test 1: Payload with null broker in tax-review mode has no broker_id or broker_name keys', () {
      final payload = CustomsConsultationPayloadBuilder.buildSavePayload(
        title: 'Tax Review Session 2026',
        brokerId: null,
        brokerName: null,
        estimatedDutiesEgp: 150000.0,
        totalBrokerFeesEgp: 0.0,
        checklistItems: [
          {'document_type': 'Commercial Invoice', 'is_required': true}
        ],
        isTaxReviewMode: true,
      );

      expect(payload['title'], 'Tax Review Session 2026');
      expect(payload.containsKey('broker_id'), isFalse,
          reason: 'broker_id must be absent when brokerId is null in tax-review mode');
      expect(payload.containsKey('broker_name'), isFalse,
          reason: 'broker_name must be absent when brokerName is null/empty in tax-review mode');
      expect(payload['estimated_duties_egp'], 150000.0);
      expect(payload['broker_quote_items'], isEmpty,
          reason: 'Tax-review mode must send empty broker_quote_items');
    });

    test('Test 2: Payload with selected broker in normal mode carries explicit broker details without defaults', () {
      final payload = CustomsConsultationPayloadBuilder.buildSavePayload(
        title: 'Alexandria Port Clearance Study',
        brokerId: 42,
        brokerName: 'Al-Bahr Customs Brokerage',
        brokerContactPerson: 'Hassan Mahmoud',
        brokerPriceListId: 7,
        importFileId: 105,
        estimatedDutiesEgp: 250000.0,
        totalBrokerFeesEgp: 12000.0,
        checklistItems: [
          {'document_type': 'Bill of Lading', 'is_required': true}
        ],
        brokerQuoteItems: [
          {'expense_name': 'Clearance Fee', 'total_amount': 12000.0, 'is_applicable': true}
        ],
        isTaxReviewMode: false,
      );

      expect(payload['broker_id'], 42);
      expect(payload['broker_name'], 'Al-Bahr Customs Brokerage');
      expect(payload['broker_contact_person'], 'Hassan Mahmoud');
      expect(payload['broker_price_list_id'], 7);
      expect(payload['import_file_id'], 105);
      expect(payload['estimated_duties_egp'], 250000.0);
      expect(payload['total_broker_fees_egp'], 12000.0);
      expect(payload['broker_quote_items'], isNotEmpty);
    });

    test('Test 3: Grep-guard asserting zero instances of `?? 1` or `Customs Review` in screen', () {
      final candidates = [
        File('lib/features/customs_consultation/screens/customs_consultation_screen.dart'),
        File('frontend/lib/features/customs_consultation/screens/customs_consultation_screen.dart'),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => candidates.first,
      );
      expect(file.existsSync(), isTrue, reason: 'Customs consultation screen file must exist');

      final content = file.readAsStringSync();

      expect(content.contains('_selectedBrokerId ?? 1'), isFalse,
          reason: 'Customs consultation screen must not invent broker id with `_selectedBrokerId ?? 1`');
      expect(content.contains("'Customs Review'"), isFalse,
          reason: "Customs consultation screen must not invent fallback broker name `'Customs Review'`");
    });
  });
}
