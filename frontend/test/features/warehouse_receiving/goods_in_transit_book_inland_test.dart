import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/inland_transport/widgets/inland_transport_dialog.dart';
import 'package:frontend/features/warehouse_receiving/models/goods_in_transit_model.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/providers/goods_in_transit_provider.dart';
import 'package:frontend/features/warehouse_receiving/screens/goods_in_transit_screen.dart';

import '../../helpers/localized_app.dart';

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

class _MockGitNotifier extends GoodsInTransitNotifier {
  final List<GitLineItemModel> items;
  _MockGitNotifier(this.items) : super() {
    state = AsyncValue.data(items);
  }
}

void main() {
  group('FE08-T04: Mandatory file picker for Book Inland Transport in GIT', () {
    testWidgets('prompts user with file picker and only includes active, unarrived files', (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final files = [
        ImportFileModel(
          importFileId: 101,
          importFileCode: 'IMP-2026-0101',
          companyName: 'Company Alpha',
          supplierName: 'Supplier A',
          currentModule: 'Phase 8',
          currentStage: 'Stage',
          nextAction: 'Next',
          isActive: true,
          inlandTransportStatus: 'Arrived Warehouse', // Already arrived, should be filtered out
          createdAt: '',
          updatedAt: '',
        ),
        ImportFileModel(
          importFileId: 102,
          importFileCode: 'IMP-2026-0102',
          companyName: 'Company Beta',
          supplierName: 'Supplier B',
          currentModule: 'Phase 8',
          currentStage: 'Stage',
          nextAction: 'Next',
          isActive: true,
          inlandTransportStatus: 'Booking Confirmed', // Eligible
          createdAt: '',
          updatedAt: '',
        ),
      ];

      final dio = Dio()..httpClientAdapter = _FakeAdapter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            uploadDioProvider.overrideWithValue(dio),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(files)),
            goodsInTransitProvider.overrideWith((ref) => _MockGitNotifier([])),
          ],
          child: localizedApp(
            locale: AppLocales.english,
            home: const Scaffold(
              body: GoodsInTransitScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click "Book inland transport" button
      expect(find.byKey(const Key('inlandTransportScreenBtn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inlandTransportScreenBtn')));
      await tester.pumpAndSettle();

      // Verify that the file picker dialog popped up with the correct title
      const en = AppLocalizationsEn();
      expect(find.text(en.wrPickFileForBookingTitle), findsOneWidget);
      expect(find.byKey(const Key('gitPickFileForInlandField')), findsOneWidget);

      // Verify that the InlandTransportDialog is NOT shown yet
      expect(find.byType(InlandTransportDialog), findsNothing);

      // Open the dropdown and select file 102
      await tester.tap(find.byKey(const Key('gitPickFileForInlandField')));
      await tester.pumpAndSettle();

      // File 102 should be in the list, but file 101 should not be eligible
      expect(find.textContaining('IMP-2026-0102'), findsWidgets);
      expect(find.textContaining('IMP-2026-0101'), findsNothing);

      await tester.tap(find.textContaining('IMP-2026-0102').last);
      await tester.pumpAndSettle();

      // Click Continue
      expect(find.byKey(const Key('gitPickFileForInlandContinueBtn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('gitPickFileForInlandContinueBtn')));
      await tester.pumpAndSettle();

      // InlandTransportDialog should now be shown
      expect(find.byType(InlandTransportDialog), findsOneWidget);
    });

    testWidgets('shows warning snackbar when no files are eligible for inland booking', (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final files = [
        ImportFileModel(
          importFileId: 201,
          importFileCode: 'IMP-2026-0201',
          companyName: 'Company Gamma',
          supplierName: 'Supplier C',
          currentModule: 'Phase 8',
          currentStage: 'Stage',
          nextAction: 'Next',
          isActive: true,
          inlandTransportStatus: 'ARRIVED_AT_WAREHOUSE',
          createdAt: '',
          updatedAt: '',
        ),
      ];

      final dio = Dio()..httpClientAdapter = _FakeAdapter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            uploadDioProvider.overrideWithValue(dio),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(files)),
            goodsInTransitProvider.overrideWith((ref) => _MockGitNotifier([])),
          ],
          child: localizedApp(
            locale: AppLocales.english,
            home: const Scaffold(
              body: GoodsInTransitScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inlandTransportScreenBtn')));
      await tester.pumpAndSettle();

      // No dialog shown, warning snackbar shown
      expect(find.byType(InlandTransportDialog), findsNothing);
      const en = AppLocalizationsEn();
      expect(find.text(en.wrNoFilesForBooking), findsOneWidget);
    });
  });
}
