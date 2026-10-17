import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/projects/models/project_model.dart';

void main() {
  group('ProjectModel BEX-T10 Serialization Tests', () {
    test('fromJson correctly parses multi-currency commitments and aggregates', () {
      final json = {
        'project_id': 101,
        'project_code': 'PRJ-2026-001',
        'project_name': 'Expansion Factory A',
        'project_owner': 'Eng. Tarek',
        'company_id': 1,
        'company_ids': [1, 2],
        'supplier_id': 10,
        'incoterm_id': 2,
        'import_type': 'Direct Commercial',
        'priority': 'High',
        'shipment_category': 'FCL Container',
        'allow_multi_shipment': true,
        'allow_multi_company': true,
        'total_budget_usd': 100000.0,
        'target_end_date': '2026-12-31',
        'status': 'Open',
        'is_active': true,
        'company_name': 'Sorour Logistics, Alpha Imports',
        'supplier_name': 'Global Machinery GmbH',
        'incoterm_code': 'FOB',
        'total_committed_usd': 20886.60,
        'po_count': 2,
        'remaining_budget_usd': 79113.40,
        'budget_utilization_percent': 20.9,
        'missing_rate_currencies': <String>[],
        'committed_by_currency': {'USD': 10000.0, 'EUR': 10000.0},
      };

      final project = ProjectModel.fromJson(json);

      expect(project.projectId, equals(101));
      expect(project.projectCode, equals('PRJ-2026-001'));
      expect(project.projectName, equals('Expansion Factory A'));
      expect(project.totalBudgetUsd, equals(100000.0));
      expect(project.totalCommittedUsd, equals(20886.60));
      expect(project.poCount, equals(2));
      expect(project.remainingBudgetUsd, equals(79113.40));
      expect(project.budgetUtilizationPercent, equals(20.9));
      expect(project.missingRateCurrencies, isEmpty);
      expect(project.committedByCurrency, equals({'USD': 10000.0, 'EUR': 10000.0}));
    });

    test('fromJson correctly handles null total_committed_usd and missingRateCurrencies when rates are missing', () {
      final json = {
        'project_id': 102,
        'project_code': 'PRJ-2026-002',
        'project_name': 'Expansion Missing Rates',
        'project_owner': 'Eng. Tarek',
        'company_id': 1,
        'supplier_id': 10,
        'incoterm_id': 2,
        'total_budget_usd': 100000.0,
        'total_committed_usd': null,
        'po_count': 3,
        'remaining_budget_usd': null,
        'budget_utilization_percent': null,
        'missing_rate_currencies': ['EUR', 'GBP'],
        'committed_by_currency': {'USD': 5000.0, 'EUR': 12000.0, 'GBP': 3000.0},
      };

      final project = ProjectModel.fromJson(json);

      expect(project.totalCommittedUsd, isNull);
      expect(project.poCount, equals(3));
      expect(project.remainingBudgetUsd, isNull);
      expect(project.budgetUtilizationPercent, isNull);
      expect(project.missingRateCurrencies, equals(['EUR', 'GBP']));
      expect(project.committedByCurrency, equals({'USD': 5000.0, 'EUR': 12000.0, 'GBP': 3000.0}));
    });

    test('fromJson gracefully falls back when commitment fields are missing or unexpected types', () {
      final json = {
        'project_code': 'PRJ-MIN',
        'project_name': 'Minimal Project',
        'company_id': 1,
        'supplier_id': 1,
        'incoterm_id': 1,
      };

      final project = ProjectModel.fromJson(json);

      expect(project.totalCommittedUsd, isNull);
      expect(project.poCount, isNull);
      expect(project.remainingBudgetUsd, isNull);
      expect(project.budgetUtilizationPercent, isNull);
      expect(project.missingRateCurrencies, isEmpty);
      expect(project.committedByCurrency, isEmpty);
    });

    test('toJson serializes core fields properly', () {
      final project = ProjectModel(
        projectId: 50,
        projectCode: 'PRJ-50',
        projectName: 'Test Export',
        projectOwner: 'Tester',
        companyId: 1,
        companyIds: [1, 2],
        supplierId: 3,
        incotermId: 4,
        totalBudgetUsd: 50000.0,
        totalCommittedUsd: 15000.0,
        poCount: 1,
        remainingBudgetUsd: 35000.0,
        budgetUtilizationPercent: 30.0,
        missingRateCurrencies: ['JPY'],
        committedByCurrency: {'JPY': 2000000.0},
      );

      final map = project.toJson();
      expect(map['project_id'], equals(50));
      expect(map['project_code'], equals('PRJ-50'));
      expect(map['total_budget_usd'], equals(50000.0));
      expect(map['allow_multi_shipment'], isTrue);
    });
  });
}
