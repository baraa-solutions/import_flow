import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/buttons/icon_action_button.dart';
import 'package:frontend/core/widgets/copyable_data_helper.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/providers/rbac_provider.dart';
import 'package:frontend/features/auth/models/rbac_models.dart';
import 'package:frontend/features/lifecycle_board/models/step_config_model.dart';
import 'package:frontend/features/lifecycle_board/providers/step_config_provider.dart';
import 'package:frontend/features/lifecycle_board/screens/step_config_management_screen.dart';

final mockOperator = UserModel(
  userId: 10,
  username: 'operator_samir',
  email: 'samir@importflow.com',
  fullName: 'Samir Logistics Operator',
  role: 'LOGISTICS_OPERATOR',
  isActive: true,
);

final mockGeneralManager = UserModel(
  userId: 2,
  username: 'gm_ahmed',
  email: 'gm@importflow.com',
  fullName: 'Ahmed General Manager',
  role: 'GENERAL_MANAGER',
  isActive: true,
);

final mockAdmin = UserModel(
  userId: 1,
  username: 'admin_sys',
  email: 'admin@importflow.com',
  fullName: 'System Administrator',
  role: 'ADMIN',
  isActive: true,
);

final mockConfigs = [
  const StepConfigModel(
    id: 1,
    stepCode: 'STEP_01',
    stepNameAr: 'تسجيل الفاتورة المبدئية',
    stepNameEn: 'Proforma Invoice Registration',
    phaseId: 1,
    skipPolicy: 'blocked',
    supportsPendingReference: false,
  ),
  const StepConfigModel(
    id: 6,
    stepCode: 'STEP_06',
    stepNameAr: 'فحص وتجهيز البضاعة والشحن',
    stepNameEn: 'Cargo Inspection & Shipping Loading',
    phaseId: 2,
    skipPolicy: 'single_approval',
    supportsPendingReference: true,
    approverRoles: ['GENERAL_MANAGER'],
    reasonCategories: ['Regulatory Exemption', 'Client Waived'],
  ),
];

Widget _buildTestApp({
  Locale locale = const Locale('ar'),
  UserModel? user,
  _MockStepConfigNotifier? configNotifier,
}) {
  final currentUser = user ?? mockAdmin;
  final notifier = configNotifier ??
      _MockStepConfigNotifier(
        StepConfigState(configs: mockConfigs, isLoading: false),
      );

  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => _MockAuthNotifier(
            AuthState(user: currentUser, isAuthenticated: true),
          )),
      stepConfigProvider.overrideWith((ref) => notifier),
      rbacProvider.overrideWith((ref) => _MockRbacNotifier(
            const RbacState(
              roles: [
                RoleModel(
                  roleId: 1,
                  roleCode: 'ADMIN',
                  nameEn: 'System Administrator',
                  nameAr: 'مدير النظام',
                  isSystemRole: true,
                  isActive: true,
                  permissions: ['*'],
                ),
                RoleModel(
                  roleId: 2,
                  roleCode: 'GENERAL_MANAGER',
                  nameEn: 'General Logistics Manager',
                  nameAr: 'مدير عام اللوجستيات',
                  isSystemRole: true,
                  isActive: true,
                  permissions: ['lifecycle_board.view', 'import_files.view'],
                ),
                RoleModel(
                  roleId: 3,
                  roleCode: 'LOGISTICS_OPERATOR',
                  nameEn: 'Logistics Operations Specialist',
                  nameAr: 'أخصائي عمليات لوجستية',
                  isSystemRole: true,
                  isActive: true,
                  permissions: ['lifecycle_board.view'],
                ),
              ],
            ),
          )),
    ],
    child: MaterialApp(
      home: AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection:
              locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: const StepConfigManagementScreen(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Non-manager (OPERATOR) sees Access Denied screen wrapped in SelectionArea',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_buildTestApp(locale: const Locale('ar'), user: mockOperator));
    await tester.pumpAndSettle();

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.textContaining('صلاحية غير كافية'), findsOneWidget);
    expect(find.textContaining('هذه الشاشة متاحة حصرياً للمدير المعتمد'),
        findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
  });

  testWidgets(
      'GENERAL_MANAGER without users.manage sees authorized table but edit actions are hidden',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_buildTestApp(locale: const Locale('ar'), user: mockGeneralManager));
    await tester.pumpAndSettle();

    // GM can access the screen
    expect(find.textContaining('إعدادات تصنيف مخاطر المراحل وحوكمة التخطي'), findsOneWidget);
    expect(find.text('STEP_01'), findsOneWidget);
    expect(find.text('STEP_06'), findsOneWidget);

    // But edit buttons are hidden because GM does not have users.manage
    expect(find.byType(EditActionButton), findsNothing);
    // Copy and audit buttons are still available
    expect(find.byIcon(Icons.copy_rounded), findsWidgets);
    expect(find.byIcon(Icons.history_rounded), findsWidgets);
  });

  testWidgets(
      'ADMIN with users.manage sees authorized table, opens edit dialog with valid roles and drops ComplianceHead',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_buildTestApp(locale: const Locale('ar'), user: mockAdmin));
    await tester.pumpAndSettle();

    // Verify SelectionArea exists
    expect(find.byType(SelectionArea), findsAtLeastNWidgets(1));

    // Verify header and table items
    expect(find.textContaining('إعدادات تصنيف مخاطر المراحل وحوكمة التخطي'),
        findsOneWidget);
    expect(find.text('STEP_01'), findsOneWidget);
    expect(find.text('تسجيل الفاتورة المبدئية'), findsOneWidget);
    expect(find.text('STEP_06'), findsOneWidget);
    expect(find.text('فحص وتجهيز البضاعة والشحن'), findsOneWidget);

    // Verify 4-action export toolbar buttons
    expect(find.byIcon(Icons.table_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    expect(find.byIcon(Icons.copy_all_rounded), findsOneWidget);

    // Verify search bar and refresh button
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    // Verify CopyableTableCell presence
    expect(find.byType(CopyableTableCell), findsWidgets);

    // Tap on row copy button
    final rowCopyButtons = find.byIcon(Icons.copy_rounded);
    expect(rowCopyButtons, findsWidgets);

    // Tap on edit button for STEP_06
    final editButtons = find.byType(EditActionButton);
    expect(editButtons, findsNWidgets(2));
    await tester.ensureVisible(editButtons.at(1));
    await tester.tap(editButtons.at(1));
    await tester.pumpAndSettle();

    // Verify Edit Dialog opened with pure Arabic fields
    expect(find.textContaining('تعديل سياسة الخطوة: STEP_06'), findsOneWidget);
    expect(find.textContaining('السبب التبريري للتعديل'), findsOneWidget);
    expect(find.text('تسجيل مرجع معلق مبكر'), findsOneWidget);

    // Verify valid role chips: GENERAL_MANAGER, ADMIN, LOGISTICS_OPERATOR
    expect(find.widgetWithText(FilterChip, 'GENERAL_MANAGER'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'ADMIN'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'LOGISTICS_OPERATOR'), findsOneWidget);

    // Verify ComplianceHead and Manager chips are completely absent
    expect(find.widgetWithText(FilterChip, 'ComplianceHead'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Manager'), findsNothing);

    // Try submitting without justification: validation error must appear
    final saveButton = find.text('حفظ التعديل وتوثيق السجل');
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('يجب إدخال سبب تبريري لا يقل عن 5 أحرف'),
        findsOneWidget);
  });

  testWidgets('Edit dialog saves payload with selected valid roles and justification',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockNotifier = _MockStepConfigNotifier(
      StepConfigState(configs: mockConfigs, isLoading: false),
    );

    await tester.pumpWidget(_buildTestApp(
      locale: const Locale('ar'),
      user: mockAdmin,
      configNotifier: mockNotifier,
    ));
    await tester.pumpAndSettle();

    // Open edit dialog for STEP_06
    final editButtons = find.byType(EditActionButton);
    await tester.ensureVisible(editButtons.at(1));
    await tester.tap(editButtons.at(1));
    await tester.pumpAndSettle();

    // Enter valid justification
    final justificationField = find.byType(TextFormField);
    await tester.enterText(justificationField, 'Direct supplier shipment approved by GM');
    await tester.pumpAndSettle();

    // Select ADMIN chip as well
    final adminChip = find.widgetWithText(FilterChip, 'ADMIN');
    expect(adminChip, findsOneWidget);
    await tester.tap(adminChip);
    await tester.pumpAndSettle();

    // Tap Save
    final saveButton = find.text('حفظ التعديل وتوثيق السجل');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify payload captured
    expect(mockNotifier.lastUpdatePayload, isNotNull);
    expect(mockNotifier.lastUpdatePayload!['stepCode'], 'STEP_06');
    expect(mockNotifier.lastUpdatePayload!['justification'], 'Direct supplier shipment approved by GM');
    final approverRoles = mockNotifier.lastUpdatePayload!['approverRoles'] as List<String>;
    expect(approverRoles, contains('GENERAL_MANAGER'));
    expect(approverRoles, contains('ADMIN'));
    expect(approverRoles.contains('ComplianceHead'), isFalse);
  });

  testWidgets('Shows SnackBar with error when updateStepConfig fails with 422',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockNotifier = _MockStepConfigNotifier(
      StepConfigState(configs: mockConfigs, isLoading: false),
    );
    mockNotifier.shouldSucceed = false;
    mockNotifier.failureError = 'فشل تعديل سياسة المرحلة: دور الاعتماد ComplianceHead غير معروف في أدوار النظام.';

    await tester.pumpWidget(_buildTestApp(
      locale: const Locale('ar'),
      user: mockAdmin,
      configNotifier: mockNotifier,
    ));
    await tester.pumpAndSettle();

    // Open edit dialog for STEP_06
    final editButtons = find.byType(EditActionButton);
    await tester.ensureVisible(editButtons.at(1));
    await tester.tap(editButtons.at(1));
    await tester.pumpAndSettle();

    // Enter valid justification
    final justificationField = find.byType(TextFormField);
    await tester.enterText(justificationField, 'Audit exception modification');
    await tester.pumpAndSettle();

    // Tap Save
    final saveButton = find.text('حفظ التعديل وتوثيق السجل');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify error SnackBar is displayed
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('ComplianceHead غير معروف'), findsOneWidget);
  });

  testWidgets('Renders properly in English mode with LTR Directionality',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_buildTestApp(locale: const Locale('en'), user: mockAdmin));
    await tester.pumpAndSettle();

    // Verify English header
    expect(
        find.text('Lifecycle Steps Risk Classification & Skip Governance'),
        findsOneWidget);
    // Verify English step names
    expect(find.text('Proforma Invoice Registration'), findsOneWidget);
    expect(find.text('Cargo Inspection & Shipping Loading'), findsOneWidget);
    // Verify English export buttons
    expect(find.text('Export TSV'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
    expect(find.text('Vector PDF'), findsOneWidget);
    expect(find.text('Copy Dossier'), findsOneWidget);
  });
}

class _MockAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRbacNotifier extends StateNotifier<RbacState>
    implements RbacNotifier {
  _MockRbacNotifier(super.state);

  @override
  Future<void> fetchRbacData() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockStepConfigNotifier extends StateNotifier<StepConfigState>
    implements StepConfigNotifier {
  _MockStepConfigNotifier(super.state);

  Map<String, dynamic>? lastUpdatePayload;
  bool shouldSucceed = true;
  String? failureError;

  @override
  Future<void> fetchConfigs() async {}

  @override
  void setSearchQuery(String q) {}

  @override
  void setFilterPhase(int? p) {}

  @override
  Future<bool> updateStepConfig({
    required String stepCode,
    String? skipPolicy,
    List<String>? reasonCategories,
    List<String>? approverRoles,
    bool? supportsPendingReference,
    required String justification,
  }) async {
    lastUpdatePayload = {
      'stepCode': stepCode,
      'skipPolicy': skipPolicy,
      'reasonCategories': reasonCategories,
      'approverRoles': approverRoles,
      'supportsPendingReference': supportsPendingReference,
      'justification': justification,
    };
    if (!shouldSucceed) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: failureError ?? 'فشل تعديل سياسة المرحلة: دور الاعتماد غير معروف.',
      );
      return false;
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
