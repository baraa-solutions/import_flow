import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/features/production_sync/services/auto_updater_service.dart';

Dio _stubDio(List<RequestOptions> sink, Map<String, dynamic> body) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    sink.add(options);
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: body));
  }));
  return dio;
}

void main() {
  group('AutoUpdaterService', () {
    test('getInstallerInfo uses the injected (authenticated) apiDio', () async {
      final apiCalls = <RequestOptions>[];
      final downloadCalls = <RequestOptions>[];
      final service = AutoUpdaterService(
        apiDio: _stubDio(apiCalls, {
          'version': '2.1.0',
          'installer_url': 'https://github.com/org/repo/releases/download/v2.1.0/setup.exe',
          'installer_filename': 'setup.exe',
          'installer_size_mb': 120.5,
          'is_available': true,
        }),
        downloadDio: _stubDio(downloadCalls, const {}),
      );

      final info = await service.getInstallerInfo();

      expect(apiCalls, hasLength(1));
      expect(downloadCalls, isEmpty);
      expect(apiCalls.single.uri.toString(),
          '${ApiConstants.serverUrl}/api/v1/production-sync/installer-info');
      expect(info.version, '2.1.0');
      expect(info.isAvailable, isTrue);
    });

    test('an apiDio with baseUrl .../api/v1 does not double the prefix', () async {
      final apiCalls = <RequestOptions>[];
      final apiDio = _stubDio(apiCalls, const {'version': 'x'})
        ..options.baseUrl = ApiConstants.baseUrl;
      await AutoUpdaterService(apiDio: apiDio).getInstallerInfo();

      expect(apiCalls.single.uri.path, '/api/v1/production-sync/installer-info');
    });
  });
}
