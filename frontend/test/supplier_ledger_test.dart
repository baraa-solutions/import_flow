// Vendor sub-ledger, aging and credit limit: models + providers (Trello GzFff0Pc).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/suppliers/models/supplier_ledger_model.dart';
import 'package:frontend/features/suppliers/providers/supplier_ledger_provider.dart';

class _MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;
  final List<RequestOptions> calls = [];

  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(options);
    final res = handler(options);
    return ResponseBody.fromString(jsonEncode(res['data']), res['status'] as int? ?? 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

const _statementJson = {
  'supplier_id': 7,
  'supplier_code': 'SUP-000007',
  'company_name': 'Milano Industrial SpA',
  'balances': [
    {
      'currency': 'USD', 'billed_fx': 10000.0, 'paid_fx': 6000.0, 'balance_fx': 4000.0, 'open_payable_fx': 4000.0,
      'unapplied_fx': 0.0, 'open_commitments_fx': 10000.0, 'book_balance_egp': 200000.0, 'current_rate': 52.0,
      'current_balance_egp': 208000.0,
    },
    {
      'currency': 'EUR', 'billed_fx': 0.0, 'paid_fx': 1000.0, 'balance_fx': -1000.0, 'open_payable_fx': 0.0,
      'unapplied_fx': 1000.0, 'open_commitments_fx': 0.0, 'book_balance_egp': -55000.0, 'current_rate': null,
      'current_balance_egp': null,
    },
  ],
  'statements': [
    {
      'currency': 'USD', 'opening_balance_fx': 0.0, 'opening_balance_egp': 0.0, 'closing_balance_fx': 4000.0,
      'closing_balance_egp': 200000.0,
      'lines': [
        {
          'entry_code': 'SLE-000001', 'source_key': 'INV:1:USD:CI-1', 'entry_type': 'INVOICE_BILLED',
          'direction': 'CREDIT', 'payment_pathway': 'ADVANCE_PAYMENT', 'reference': 'CI-1', 'import_file_id': 1,
          'entry_date': '2026-02-01', 'due_date': '2026-02-01', 'currency': 'USD', 'amount_fx': 10000.0,
          'exchange_rate': 50.6, 'amount_egp': 506000.0, 'open_amount_fx': 4000.0, 'status': 'PARTIAL',
          'balance_fx': 10000.0, 'balance_egp': 506000.0,
        },
        {
          'entry_code': 'SLE-000002', 'source_key': 'PAY:3', 'entry_type': 'ADVANCE_PAID', 'direction': 'DEBIT',
          'reference': 'SWIFT-1', 'entry_date': '2026-03-01', 'currency': 'USD', 'amount_fx': 6000.0,
          'amount_egp': 306000.0, 'open_amount_fx': 0.0, 'status': 'SETTLED', 'balance_fx': 4000.0,
          'balance_egp': 200000.0,
        },
        {
          'entry_code': 'SLE-000003', 'source_key': 'FIN:2:COMMIT', 'entry_type': 'LC_COMMITTED', 'direction': 'MEMO',
          'entry_date': '2026-03-02', 'currency': 'USD', 'amount_fx': 10000.0, 'amount_egp': 500000.0,
          'open_amount_fx': 10000.0, 'status': 'OPEN', 'balance_fx': 4000.0, 'balance_egp': 200000.0,
        },
      ],
    },
  ],
  'warnings': [
    {'code': 'SUPPLIER_LEDGER_FILE_NOT_VALUED', 'import_file_id': 9, 'import_file_code': 'IMP-9', 'reason': 'X'},
  ],
};

const _agingJson = {
  'supplier_id': 7,
  'supplier_code': 'SUP-000007',
  'company_name': 'Milano Industrial SpA',
  'as_of': '2026-10-31',
  'currencies': [
    {
      'currency': 'USD', 'current': 4000.0, 'days_1_30': 1000.0, 'days_31_60': 2000.0, 'days_61_90': 0.0,
      'over_90': 3000.0, 'total_open_fx': 10000.0, 'unapplied_fx': 0.0, 'current_rate': 52.0,
      'total_open_egp': 520000.0,
      'items': [
        {
          'entry_code': 'SLE-1', 'reference': 'CI-3', 'entry_date': '2026-07-01', 'due_date': '2026-08-01',
          'amount_fx': 3000.0, 'open_amount_fx': 3000.0, 'days_past_due': 91, 'bucket': 'OVER_90',
        },
      ],
    },
  ],
  'total_open_egp': 520000.0,
  'warnings': [],
};

const _creditJson = {
  'supplier_id': 7,
  'credit': {
    'has_limit': true, 'currency': 'USD', 'policy': 'BLOCK', 'limit_amount': 20000.0, 'utilization_amount': 15000.0,
    'requested_amount': 0.0, 'projected_amount': 15000.0, 'available_amount': 5000.0, 'utilization_pct': 75.0,
    'exceeded': false, 'allowed': true, 'decision': 'WITHIN_LIMIT',
  },
  'balances': [],
  'overrides': [
    {
      'override_id': 1, 'context': 'PURCHASE_ORDER', 'reference': 'PO-2026-003', 'currency': 'USD',
      'limit_amount': 20000.0, 'utilization_amount': 15000.0, 'requested_amount': 6346.15,
      'projected_amount': 21346.15, 'reason': 'Strategic order', 'created_at': '2026-11-12T10:00:00',
      'created_by': 'admin',
    },
  ],
};

void main() {
  group('Supplier ledger models', () {
    test('statement parses balances, running balance lines and memo commitments', () {
      final st = SupplierStatement.fromJson(Map<String, dynamic>.from(_statementJson));
      expect(st.currencies, ['USD', 'EUR']);
      final usd = st.balances.first;
      expect(usd.balanceFx, 4000.0);
      expect(usd.currentBalanceEgp, 208000.0);
      expect(usd.isAdvance, isFalse);
      final eur = st.balances.last;
      expect(eur.isAdvance, isTrue);
      expect(eur.currentBalanceEgp, isNull); // no rate: never guessed
      final lines = st.statements.single.lines;
      expect(lines.map((l) => l.balanceFx), [10000.0, 4000.0, 4000.0]);
      expect(lines[0].creditFx, 10000.0);
      expect(lines[1].debitFx, 6000.0);
      expect(lines[2].isMemo, isTrue);
      expect(lines[2].creditFx, 0.0); // memo never moves the balance
      expect(lines[0].dueDate, DateTime(2026, 2, 1));
      expect(st.warnings.single.importFileCode, 'IMP-9');
    });

    test('aging buckets and overdue total', () {
      final aging = SupplierAging.fromJson(Map<String, dynamic>.from(_agingJson));
      final usd = aging.currencies.single;
      expect(usd.buckets, {'CURRENT': 4000.0, '1_30': 1000.0, '31_60': 2000.0, '61_90': 0.0, 'OVER_90': 3000.0});
      expect(usd.overdueFx, 6000.0);
      expect(usd.items.single.bucket, 'OVER_90');
      expect(aging.asOf, DateTime(2026, 10, 31));
    });

    test('bucket boundaries match the backend (30/31/60/61/90/91)', () {
      expect(agingBucketForDays(0), 'CURRENT');
      expect(agingBucketForDays(30), '1_30');
      expect(agingBucketForDays(31), '31_60');
      expect(agingBucketForDays(60), '31_60');
      expect(agingBucketForDays(61), '61_90');
      expect(agingBucketForDays(90), '61_90');
      expect(agingBucketForDays(91), 'OVER_90');
    });

    test('credit status utilization ratio and overrides', () {
      final status = SupplierCreditStatus.fromJson(Map<String, dynamic>.from(_creditJson));
      expect(status.credit.utilizationRatio, 0.75);
      expect(status.credit.availableAmount, 5000.0);
      expect(status.overrides.single.reason, 'Strategic order');
      const noLimit = SupplierCreditCheck(hasLimit: false, currency: 'USD', policy: 'BLOCK');
      expect(noLimit.utilizationRatio, isNull);
      const over = SupplierCreditCheck(
          hasLimit: true, currency: 'USD', policy: 'WARN', limitAmount: 100, utilizationAmount: 150, exceeded: true);
      expect(over.utilizationRatio, 1.0);
    });
  });

  group('Supplier ledger providers', () {
    late _MockAdapter adapter;
    late ProviderContainer container;
    late int statementCalls;

    setUp(() {
      statementCalls = 0;
      adapter = _MockAdapter((o) {
        if (o.path.endsWith('/ledger/statement')) {
          statementCalls++;
          return {'data': _statementJson};
        }
        if (o.path.endsWith('/ledger/aging')) return {'data': _agingJson};
        if (o.path.endsWith('/credit-limit') && o.method == 'GET') return {'data': _creditJson};
        if (o.path.endsWith('/credit-limit') && o.method == 'PUT') return {'data': {'supplier_id': 7}};
        if (o.path.endsWith('/ledger/sync')) return {'data': _statementJson};
        if (o.path.endsWith('/credit-limit/check')) return {'data': _creditJson['credit']};
        return {'data': [], 'status': 200};
      });
      final dio = Dio()..httpClientAdapter = adapter;
      container = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    });

    tearDown(() => container.dispose());

    test('statement provider sends the currency filter and parses the response', () async {
      final sub = container.listen(supplierStatementProvider((supplierId: 7, currency: 'USD')), (_, __) {});
      final st = await container.read(supplierStatementProvider((supplierId: 7, currency: 'USD')).future);
      expect(st.companyName, 'Milano Industrial SpA');
      final call = adapter.calls.firstWhere((c) => c.path.endsWith('/ledger/statement'));
      expect(call.path, contains('/suppliers/7/ledger/statement'));
      expect(call.queryParameters['currency'], 'USD');
      sub.close();
    });

    test('aging and credit providers parse', () async {
      final aging = await container.read(supplierAgingProvider(7).future);
      expect(aging.currencies.single.totalOpenFx, 10000.0);
      final credit = await container.read(supplierCreditStatusProvider(7).future);
      expect(credit.credit.decision, 'WITHIN_LIMIT');
    });

    test('updating the credit limit sends the payload and invalidates the views (live reload)', () async {
      final sub = container.listen(supplierStatementProvider((supplierId: 7, currency: null)), (_, __) {});
      await container.read(supplierStatementProvider((supplierId: 7, currency: null)).future);
      expect(statementCalls, 1);

      await container.read(supplierLedgerActionsProvider).updateCreditLimit(7, creditLimit: 25000, currency: 'USD', policy: 'WARN');
      final put = adapter.calls.firstWhere((c) => c.method == 'PUT');
      expect(put.path, contains('/suppliers/7/credit-limit'));
      expect(put.data, {'credit_limit': 25000.0, 'credit_limit_currency': 'USD', 'credit_limit_policy': 'WARN'});

      await container.read(supplierStatementProvider((supplierId: 7, currency: null)).future);
      expect(statementCalls, 2); // invalidated -> fetched again from the server
      sub.close();
    });

    test('credit what-if check posts amount and currency', () async {
      final check = await container.read(supplierLedgerActionsProvider).checkCredit(7, amount: 6000, currency: 'EUR');
      expect(check.availableAmount, 5000.0);
      final post = adapter.calls.firstWhere((c) => c.path.endsWith('/credit-limit/check'));
      expect(post.data, {'amount': 6000.0, 'currency': 'EUR'});
    });
  });
}
