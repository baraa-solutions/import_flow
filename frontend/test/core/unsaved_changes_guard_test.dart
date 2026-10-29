import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/providers/workspace_tabs_provider.dart';
import 'package:frontend/core/services/form_draft_service.dart';
import 'package:frontend/core/widgets/unsaved_changes_dialog.dart';
import 'package:frontend/core/widgets/unsaved_changes_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppLocalizationsProvider(
        locale: const Locale('ar'),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FormDraftService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveDraft, loadDraft, hasDraft, and clearDraft lifecycle', () async {
      const scope = 'customs_46';
      const entityId = 'IMP-2026-999';
      final draftData = {
        'declaration_no': '46-ALX-999',
        'cif_egp': 50000.0,
        'has_exemption': true,
      };

      // 1. Initial state: no draft
      expect(await FormDraftService.hasDraft(scope: scope, entityId: entityId), isFalse);
      expect(await FormDraftService.loadDraft(scope: scope, entityId: entityId), isNull);

      // 2. Save draft
      await FormDraftService.saveDraft(scope: scope, entityId: entityId, data: draftData);

      // 3. Verify existence and contents
      expect(await FormDraftService.hasDraft(scope: scope, entityId: entityId), isTrue);
      final loaded = await FormDraftService.loadDraft(scope: scope, entityId: entityId);
      expect(loaded, isNotNull);
      expect(loaded!['declaration_no'], '46-ALX-999');
      expect(loaded['cif_egp'], 50000.0);
      expect(loaded['has_exemption'], isTrue);
      expect(loaded['saved_at'], isNotNull);
      expect(loaded['form_scope'], scope);

      // 4. Clear draft
      await FormDraftService.clearDraft(scope: scope, entityId: entityId);
      expect(await FormDraftService.hasDraft(scope: scope, entityId: entityId), isFalse);
      expect(await FormDraftService.loadDraft(scope: scope, entityId: entityId), isNull);
    });
  });

  group('UnsavedChangesGuard Widget Tests', () {
    testWidgets('Test 1: When isDirty is false, popping route succeeds immediately without dialog', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                key: const Key('openPageBtn'),
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (childCtx) => const UnsavedChangesGuard(
                        isDirty: false,
                        child: Scaffold(
                          body: Center(child: Text('Protected Sub Page')),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open sub page
      await tester.tap(find.byKey(const Key('openPageBtn')));
      await tester.pumpAndSettle();
      expect(find.text('Protected Sub Page'), findsOneWidget);

      // Trigger pop
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pop();
      await tester.pumpAndSettle();

      // Verified sub page popped without showing UnsavedChangesDialog
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.text('Protected Sub Page'), findsNothing);
    });

    testWidgets('Test 2: When isDirty is true, attempting to pop triggers UnsavedChangesDialog', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                key: const Key('openPageBtn'),
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (childCtx) => const UnsavedChangesGuard(
                        isDirty: true,
                        child: Scaffold(
                          body: Center(child: Text('Protected Dirty Page')),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open sub page
      await tester.tap(find.byKey(const Key('openPageBtn')));
      await tester.pumpAndSettle();
      expect(find.text('Protected Dirty Page'), findsOneWidget);

      // Trigger pop
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.maybePop();
      await tester.pumpAndSettle();

      // Verify UnsavedChangesDialog appeared
      expect(find.byType(UnsavedChangesDialog), findsOneWidget);
      expect(find.textContaining('تنبيه تعديلات غير محفوظة'), findsOneWidget);
      expect(find.text('Protected Dirty Page'), findsOneWidget);
    });

    testWidgets('Test 3: Tapping Cancel/Stay keeps the user on the screen', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                key: const Key('openPageBtn'),
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (childCtx) => const UnsavedChangesGuard(
                        isDirty: true,
                        child: Scaffold(
                          body: Center(child: Text('Protected Dirty Page')),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('openPageBtn')));
      await tester.pumpAndSettle();

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(UnsavedChangesDialog), findsOneWidget);

      // Tap 'البقاء في الشاشة'
      await tester.tap(find.text('البقاء في الشاشة'));
      await tester.pumpAndSettle();

      // Dialog dismissed, page still open
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.text('Protected Dirty Page'), findsOneWidget);
    });

    testWidgets('Test 4: Tapping Discard dismisses dialog, triggers onDiscard, and pops page', (tester) async {
      bool discardFired = false;

      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                key: const Key('openPageBtn'),
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (childCtx) => UnsavedChangesGuard(
                        isDirty: true,
                        onDiscard: () => discardFired = true,
                        child: const Scaffold(
                          body: Center(child: Text('Protected Dirty Page')),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('openPageBtn')));
      await tester.pumpAndSettle();

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(UnsavedChangesDialog), findsOneWidget);

      // Tap 'تجاهل التعديلات والمتابعة'
      await tester.tap(find.text('تجاهل التعديلات والمتابعة'));
      await tester.pumpAndSettle();

      expect(discardFired, isTrue);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.text('Protected Dirty Page'), findsNothing);
    });

    testWidgets('Test 5: Tapping Save triggers onSave and pops page', (tester) async {
      bool saveFired = false;

      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                key: const Key('openPageBtn'),
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (childCtx) => UnsavedChangesGuard(
                        isDirty: true,
                        onSave: () => saveFired = true,
                        child: const Scaffold(
                          body: Center(child: Text('Protected Dirty Page')),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('openPageBtn')));
      await tester.pumpAndSettle();

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(UnsavedChangesDialog), findsOneWidget);

      // Tap 'حفظ التعديلات أولاً'
      await tester.tap(find.text('حفظ التعديلات أولاً'));
      await tester.pumpAndSettle();

      expect(saveFired, isTrue);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.text('Protected Dirty Page'), findsNothing);
    });

    testWidgets('Test 6: UnsavedChangesGuard syncs dirty state to workspaceTabsProvider', (tester) async {
      late final WidgetRef capturedRef;

      await tester.pumpWidget(
        _buildTestApp(
          child: Consumer(
            builder: (ctx, ref, _) {
              capturedRef = ref;
              return const UnsavedChangesGuard(
                isDirty: true,
                child: Scaffold(
                  body: Center(child: Text('Dirty Tab Page')),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check active tab is marked dirty in workspaceTabsProvider
      final activeTab = capturedRef.read(workspaceTabsProvider).activeTab;
      expect(activeTab, isNotNull);
      expect(activeTab!.isDirty, isTrue);
    });
  });
}
