import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/customs_tariff/widgets/anti_dumping_hazard_card.dart';

void main() {
  group('AntiDumpingHazardCard Tests', () {
    testWidgets('Renders AntiDumpingHazardCard in Arabic RTL when hasAntiDumpingRisk is true', (tester) async {
      final tariff = CustomsTariffModel(
        tariffId: 10,
        hsCode: '5703290000',
        hsDescription: 'سجاد وأغطية أرضيات أخر من نايلون',
        customsDutyRate: 60.0,
        vatRate: 14.0,
        scheduleTaxRate: 0.0,
        developmentFeeRate: 0.0,
        importFeeRate: 0.0,
        requiresCoo: true,
        requiresInspection: true,
        requiresAcid: true,
        effectiveFrom: DateTime(2026, 1, 1),
        isActive: true,
        hasAntiDumpingRisk: true,
        antiDumpingNotes: 'غ6555 - يراعى إيداع حصيلة رسم الإغراق والتدابير الوقائية لحساب وزارة الاستثمار والتجارة الخارجية',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: AntiDumpingHazardCard(tariff: tariff),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AntiDumpingHazardCard), findsOneWidget);
      expect(find.textContaining('إنذار جمركي حرج'), findsOneWidget);
      expect(find.textContaining('غ6555'), findsWidgets);
      expect(find.textContaining('وزارة الاستثمار والتجارة الخارجية'), findsWidgets);
    });

    testWidgets('Renders AntiDumpingHazardCard in English LTR when hasAntiDumpingRisk is true', (tester) async {
      final tariff = CustomsTariffModel(
        tariffId: 10,
        hsCode: '5703290000',
        hsDescription: 'Carpets',
        customsDutyRate: 60.0,
        vatRate: 14.0,
        scheduleTaxRate: 0.0,
        developmentFeeRate: 0.0,
        importFeeRate: 0.0,
        requiresCoo: true,
        requiresInspection: true,
        requiresAcid: true,
        effectiveFrom: DateTime(2026, 1, 1),
        isActive: true,
        hasAntiDumpingRisk: true,
        antiDumpingNotes: 'G6555 - Anti-dumping duty notice',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: AntiDumpingHazardCard(tariff: tariff),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AntiDumpingHazardCard), findsOneWidget);
      expect(find.textContaining('Critical Customs Hazard'), findsOneWidget);
      expect(find.textContaining('CRITICAL'), findsOneWidget);
    });

    testWidgets('Does not render when hasAntiDumpingRisk is false and notes empty', (tester) async {
      final tariff = CustomsTariffModel(
        tariffId: 11,
        hsCode: '8415820010',
        hsDescription: 'تكييفات',
        customsDutyRate: 60.0,
        vatRate: 14.0,
        scheduleTaxRate: 0.0,
        developmentFeeRate: 0.0,
        importFeeRate: 0.0,
        requiresCoo: true,
        requiresInspection: true,
        requiresAcid: true,
        effectiveFrom: DateTime(2026, 1, 1),
        isActive: true,
        hasAntiDumpingRisk: false,
        antiDumpingNotes: null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AntiDumpingHazardCard(tariff: tariff),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('إنذار جمركي حرج'), findsNothing);
      expect(find.textContaining('Critical Customs Hazard'), findsNothing);
    });
  });
}
