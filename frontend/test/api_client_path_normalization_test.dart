import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';

void main() {
  group('ApiClient Path Doubling Guard', () {
    test('dioProvider strips leading /api/v1/ from relative path', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dio = container.read(dioProvider);
      String? actualResolvedPath;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            actualResolvedPath = options.path;
            // Reject so no network attempt is made
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'intercepted_for_test',
                type: DioExceptionType.unknown,
              ),
            );
          },
        ),
      );

      try {
        await dio.get('/api/v1/file-closure/audit-timeline/1');
      } catch (_) {}

      expect(actualResolvedPath, equals('/file-closure/audit-timeline/1'));
    });

    test('uploadDioProvider strips leading /api/v1/ from relative path', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dio = container.read(uploadDioProvider);
      String? actualResolvedPath;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            actualResolvedPath = options.path;
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'intercepted_for_test',
                type: DioExceptionType.unknown,
              ),
            );
          },
        ),
      );

      try {
        await dio.post('/api/v1/smart-document-upload/upload');
      } catch (_) {}

      expect(actualResolvedPath, equals('/smart-document-upload/upload'));
    });
  });
}
