import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/comprehensive_report/widgets/shipment_audit_timeline_dialog.dart';

Dio _mockDioWithHandler(Future<Response> Function(RequestOptions options) handler) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, reqHandler) async {
        try {
          final resp = await handler(options);
          reqHandler.resolve(resp);
        } on DioException catch (e) {
          reqHandler.reject(e);
        } catch (e) {
          reqHandler.reject(
            DioException(
              requestOptions: options,
              error: e,
              type: DioExceptionType.unknown,
            ),
          );
        }
      },
    ),
  );
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({required Dio dio, required int importFileId}) {
    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ShipmentAuditTimelineDialog(importFileId: importFileId),
        ),
      ),
    );
  }

  group('ShipmentAuditTimelineDialog Tests', () {
    testWidgets('shows validation message immediately when importFileId is 0 or negative', (tester) async {
      final dio = Dio();
      await tester.pumpWidget(buildTestWidget(dio: dio, importFileId: 0));
      await tester.pump();

      expect(find.textContaining('رقم ملف الشحنة غير صالح (0)'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows clean backend error message on 404 Not Found', (tester) async {
      final dio = _mockDioWithHandler((options) async {
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 404,
            data: {'detail': 'ملف الشحنة الاستيرادية رقم 999 غير موجود أو محذوف.'},
          ),
          type: DioExceptionType.badResponse,
        );
      });

      await tester.pumpWidget(buildTestWidget(dio: dio, importFileId: 999));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('ملف الشحنة الاستيرادية رقم 999 غير موجود أو محذوف.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('renders audit timeline successfully on 200 OK', (tester) async {
      final mockData = {
        'import_file_id': 1,
        'import_file_code': 'IMP-2026-0001',
        'custom_file_number': 'HSR Project Alpha',
        'company_name': 'Test Company LLC',
        'supplier_name': 'Global Trading Co',
        'shipping_line_name': 'Maersk Line',
        'bill_of_lading_no': 'BL-987654321',
        'port_of_loading': 'Shanghai',
        'port_of_discharge': 'Alexandria',
        'containers_summary': '2x40HQ',
        'status': 'In Progress',
        'financial_radar': {
          'free_days_storage': 14,
          'port_storage_start_date': '2026-10-25',
          'free_days_demurrage': 21,
          'demurrage_start_date': '2026-11-01',
          'expected_clearance_date': '2026-10-23',
          'expected_warehouse_delivery_date': '2026-10-26',
          'actual_warehouse_delivery_date': null,
          'risk_level': 'SAFE',
        },
        'milestones': [
          {
            'seq': 1,
            'phase_code': 'PHASE_01',
            'phase_name_ar': 'المرحلة 1: إنشاء ملف الشحنة وتثبيت أمر الشراء',
            'stage_code': 'STG_01',
            'name_ar': 'تاريخ إنشاء ملف الشحنة',
            'planned_date': '2026-10-01',
            'actual_date': '2026-10-01',
            'variance_days': 0,
            'status': 'COMPLETED',
            'sla_days': 1,
            'tat_display': '1 يوم',
            'source_field': 'created_at',
            'notes': 'تم الإنشاء بنجاح',
            'is_financial_watchpoint': false,
          }
        ],
        'vessel_tracking_pulse': [],
        'meeting_directives': 'قرارات الاجتماع التشغيلي للتجربة',
      };

      final dio = _mockDioWithHandler((options) async {
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: mockData,
        );
      });

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(dio: dio, importFileId: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('IMP-2026-0001'), findsOneWidget);
      expect(find.textContaining('HSR Project Alpha'), findsOneWidget);
      expect(find.text('قرارات الاجتماع التشغيلي للتجربة'), findsOneWidget);
    });
  });
}
