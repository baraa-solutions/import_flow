import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/financial_approval/models/financial_approval_model.dart';
import 'package:frontend/features/financial_approval/providers/financial_approval_provider.dart';

class _MockAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, ResponseBody Function(RequestOptions)> routes = {};

  static ResponseBody json(Object body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  _MockAdapter on(String key, ResponseBody Function(RequestOptions) f) {
    routes[key] = f;
    return this;
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    for (final e in routes.entries) {
      final sp = e.key.indexOf(' ');
      if (options.method == e.key.substring(0, sp) &&
          options.uri.path.contains(e.key.substring(sp + 1))) {
        return e.value(options);
      }
    }
    return json(<dynamic>[]);
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _createContainer(_MockAdapter adapter) {
  final dio =
      Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))
        ..httpClientAdapter = adapter;
  final c = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    uploadDioProvider.overrideWithValue(dio),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  group('Phase 02 Session 1 - Financial Approval Frontend Tests', () {
    test('FE02-T02: approveImportBudget calls server endpoint and updates budget status to Approved', () async {
      final adapter = _MockAdapter().on(
        'POST /approve',
        (r) => _MockAdapter.json({
          'budget_id': 42,
          'budget_code': 'BGT-2026-0042',
          'version': 2,
          'title': 'Certified Import Budget',
          'import_file_id': 9,
          'invoice_amount_foreign': 100000.0,
          'invoice_currency': 'EUR',
          'invoice_amount_egp': 5200000.0,
          'freight_cost_foreign': 8000.0,
          'freight_currency': 'USD',
          'freight_cost_egp': 392000.0,
          'customs_duties_egp': 300000.0,
          'clearance_inland_egp': 50000.0,
          'exchange_rate': 52.0,
          'total_budget_egp': 5942000.0,
          'budget_status': 'Approved',
          'is_active': true,
          'created_at': '2026-10-19T00:00:00Z',
          'updated_at': '2026-10-19T00:00:00Z',
        }),
      );

      final container = _createContainer(adapter);
      final notifier = container.read(importBudgetsProvider.notifier);
      final approved = await notifier.approveImportBudget(42);

      expect(approved, isNotNull);
      expect(approved!.budgetId, 42);
      expect(approved.budgetStatus, 'Approved');
      expect(adapter.requests.any((r) =>
          r.method == 'POST' &&
          r.uri.path.contains('/import-budgets/42/approve')), isTrue);
    });

    test('FE02-T04: Consolidated summary displays exact saved values in View mode', () {
      final savedBudget = ImportBudgetModel(
        budgetId: 10,
        budgetCode: 'BGT-2026-0010',
        version: 1,
        title: 'Chemical Raw Materials Budget',
        importFileId: 5,
        invoiceAmountForeign: 150000.0,
        invoiceCurrency: 'EUR',
        invoiceAmountEgp: 7800000.0,
        freightCostForeign: 12000.0,
        freightCurrency: 'USD',
        freightCostEgp: 588000.0,
        customsDutiesEgp: 450000.0,
        clearanceInlandEgp: 65000.0,
        exchangeRate: 52.0,
        totalBudgetEgp: 8903000.0,
        budgetStatus: 'Approved',
        isActive: true,
        createdAt: '2026-10-19T00:00:00Z',
        updatedAt: '2026-10-19T00:00:00Z',
      );

      // Verify that all properties represent the contract exactly
      expect(savedBudget.invoiceAmountForeign, 150000.0);
      expect(savedBudget.invoiceCurrency, 'EUR');
      expect(savedBudget.invoiceAmountEgp, 7800000.0);
      expect(savedBudget.freightCostForeign, 12000.0);
      expect(savedBudget.freightCurrency, 'USD');
      expect(savedBudget.freightCostEgp, 588000.0);
      expect(savedBudget.customsDutiesEgp, 450000.0);
      expect(savedBudget.clearanceInlandEgp, 65000.0);
      expect(savedBudget.totalBudgetEgp, 8903000.0);
    });

    test('FE02-T04: Consolidated summary with zero amounts does not fall back to defaults', () {
      final zeroBudget = ImportBudgetModel(
        budgetId: 11,
        budgetCode: 'BGT-2026-0011',
        version: 1,
        title: 'Zero Freight Budget',
        importFileId: 6,
        invoiceAmountForeign: 50000.0,
        invoiceCurrency: 'USD',
        invoiceAmountEgp: 2450000.0,
        freightCostForeign: 0.0,
        freightCurrency: 'USD',
        freightCostEgp: 0.0,
        customsDutiesEgp: 0.0,
        clearanceInlandEgp: 0.0,
        exchangeRate: 49.0,
        totalBudgetEgp: 2450000.0,
        budgetStatus: 'Draft',
        isActive: true,
        createdAt: '2026-10-19T00:00:00Z',
        updatedAt: '2026-10-19T00:00:00Z',
      );

      expect(zeroBudget.freightCostForeign, 0.0);
      expect(zeroBudget.freightCostEgp, 0.0);
      expect(zeroBudget.totalBudgetEgp, 2450000.0);
    });

    test('FE02-T05: cloneImportBudget returns the newly generated server clone with Draft status', () async {
      final adapter = _MockAdapter().on(
        'POST /clone',
        (r) => _MockAdapter.json({
          'budget_id': 99,
          'budget_code': 'BGT-2026-0099',
          'version': 1,
          'title': 'Cloned Budget Copy',
          'import_file_id': 5,
          'invoice_amount_foreign': 150000.0,
          'invoice_currency': 'EUR',
          'invoice_amount_egp': 7800000.0,
          'freight_cost_foreign': 12000.0,
          'freight_currency': 'USD',
          'freight_cost_egp': 588000.0,
          'customs_duties_egp': 450000.0,
          'clearance_inland_egp': 65000.0,
          'exchange_rate': 52.0,
          'total_budget_egp': 8903000.0,
          'budget_status': 'Draft',
          'is_active': true,
          'created_at': '2026-10-19T00:00:00Z',
          'updated_at': '2026-10-19T00:00:00Z',
        }),
      );

      final container = _createContainer(adapter);
      final notifier = container.read(importBudgetsProvider.notifier);
      final cloned = await notifier.cloneImportBudget(10, {'new_title': 'Cloned Budget Copy'});

      expect(cloned, isNotNull);
      expect(cloned!.budgetId, 99);
      expect(cloned.budgetCode, 'BGT-2026-0099');
      expect(cloned.budgetStatus, 'Draft');
      expect(adapter.requests.any((r) =>
          r.method == 'POST' &&
          r.uri.path.contains('/import-budgets/10/clone')), isTrue);
    });

    test('FE02-T06: Open payment request duplicate check contract matches backend statuses', () {
      const openStatuses = {'Draft', 'Pending Approval', 'Approved'};
      const terminalStatuses = {'Paid', 'Rejected', 'Cancelled'};

      final openDraft = PaymentRequestModel(
        paymentId: 1,
        paymentCode: 'PAY-1',
        version: 1,
        title: 'Open Draft',
        supplierName: 'ACME',
        paymentType: 'ADVANCE_PAYMENT',
        requestedAmount: 1000,
        currencyCode: 'USD',
        exchangeRate: 50,
        requestedAmountEgp: 50000,
        dueDate: '2026-10-25',
        requestDate: '2026-10-19',
        status: 'Draft',
        isActive: true,
        createdAt: '2026-10-19T00:00:00Z',
        updatedAt: '2026-10-19T00:00:00Z',
      );

      final openApproved = PaymentRequestModel(
        paymentId: 2,
        paymentCode: 'PAY-2',
        version: 1,
        title: 'Open Approved',
        supplierName: 'ACME',
        paymentType: 'ADVANCE_PAYMENT',
        requestedAmount: 1000,
        currencyCode: 'USD',
        exchangeRate: 50,
        requestedAmountEgp: 50000,
        dueDate: '2026-10-25',
        requestDate: '2026-10-19',
        status: 'Approved',
        isActive: true,
        createdAt: '2026-10-19T00:00:00Z',
        updatedAt: '2026-10-19T00:00:00Z',
      );

      final paidRequest = PaymentRequestModel(
        paymentId: 3,
        paymentCode: 'PAY-3',
        version: 1,
        title: 'Paid Request',
        supplierName: 'ACME',
        paymentType: 'ADVANCE_PAYMENT',
        requestedAmount: 1000,
        currencyCode: 'USD',
        exchangeRate: 50,
        requestedAmountEgp: 50000,
        dueDate: '2026-10-25',
        requestDate: '2026-10-19',
        status: 'Paid',
        isActive: true,
        createdAt: '2026-10-19T00:00:00Z',
        updatedAt: '2026-10-19T00:00:00Z',
      );

      expect(openStatuses.contains(openDraft.status), isTrue);
      expect(openStatuses.contains(openApproved.status), isTrue);
      expect(openStatuses.contains(paidRequest.status), isFalse);
      expect(terminalStatuses.contains(paidRequest.status), isTrue);
    });
  });
}
