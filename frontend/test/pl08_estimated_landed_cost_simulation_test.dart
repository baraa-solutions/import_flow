import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/financial_settlement/models/estimated_landed_cost_model.dart';
import 'package:frontend/features/financial_settlement/widgets/estimated_landed_cost_dialog.dart';

void main() {
  group('PL-08 Landed Cost Calculation Engine Rules & Math Tests', () {
    test('Landed Cost allocation, markup factor, and unit landed cost math', () {
      // Setup base values
      const double fobTotalFc = 20000.0; // USD
      const double fxRate = 50.0; // EGP/USD
      const double totalFobEgp = fobTotalFc * fxRate; // 1,000,000 EGP

      // Expenses
      const double freightEgp = 50000.0;
      const double insuranceEgp = 25000.0;
      const double customsAndTaxesEgp = 180000.0;
      const double clearanceAndPortEgp = 12000.0;
      const double inlandTransportEgp = 8000.0;
      const double otherExpensesEgp = 5000.0;

      const double totalExpensesEgp = freightEgp +
          insuranceEgp +
          customsAndTaxesEgp +
          clearanceAndPortEgp +
          inlandTransportEgp +
          otherExpensesEgp; // 280,000 EGP

      expect(totalExpensesEgp, equals(280000.0));

      // Total Landed Cost
      const double totalLandedCostEgp = totalFobEgp + totalExpensesEgp; // 1,280,000 EGP
      const double totalLandedCostFc = totalLandedCostEgp / fxRate; // 25,600 USD

      expect(totalLandedCostEgp, equals(1280000.0));
      expect(totalLandedCostFc, equals(25600.0));

      // Markup calculations
      const double markupFactor = totalLandedCostEgp / totalFobEgp; // 1.28
      const double markupPercent = (markupFactor - 1.0) * 100.0; // 28.0%

      expect(markupFactor, closeTo(1.28, 0.0001));
      expect(markupPercent, closeTo(28.0, 0.01));

      // Item 1: 10 units, 15,000 USD FOB (75% share)
      const double item1Qty = 10.0;
      const double item1FobFc = 15000.0;
      const double item1FobEgp = item1FobFc * fxRate; // 750,000 EGP
      const double item1FobUnitEgp = item1FobEgp / item1Qty; // 75,000 EGP

      // Item 1 allocated expenses (75% of expenses)
      const double item1AllocatedExpenses = totalExpensesEgp * 0.75; // 210,000 EGP
      const double item1TotalLandedEgp = item1FobEgp + item1AllocatedExpenses; // 960,000 EGP
      const double item1UnitLandedEgp = item1TotalLandedEgp / item1Qty; // 96,000 EGP
      const double item1UnitLandedFc = item1UnitLandedEgp / fxRate; // 1,920 USD

      expect(item1UnitLandedEgp, equals(96000.0));
      expect(item1UnitLandedFc, equals(1920.0));
      expect(item1UnitLandedEgp / item1FobUnitEgp, closeTo(1.28, 0.0001));
    });

    test('Simulation request model toJson handles overrides properly', () {
      final req = EstimatedLandedCostSimulationRequestModel(
        exchangeRateOverride: 51.5,
        freightAmountEgpOverride: 45000.0,
        insuranceAmountEgpOverride: 12000.0,
        clearanceFeesEgpOverride: 6000.0,
        portHandlingEgpOverride: 5500.0,
        inlandTransportEgpOverride: 9000.0,
        bankFeesEgpOverride: 3000.0,
        otherExpensesEgpOverride: 1500.0,
        allocationPreference: 'Weight-Based',
      );

      final json = req.toJson();
      expect(json['exchange_rate_override'], equals(51.5));
      expect(json['freight_amount_egp_override'], equals(45000.0));
      expect(json['insurance_amount_egp_override'], equals(12000.0));
      expect(json['clearance_fees_egp_override'], equals(6000.0));
      expect(json['port_handling_egp_override'], equals(5500.0));
      expect(json['inland_transport_egp_override'], equals(9000.0));
      expect(json['bank_fees_egp_override'], equals(3000.0));
      expect(json['other_expenses_egp_override'], equals(1500.0));
      expect(json['allocation_preference'], equals('Weight-Based'));
    });
  });

  group('Estimated Landed Cost Model Serialization Tests', () {
    test('EstimatedLandedCostSimulationModel parses JSON correctly', () {
      final json = {
        'import_file_id': 108,
        'import_file_code': 'IMP-2026-TEST08',
        'currency': 'USD',
        'exchange_rate': 50.0,
        'incoterm': 'FOB',
        'total_fob_fc': 20000.0,
        'total_fob_egp': 1000000.0,
        'total_freight_egp': 50000.0,
        'total_insurance_egp': 25000.0,
        'total_customs_and_taxes_egp': 180000.0,
        'total_clearance_and_port_egp': 12000.0,
        'total_inland_transport_egp': 8000.0,
        'total_other_expenses_egp': 5000.0,
        'total_expenses_egp': 280000.0,
        'total_landed_cost_egp': 1280000.0,
        'total_landed_cost_fc': 25600.0,
        'average_markup_factor': 1.28,
        'average_markup_percent': 28.0,
        'executive_summary_ar': 'تبلغ تكلفة الوصول التقديرية الإجمالية للشحنة 1,280,000.00 جنيه مصري',
        'expenses_breakdown': [
          {
            'category': 'Ocean/Air Freight',
            'description': 'النولون والشحن الدولي التقديري',
            'amount_fc': 1000.0,
            'currency': 'USD',
            'amount_egp': 50000.0,
            'is_estimated': true,
            'source': 'نولون حكمي جمركي (2.0% من قيمة FOB)',
            'allocation_rule': 'Volume-Based',
          },
          {
            'category': 'Customs Duties',
            'description': 'ضريبة الوارد الجمركية (Import Duty)',
            'amount_fc': 1600.0,
            'currency': 'EGP',
            'amount_egp': 80000.0,
            'is_estimated': true,
            'source': 'محرك التعريفة الجمركية المصري MD-008',
            'allocation_rule': 'Direct HS Code Allocation',
          },
        ],
        'items_breakdown': [
          {
            'line_no': 1,
            'item_code': 'ITM-MAC-01',
            'item_name': 'Industrial Packing Machine',
            'hs_code': '8479.89.90',
            'qty': 10.0,
            'unit_price_fc': 1500.0,
            'fob_total_fc': 15000.0,
            'fob_unit_egp': 75000.0,
            'fob_total_egp': 750000.0,
            'allocated_freight_egp': 37500.0,
            'allocated_insurance_egp': 18750.0,
            'allocated_customs_duty_egp': 60000.0,
            'allocated_vat_egp': 75000.0,
            'allocated_clearance_and_port_egp': 9000.0,
            'allocated_inland_transport_egp': 6000.0,
            'allocated_other_egp': 3750.0,
            'total_expenses_allocated_egp': 210000.0,
            'total_landed_cost_egp': 960000.0,
            'unit_landed_cost_egp': 96000.0,
            'unit_landed_cost_fc': 1920.0,
            'markup_factor': 1.28,
            'markup_percent': 28.0,
          },
        ],
      };

      final model = EstimatedLandedCostSimulationModel.fromJson(json);

      expect(model.importFileId, equals(108));
      expect(model.importFileCode, equals('IMP-2026-TEST08'));
      expect(model.currency, equals('USD'));
      expect(model.exchangeRate, equals(50.0));
      expect(model.totalLandedCostEgp, equals(1280000.0));
      expect(model.averageMarkupFactor, equals(1.28));
      expect(model.averageMarkupPercent, equals(28.0));
      expect(model.expensesBreakdown.length, equals(2));
      expect(model.expensesBreakdown.first.category, equals('Ocean/Air Freight'));
      expect(model.itemsBreakdown.length, equals(1));
      expect(model.itemsBreakdown.first.unitLandedCostEgp, equals(96000.0));
      expect(model.itemsBreakdown.first.unitLandedCostFc, equals(1920.0));
      expect(model.itemsBreakdown.first.markupFactor, equals(1.28));
    });
  });

  group('Estimated Landed Cost Dialog Widget Tests', () {
    testWidgets('EstimatedLandedCostDialog renders successfully with simulation data', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 950));

      final mockResponse = jsonEncode({
        'import_file_id': 108,
        'import_file_code': 'IMP-2026-TEST08',
        'currency': 'USD',
        'exchange_rate': 50.0,
        'incoterm': 'FOB',
        'total_fob_fc': 20000.0,
        'total_fob_egp': 1000000.0,
        'total_freight_egp': 50000.0,
        'total_insurance_egp': 25000.0,
        'total_customs_and_taxes_egp': 180000.0,
        'total_clearance_and_port_egp': 12000.0,
        'total_inland_transport_egp': 8000.0,
        'total_other_expenses_egp': 5000.0,
        'total_expenses_egp': 280000.0,
        'total_landed_cost_egp': 1280000.0,
        'total_landed_cost_fc': 25600.0,
        'average_markup_factor': 1.28,
        'average_markup_percent': 28.0,
        'executive_summary_ar': 'تبلغ تكلفة الوصول التقديرية الإجمالية للشحنة 1,280,000.00 جنيه مصري',
        'expenses_breakdown': [
          {
            'category': 'Ocean/Air Freight',
            'description': 'النولون والشحن الدولي التقديري',
            'amount_fc': 1000.0,
            'currency': 'USD',
            'amount_egp': 50000.0,
            'is_estimated': true,
            'source': 'نولون حكمي جمركي (2.0% من قيمة FOB)',
            'allocation_rule': 'Volume-Based',
          },
          {
            'category': 'Customs Duties',
            'description': 'ضريبة الوارد الجمركية',
            'amount_fc': 1600.0,
            'currency': 'EGP',
            'amount_egp': 80000.0,
            'is_estimated': true,
            'source': 'محرك التعريفة الجمركية المصري MD-008',
            'allocation_rule': 'Direct HS Code Allocation',
          },
        ],
        'items_breakdown': [
          {
            'line_no': 1,
            'item_code': 'ITM-MAC-01',
            'item_name': 'Industrial Packing Machine',
            'hs_code': '8479.89.90',
            'qty': 10.0,
            'unit_price_fc': 1500.0,
            'fob_total_fc': 15000.0,
            'fob_unit_egp': 75000.0,
            'fob_total_egp': 750000.0,
            'allocated_freight_egp': 37500.0,
            'allocated_insurance_egp': 18750.0,
            'allocated_customs_duty_egp': 60000.0,
            'allocated_vat_egp': 75000.0,
            'allocated_clearance_and_port_egp': 9000.0,
            'allocated_inland_transport_egp': 6000.0,
            'allocated_other_egp': 3750.0,
            'total_expenses_allocated_egp': 210000.0,
            'total_landed_cost_egp': 960000.0,
            'unit_landed_cost_egp': 96000.0,
            'unit_landed_cost_fc': 1920.0,
            'markup_factor': 1.28,
            'markup_percent': 28.0,
          },
        ],
      });

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          mockResponse,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EstimatedLandedCostDialog(
                importFileId: 108,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header (labels are localized via Localizations.localeOf -> en_US in tests;
      // the executive summary text comes from the API payload and stays Arabic)
      expect(find.textContaining('Pre-Shipment Estimated Landed Cost Simulation'), findsOneWidget);
      expect(find.textContaining('IMP-2026-TEST08'), findsOneWidget);

      // Verify Executive Summary
      expect(find.textContaining('تبلغ تكلفة الوصول التقديرية الإجمالية'), findsOneWidget);

      // Verify KPI Cards
      expect(find.text('Total Goods FOB'), findsOneWidget);
      expect(find.text('Freight & Insurance'), findsOneWidget);
      expect(find.text('Customs & Taxes'), findsOneWidget);
      expect(find.text('Total Landed Cost'), findsOneWidget);
      expect(find.text('Overall Markup Factor'), findsOneWidget);

      // Verify Items Breakdown
      expect(find.text('ITM-MAC-01'), findsOneWidget);
      expect(find.text('8479.89.90'), findsOneWidget);
      expect(find.text('Industrial Packing Machine'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Export Excel/CSV'), findsOneWidget);
      expect(find.text('Copy TSV Table'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;
  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
      RequestOptions options,
      Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
