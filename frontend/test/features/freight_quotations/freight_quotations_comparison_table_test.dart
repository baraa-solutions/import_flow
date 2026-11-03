import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/features/freight_quotations/widgets/freight_quotations_comparison_table.dart';
import '../../helpers/localized_app.dart';

void main() {
  testWidgets('FreightQuotationsComparisonTable renders quotes and award action', (tester) async {
    final quotes = [
      {
        'quotation_id': 101,
        'provider_name': 'Maersk Line',
        'total_cost': 4500.0,
        'ocean_freight_cost': 3800.0,
        'local_charges_cost': 700.0,
        'currency_code': 'USD',
        'transit_days': 24,
        'sailing_date': '2026-11-01',
        'estimated_arrival_date': '2026-11-25',
        'remarks': 'Direct sailing',
      },
      {
        'quotation_id': 102,
        'provider_name': 'MSC Shipping',
        'total_cost': 4200.0,
        'ocean_freight_cost': 3500.0,
        'local_charges_cost': 700.0,
        'currency_code': 'USD',
        'transit_days': 28,
        'sailing_date': '2026-11-03',
        'estimated_arrival_date': '2026-12-01',
        'remarks': 'Via Valencia',
      },
    ];

    int? selectedId;

    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 900,
            child: FreightQuotationsComparisonTable(
              quotations: quotes,
              selectedQuotationId: 101,
              onSelectQuotation: (id) => selectedId = id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maersk Line'), findsOneWidget);
    expect(find.text('MSC Shipping'), findsOneWidget);

    expect(find.byType(FreightQuotationsComparisonTable), findsOneWidget);
    expect(find.byType(SelectionArea), findsAtLeastNWidgets(1));

    // Tap the award AppButton for MSC (second quote)
    final appButtons = find.byType(AppButton);
    expect(appButtons, findsNWidgets(2));
    await tester.tap(appButtons.last);
    await tester.pumpAndSettle();

    expect(selectedId, equals(102));
  });
}
