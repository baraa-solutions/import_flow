import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/experience_guide/providers/experience_guide_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

/// Captures POST /match payloads and answers every request with a canned body.
class _CapturingInterceptor extends Interceptor {
  final List<Map<String, dynamic>> matchPayloads = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' && options.path.endsWith('/match')) {
      matchPayloads.add(Map<String, dynamic>.from(options.data as Map));
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{'has_critical_alert': true, 'mandatory_ports': ['SOKHNA']},
      ));
      return;
    }
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: <dynamic>[]));
  }
}

ImportFileModel _file(Map<String, dynamic> extra) => ImportFileModel.fromJson({
      'import_file_id': 42,
      'import_file_code': 'IMP-000042',
      'company_name': 'ARCHI Brands',
      'supplier_name': 'Shaw Europe',
      ...extra,
    });

void main() {
  late _CapturingInterceptor interceptor;
  late ExperienceGuideNotifier notifier;

  setUp(() {
    interceptor = _CapturingInterceptor();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))..interceptors.add(interceptor);
    notifier = ExperienceGuideNotifier(dio);
  });

  tearDown(() => notifier.dispose());

  group('ExperienceGuideNotifier.matchImportFile', () {
    test('maps the 7 import-file fields exactly like the explicit matchShipment call', () async {
      final file = _file({
        'hs_code': '5703299100',
        'product_category': 'Carpet tiles',
        'port_of_loading': 'FELIXSTOWE',
        'port_of_discharge': 'SOKHNA',
        'incoterm_code': 'CIF',
      });

      final viaHelper = await notifier.matchImportFile(file);
      await notifier.matchShipment(
        supplier: file.supplierName,
        hsCode: file.hsCode,
        productCategory: file.productCategory,
        portOfLoading: file.portOfLoading,
        portOfDischarge: file.portOfDischarge,
        incoterm: file.incotermCode,
        importFileReference: file.importFileCode,
      );

      expect(interceptor.matchPayloads, hasLength(2));
      expect(interceptor.matchPayloads[0], interceptor.matchPayloads[1]);
      expect(interceptor.matchPayloads[0], {
        'hs_code': '5703299100',
        'product_category': 'Carpet tiles',
        'port_of_discharge': 'SOKHNA',
        'port_of_loading': 'FELIXSTOWE',
        'supplier': 'Shaw Europe',
        'incoterm': 'CIF',
        'import_file_reference': 'IMP-000042',
      });
      expect(viaHelper.hasCriticalAlert, isTrue);
      expect(viaHelper.mandatoryPorts, ['SOKHNA']);
    });

    test('omits null / empty optional fields (same filtering as matchShipment)', () async {
      final file = _file({'hs_code': '', 'port_of_discharge': 'X'});
      await notifier.matchImportFile(file);
      final payload = interceptor.matchPayloads.single;
      expect(payload.containsKey('hs_code'), isFalse);
      expect(payload.containsKey('product_category'), isFalse);
      expect(payload.containsKey('port_of_loading'), isFalse);
      expect(payload['port_of_discharge'], 'X');
      expect(payload['incoterm'], 'FOB'); // model default
      expect(payload['supplier'], 'Shaw Europe');
      expect(payload['import_file_reference'], 'IMP-000042');
    });
  });
}
