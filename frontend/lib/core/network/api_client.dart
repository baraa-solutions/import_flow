import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../constants/api_constants.dart';
import '../performance/client_diagnostics_service.dart';
import '../services/backend_launcher.dart';
import 'api_error.dart';
import 'network_security.dart';

/// Centralized Dio HTTP client provider for Sorour Logistics ERP.
/// All features must use this provider instead of creating their own Dio().
///
/// Features:
/// - Unified base URL from ApiConstants
/// - Consistent timeouts (connect: 30s, receive: 180s for large uploads)
/// - Centralized error interceptor
/// - Auth token and role headers injection
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 180),
      sendTimeout: const Duration(seconds: 180),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
      },
    ),
  );

  // Configure TLS certificate validation for LAN / local HTTPS
  configureDioTls(dio);

  // Self-heal the local backend on connection errors (see backend_launcher.dart).
  dio.interceptors.add(BackendRecoveryInterceptor(() => ref.read(backendLauncherProvider)));

  // ── Auth Token & Role Header & X-Request-ID Interceptor ───────
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        try {
          final authState = ref.read(authProvider);
          if (authState.token != null && authState.token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${authState.token}';
          }
          if (authState.user != null) {
            options.headers['x-user-role'] = authState.user!.role;
            options.headers['x-user-name'] = authState.user!.username;
          }
          // Inject Correlation ID & Client Version
          final reqId = 'req_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
          options.headers['X-Request-ID'] = reqId;
          options.headers['X-Client-Version'] = ApiConstants.clientVersion;
          options.extra['request_start_time'] = DateTime.now().millisecondsSinceEpoch;

          // Prevent /api/v1/api/v1/ path doubling trap
          if (options.path.startsWith('/api/v1/')) {
            options.path = options.path.substring(7);
          } else if (options.path.startsWith('api/v1/')) {
            options.path = options.path.substring(6);
          }
        } catch (_) {}
        handler.next(options);
      },
      onResponse: (response, handler) {
        try {
          final start = response.requestOptions.extra['request_start_time'] as int?;
          final durationMs = start != null ? DateTime.now().millisecondsSinceEpoch - start : 0;
          ClientDiagnosticsService.instance.recordNetworkEvent(
            method: response.requestOptions.method,
            path: response.requestOptions.path,
            statusCode: response.statusCode ?? 200,
            durationMs: durationMs,
            requestId: response.requestOptions.headers['X-Request-ID']?.toString(),
          );
        } catch (_) {}
        handler.next(response);
      },
    ),
  );

  // ── Logging Interceptor (debug only) ──────────────────────
  dio.interceptors.add(
    LogInterceptor(
      // Never log headers: they carry the Bearer token (CORE_RULES: no tokens in logs).
      requestHeader: false,
      requestBody: false,
      responseBody: false,
      logPrint: (obj) => debugPrintSynchronously('[DIO] $obj'),
    ),
  );

  // ── Error Response Interceptor ────────────────────────────
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        try {
          final start = error.requestOptions.extra['request_start_time'] as int?;
          final durationMs = start != null ? DateTime.now().millisecondsSinceEpoch - start : 0;
          ClientDiagnosticsService.instance.recordNetworkEvent(
            method: error.requestOptions.method,
            path: error.requestOptions.path,
            statusCode: error.response?.statusCode ?? 500,
            durationMs: durationMs,
            requestId: error.requestOptions.headers['X-Request-ID']?.toString(),
          );
          ClientDiagnosticsService.instance.recordError(
            '${error.requestOptions.method} ${error.requestOptions.path} error',
            requestId: error.requestOptions.headers['X-Request-ID']?.toString(),
            error: error.message,
          );
        } catch (_) {}

        // Automatically handle 401 Unauthorized (Expired or invalid token)
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;

        if (statusCode == 401 && !path.contains('/auth/login')) {
          final authNotifier = ref.read(authProvider.notifier);

          // If the failing request was not already a refresh attempt, try silent refresh
          if (!path.contains('/auth/refresh')) {
            final refreshed = await authNotifier.refreshToken();
            if (refreshed) {
              final newToken = ref.read(authProvider).token;
              if (newToken != null && newToken.isNotEmpty) {
                final retryOptions = Options(
                  method: error.requestOptions.method,
                  headers: Map<String, dynamic>.from(error.requestOptions.headers)
                    ..['Authorization'] = 'Bearer $newToken',
                  responseType: error.requestOptions.responseType,
                  contentType: error.requestOptions.contentType,
                  extra: error.requestOptions.extra,
                  sendTimeout: error.requestOptions.sendTimeout,
                  receiveTimeout: error.requestOptions.receiveTimeout,
                );
                try {
                  final retryResponse = await dio.request<dynamic>(
                    error.requestOptions.path,
                    data: error.requestOptions.data,
                    queryParameters: error.requestOptions.queryParameters,
                    options: retryOptions,
                  );
                  return handler.resolve(retryResponse);
                } catch (retryErr) {
                  if (retryErr is DioException) {
                    error = retryErr;
                  }
                }
              }
            }
          }

          // If refresh failed or was not possible, cleanly expire the session
          await authNotifier.handleSessionExpired();
        }

        // 403 PASSWORD_CHANGE_REQUIRED: flag the user so the password-change
        // gate replaces the app shell (the screens that fired the call unmount).
        if (ApiError.isPasswordChangeRequired(error)) {
          ref.read(authProvider.notifier).markPasswordChangeRequired();
        }

        // Normalize error messages for UI display
        if (error.response != null) {
          final data = error.response!.data;
          if (data is Map && data.containsKey('detail')) {
            error = error.copyWith(
              // Structured details ({code, message}) surface their message.
              message: ApiError.isPasswordChangeRequired(error)
                  ? ApiError.message(error)
                  : data['detail'].toString(),
            );
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

/// Upload-optimized Dio client (180s timeout, no JSON content-type).
/// Use for multipart file uploads to /smart-upload endpoints.
final uploadDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 180),
      sendTimeout: const Duration(seconds: 180),
    ),
  );

  // Configure TLS certificate validation for LAN / local HTTPS
  configureDioTls(dio);

  // Self-heal the local backend on connection errors (see backend_launcher.dart).
  dio.interceptors.add(BackendRecoveryInterceptor(() => ref.read(backendLauncherProvider)));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        try {
          final authState = ref.read(authProvider);
          if (authState.token != null && authState.token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${authState.token}';
          }
          if (authState.user != null) {
            options.headers['x-user-role'] = authState.user!.role;
            options.headers['x-user-name'] = authState.user!.username;
          }
          // Prevent /api/v1/api/v1/ path doubling trap
          if (options.path.startsWith('/api/v1/')) {
            options.path = options.path.substring(7);
          } else if (options.path.startsWith('api/v1/')) {
            options.path = options.path.substring(6);
          }
        } catch (_) {}
        handler.next(options);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        if (error.response?.statusCode == 401 && !error.requestOptions.path.contains('/auth/')) {
          await ref.read(authProvider.notifier).handleSessionExpired();
        }
        if (ApiError.isPasswordChangeRequired(error)) {
          ref.read(authProvider.notifier).markPasswordChangeRequired();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
