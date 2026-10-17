import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/permission_gate.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/providers/current_permissions_provider.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('PermissionSet unit tests', () {
    test('wildcard * grants any code', () {
      const set = PermissionSet({'*'});
      expect(set.can('purchase_orders.manage'), isTrue);
      expect(set.can('customs_tariff.view'), isTrue);
      expect(set.can('users.delete'), isTrue);
      expect(set.canAny(['foo', 'bar']), isTrue);
      expect(set.canAll(['foo', 'bar']), isTrue);
    });

    test('exact code match grants only assigned permissions', () {
      const set = PermissionSet({'purchase_orders.view', 'import_files.view'});
      expect(set.can('purchase_orders.view'), isTrue);
      expect(set.can('import_files.view'), isTrue);
      expect(set.can('purchase_orders.manage'), isFalse);
      expect(set.can('users.manage'), isFalse);

      expect(set.canAny(['purchase_orders.manage', 'purchase_orders.view']), isTrue);
      expect(set.canAll(['purchase_orders.view', 'import_files.view']), isTrue);
      expect(set.canAll(['purchase_orders.view', 'purchase_orders.manage']), isFalse);
    });

    test('empty set denies all permissions', () {
      const set = PermissionSet();
      expect(set.can('anything'), isFalse);
      expect(set.isEmpty, isTrue);
    });
  });

  group('currentPermissionsProvider tests', () {
    test('returns empty PermissionSet when unauthenticated', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(
                const AuthState(isAuthenticated: false, token: null),
              )),
        ],
      );
      addTearDown(container.dispose);

      final permissions = await container.read(currentPermissionsProvider.future);
      expect(permissions.isEmpty, isTrue);
      expect(permissions.can('purchase_orders.view'), isFalse);
    });

    test('fetches and parses effective_permissions from backend JSON', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.path, contains('/auth/me/permissions'));
        expect(options.headers['Authorization'], 'Bearer fake_jwt_token');

        return ResponseBody.fromString(
          '{"role_code":"OPERATOR","effective_permissions":["purchase_orders.view","customs.view"]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(
                AuthState(
                  isAuthenticated: true,
                  token: 'fake_jwt_token',
                  user: UserModel(
                    userId: 1,
                    username: 'op1',
                    email: 'op@example.com',
                    fullName: 'Operator',
                    role: 'OPERATOR',
                    isActive: true,
                  ),
                ),
              )),
          dioProvider.overrideWithValue(dio),
        ],
      );
      addTearDown(container.dispose);

      final permissions = await container.read(currentPermissionsProvider.future);
      expect(permissions.can('purchase_orders.view'), isTrue);
      expect(permissions.can('customs.view'), isTrue);
      expect(permissions.can('purchase_orders.manage'), isFalse);
    });

    test('ADMIN role automatically receives wildcard *', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        return ResponseBody.fromString(
          '{"role_code":"ADMIN","effective_permissions":["system.admin"]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(
                AuthState(
                  isAuthenticated: true,
                  token: 'admin_token',
                  user: UserModel(
                    userId: 99,
                    username: 'admin',
                    email: 'admin@example.com',
                    fullName: 'Admin',
                    role: 'ADMIN',
                    isActive: true,
                  ),
                ),
              )),
          dioProvider.overrideWithValue(dio),
        ],
      );
      addTearDown(container.dispose);

      final permissions = await container.read(currentPermissionsProvider.future);
      expect(permissions.can('purchase_orders.manage'), isTrue);
      expect(permissions.can('arbitrary.permission.code'), isTrue);
    });

    test('network error propagates exception so Riverpod produces AsyncError', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        return ResponseBody.fromString('Internal Server Error', 500);
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(
                const AuthState(isAuthenticated: true, token: 'failing_token'),
              )),
          dioProvider.overrideWithValue(dio),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(currentPermissionsProvider.future),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('PermissionGate widget tests', () {
    testWidgets('renders child when user has permission', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentPermissionsProvider.overrideWith((ref) async =>
              const PermissionSet({'purchase_orders.manage'})),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: PermissionGate(
              code: 'purchase_orders.manage',
              child: Text('Edit PO Button'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit PO Button'), findsOneWidget);
    });

    testWidgets('hides child and renders fallback when user lacks permission', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentPermissionsProvider.overrideWith((ref) async =>
              const PermissionSet({'purchase_orders.view'})),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: PermissionGate(
              code: 'purchase_orders.manage',
              fallback: Text('Locked'),
              child: Text('Edit PO Button'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit PO Button'), findsNothing);
      expect(find.text('Locked'), findsOneWidget);
    });

    testWidgets('view actions stay visible during loading state', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentPermissionsProvider.overrideWith((ref) {
            // Never completing future simulates in-flight loading
            return Future<PermissionSet>.delayed(const Duration(seconds: 10));
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                PermissionGate(
                  code: 'purchase_orders.view',
                  child: Text('View Action Visible'),
                ),
                PermissionGate(
                  code: 'purchase_orders.manage',
                  child: Text('Manage Action Hidden'),
                ),
              ],
            ),
          ),
        ),
      );
      // Pump initial frame while provider is still in loading state
      await tester.pump();

      expect(find.text('View Action Visible'), findsOneWidget);
      expect(find.text('Manage Action Hidden'), findsNothing);
    });

    testWidgets('provider throws -> .view gate shows child and .manage gate hides child', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentPermissionsProvider.overrideWith((ref) {
            return Future<PermissionSet>.error(
              DioException(
                requestOptions: RequestOptions(path: '/auth/me/permissions'),
                response: Response(
                  requestOptions: RequestOptions(path: '/auth/me/permissions'),
                  statusCode: 500,
                ),
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                PermissionGate(
                  code: 'purchase_orders.view',
                  child: Text('View Action Visible on Error'),
                ),
                PermissionGate(
                  code: 'purchase_orders.manage',
                  child: Text('Manage Action Hidden on Error'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View Action Visible on Error'), findsOneWidget);
      expect(find.text('Manage Action Hidden on Error'), findsNothing);
    });
  });
}

class _FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
