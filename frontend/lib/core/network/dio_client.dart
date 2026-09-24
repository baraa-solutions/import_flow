import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart' as central;

/// Single shared Dio HTTP client for Sorour Logistics ERP.
/// Delegated to central api_client.dart dioProvider.
final dioProvider = Provider<Dio>((ref) {
  return ref.watch(central.dioProvider);
});

/// Multipart/file upload Dio client.
/// Delegated to the authenticated central api_client.dart uploadDioProvider
/// (no JSON content-type, long timeouts, Bearer token injection).
final uploadDioProvider = Provider<Dio>((ref) {
  return ref.watch(central.uploadDioProvider);
});
