@Tags(['perf'])
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/shipment_inquiry/screens/shipment_inquiry_screen.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier()
      : super(AuthState(
          isAuthenticated: true,
          user: UserModel(
            userId: 1,
            username: 'admin',
            email: 'admin@sorour.com',
            fullName: 'Performance Tester',
            role: 'ADMIN',
            isActive: true,
          ),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> mockFiles;
  _MockImportFilesNotifier(this.mockFiles) : super(Dio()) {
    state = AsyncValue.data(mockFiles);
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
    state = AsyncValue.data(mockFiles);
  }
}

class _MockSuppliersNotifier extends SuppliersNotifier {
  _MockSuppliersNotifier() : super(showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchSuppliers({
    bool includeInactive = false,
    String? search,
    String? country,
    String? currency,
    String? productCategory,
  }) async {
    state = const AsyncValue.data([]);
  }
}

class _MockImportCompaniesNotifier extends ImportCompaniesNotifier {
  _MockImportCompaniesNotifier() : super(showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchCompanies({
    bool includeInactive = false,
    String? search,
    String? country,
    String? city,
  }) async {
    state = const AsyncValue.data([]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen 68: ShipmentInquiryScreen Performance Diagnostics', () {
    testWidgets('Measure Nav-IN and Nav-OUT latency across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<ImportFileModel> dummyShipments = List.generate(
        15,
        (i) => ImportFileModel(
          importFileId: i + 1,
          importFileCode: 'IMP-2026-${(i + 1).toString().padLeft(4, "0")}',
          supplierId: (i % 5) + 1,
          supplierName: 'Global Supplier ${(i % 5) + 1}',
          companyId: (i % 3) + 1,
          companyName: 'Import Company ${(i % 3) + 1}',
          shipmentMode: i % 2 == 0 ? 'FCL' : 'LCL',
          incotermCode: i % 3 == 0 ? 'CIF' : (i % 3 == 1 ? 'FOB' : 'EXW'),
          status: 'Shipment',
          estimatedCost: 2500.0 * ((i % 10) + 1),
          estimatedCostCurrency: 'USD',
          fileOpeningDate: '2026-03-${(i % 28) + 1}',
          portOfLoading: 'Port A',
          portOfDischarge: 'Port B',
          hsCode: '8471.30.00',
          productCategory: 'Electronics',
          customFileNumber: 'CFN-${1000 + i}',
          notes: 'Shipment Note $i',
          currentModule: 'Phase 1',
          currentStage: 'Phase 1',
          nextAction: 'None',
          createdAt: '2026-03-01',
          updatedAt: '2026-03-01',
        ),
      );

      Widget buildTarget() {
        return ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier()),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(dummyShipments)),
            suppliersProvider.overrideWith((ref) => _MockSuppliersNotifier()),
            importCompaniesProvider.overrideWith((ref) => _MockImportCompaniesNotifier()),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ShipmentInquiryScreen(),
              ),
            ),
          ),
        );
      }

      // Warm-up run to eliminate JIT compilation overhead
      await tester.pumpWidget(buildTarget());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Empty Destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navInFirstFrameTimes = <int>[];
      final navInSettledTimes = <int>[];
      final navOutTimes = <int>[];

      for (int run = 1; run <= 3; run++) {
        final navInWatch = Stopwatch()..start();

        await tester.pumpWidget(buildTarget());
        final firstFrameMs = navInWatch.elapsedMilliseconds;
        navInFirstFrameTimes.add(firstFrameMs);

        await tester.pumpAndSettle();
        final settledMs = navInWatch.elapsedMilliseconds;
        navInSettledTimes.add(settledMs);
        navInWatch.stop();

        // Verify loaded content
        expect(find.byType(ShipmentInquiryScreen), findsOneWidget);
        expect(find.text('IMP-2026-0001'), findsOneWidget);

        // Measure Nav-OUT
        final navOutWatch = Stopwatch()..start();
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Empty Destination')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final navOutMs = navOutWatch.elapsedMilliseconds;
        navOutTimes.add(navOutMs);
        navOutWatch.stop();
      }

      final avgFirstFrame = navInFirstFrameTimes.reduce((a, b) => a + b) ~/ 3;
      final avgSettled = navInSettledTimes.reduce((a, b) => a + b) ~/ 3;
      final avgNavOut = navOutTimes.reduce((a, b) => a + b) ~/ 3;

      debugPrint('=== Screen 68 Performance Benchmark Summary ===');
      debugPrint('Nav-IN First Frame Average: ${avgFirstFrame}ms');
      debugPrint('Nav-IN Settled Frame Average: ${avgSettled}ms');
      debugPrint('Nav-OUT Average: ${avgNavOut}ms');

      expect(avgFirstFrame, lessThanOrEqualTo(1000));
      expect(avgSettled, lessThanOrEqualTo(1200));
      expect(avgNavOut, lessThanOrEqualTo(300));
    });
  });
}
