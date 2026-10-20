import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/financial_settlement/screens/financial_settlement_screen.dart';
import 'package:frontend/features/financial_settlement/widgets/final_settlement_invoices_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode([]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> files;
  _MockImportFilesNotifier(this.files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    state = AsyncValue.data(files);
  }
}

void main() {
  group('FE09-T01: Global CLO header buttons ask which file', () {
    testWidgets('clicking CLO-01 opens file picker and does not open invoices until file selected', (tester) async {
      final sampleFiles = [
        ImportFileModel(
          importFileId: 101,
          importFileCode: 'IMP-2026-0101',
          companyName: 'Company Alpha',
          supplierName: 'Supplier A',
          portOfDischarge: 'Alexandria',
          currentModule: 'Phase 9',
          currentStage: 'Financial Settlement',
          progressPercent: 95.0,
          nextAction: 'Invoices Aggregation',
          createdAt: '2026-09-01T10:00:00Z',
          updatedAt: '2026-09-01T12:00:00Z',
        ),
        ImportFileModel(
          importFileId: 102,
          importFileCode: 'IMP-2026-0102',
          companyName: 'Company Beta',
          supplierName: 'Supplier B',
          portOfDischarge: 'Port Said',
          currentModule: 'Phase 9',
          currentStage: 'Financial Settlement',
          progressPercent: 95.0,
          nextAction: 'Invoices Aggregation',
          createdAt: '2026-09-02T10:00:00Z',
          updatedAt: '2026-09-02T12:00:00Z',
        ),
      ];

      final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))
        ..httpClientAdapter = _FakeAdapter();

      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            uploadDioProvider.overrideWithValue(dio),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(sampleFiles)),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: FinancialSettlementScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap header CLO-01 button
      final clo01Btn = find.byKey(const Key('globalFinalSettlementInvoicesBtn'));
      expect(clo01Btn, findsOneWidget);
      await tester.tap(clo01Btn);
      await tester.pumpAndSettle();

      // Assert that picker field is shown and invoices dialog is NOT open yet
      expect(find.byKey(const Key('settlementPickFileField')), findsOneWidget);
      expect(find.byType(FinalSettlementInvoicesDialog), findsNothing);

      // Tap picker and select second file
      await tester.tap(find.byKey(const Key('settlementPickFileField')));
      await tester.pumpAndSettle();

      // Find item with 'IMP-2026-0102' or 'Company Beta'
      final optionFinder = find.textContaining('IMP-2026-0102');
      expect(optionFinder, findsWidgets);
      await tester.tap(optionFinder.last);
      await tester.pumpAndSettle();

      // Tap Continue
      final continueBtn = find.byKey(const Key('settlementPickFileContinueBtn'));
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Assert invoices dialog opened for IMP-2026-0102
      expect(find.byType(FinalSettlementInvoicesDialog), findsOneWidget);
      expect(find.textContaining('IMP-2026-0102'), findsWidgets);
    });
  });
}
