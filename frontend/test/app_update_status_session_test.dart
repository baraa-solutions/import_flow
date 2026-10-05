import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/app_update/models/update_models.dart';
import 'package:frontend/features/app_update/providers/app_update_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_app_update_service.dart';

final _userId = StateProvider<int?>((ref) => 1);

ProviderContainer _container(FakeAppUpdateService fake) {
  final c = ProviderContainer(overrides: [
    appUpdateServiceProvider.overrideWithValue(fake),
    updatePollIntervalProvider.overrideWithValue(const Duration(milliseconds: 5)),
    canInstallUpdatesProvider.overrideWithValue(true),
    updateUserIdProvider.overrideWith((ref) => ref.watch(_userId)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _waitFor(bool Function() cond) async {
  for (var i = 0; i < 200 && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

DioException _dio(int? code) {
  final req = RequestOptions(path: '/api/v1/app-update/status');
  return DioException(
    requestOptions: req,
    type: code == null ? DioExceptionType.connectionError : DioExceptionType.badResponse,
    response: code == null ? null : Response(requestOptions: req, statusCode: code),
  );
}

const _downloading = UpdateStatus(state: UpdateState.downloading, downloadedBytes: 10, totalBytes: 100);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('logout mid-download stops polling and sends no further /status requests', () async {
    final fake = FakeAppUpdateService(statuses: const [_downloading]);
    final c = _container(fake);
    final sub = c.listen(updateStatusProvider, (_, __) {});
    addTearDown(sub.close);
    final notifier = c.read(updateStatusProvider.notifier);
    await _waitFor(() => fake.statusCalls >= 3);
    expect(notifier.isPolling, isTrue);

    c.read(_userId.notifier).state = null;
    await Future<void>.delayed(Duration.zero);
    expect(c.read(updateStatusProvider).valueOrNull?.state, UpdateState.idle);
    expect(notifier.isPolling, isFalse, reason: 'old notifier disposed with its timer');
    expect(c.read(updateStatusProvider.notifier).isPolling, isFalse);

    final calls = fake.statusCalls;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(fake.statusCalls, calls);

    // refresh() while signed out is a no-op (e.g. the host's 24 h timer).
    await c.read(updateStatusProvider.notifier).refresh();
    expect(fake.statusCalls, calls);
  });

  test('signed out from the start: no /status request at all', () async {
    final fake = FakeAppUpdateService();
    final c = _container(fake);
    c.read(_userId.notifier).state = null;
    expect(c.read(updateStatusProvider).valueOrNull, UpdateStatus.idle);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(fake.statusCalls, 0);
  });

  test('sign-in fetches a fresh status', () async {
    final fake = FakeAppUpdateService();
    final c = _container(fake);
    c.read(_userId.notifier).state = null;
    c.read(updateStatusProvider);
    expect(fake.statusCalls, 0);
    c.read(_userId.notifier).state = 2;
    c.read(updateStatusProvider);
    await _waitFor(() => fake.statusCalls == 1);
    expect(fake.statusCalls, 1);
  });

  for (final code in [401, 403, 404]) {
    test('$code mid-download is not retried', () async {
      final fake = FakeAppUpdateService(statuses: const [_downloading]);
      final c = _container(fake);
      final notifier = c.read(updateStatusProvider.notifier);
      await _waitFor(() => fake.statusCalls >= 2);
      fake.statusError = _dio(code);
      await _waitFor(() => c.read(updateStatusProvider).hasError);
      expect(c.read(updateStatusProvider).hasError, isTrue);
      expect(notifier.isPolling, isFalse);
      final calls = fake.statusCalls;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fake.statusCalls, calls);
    });
  }

  for (final code in [null, 502]) {
    test('${code ?? 'network error'} mid-download keeps progress and retries', () async {
      final fake = FakeAppUpdateService(statuses: const [_downloading]);
      final c = _container(fake);
      final notifier = c.read(updateStatusProvider.notifier);
      await _waitFor(() => fake.statusCalls >= 2);
      fake.statusError = _dio(code);
      final calls = fake.statusCalls;
      await _waitFor(() => fake.statusCalls >= calls + 3);
      expect(c.read(updateStatusProvider).valueOrNull?.state, UpdateState.downloading);
      expect(notifier.isPolling, isTrue);
    });
  }

  test('isTransientUpdateError', () {
    expect(isTransientUpdateError(_dio(null)), isTrue);
    expect(isTransientUpdateError(_dio(500)), isTrue);
    expect(isTransientUpdateError(_dio(401)), isFalse);
    expect(isTransientUpdateError(_dio(403)), isFalse);
    expect(isTransientUpdateError(Exception('x')), isFalse);
  });
}
