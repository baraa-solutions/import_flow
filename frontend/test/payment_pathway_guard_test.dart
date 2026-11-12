import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/api_error_text.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/import_files/models/payment_pathway_status_model.dart';
import 'package:frontend/features/import_files/providers/payment_pathway_provider.dart';
import 'package:frontend/features/import_files/widgets/file_details/payment_pathway_guard.dart';

Map<String, dynamic> _lcJson({bool blocked = true}) => {
      'import_file_id': 7,
      'import_file_code': 'IMP-2026-0007',
      'payment_term': 'LC',
      'is_pathway_set': true,
      'current_phase_id': 2,
      'current_step_code': 'STEP_04',
      'milestones': [
        {
          'code': 'LC_MT700_ISSUED',
          'label_en': 'Letter of Credit issued (SWIFT MT700)',
          'label_ar': 'إصدار الاعتماد المستندي (سويفت MT700)',
          'evidence_en': 'LC instrument issued',
          'evidence_ar': 'أداة اعتماد صادرة',
          'is_completed': true,
          'required_before_gate': 'PHASE_3',
          'required_before_label_en': 'Phase 3: Booking & Doc Prep',
          'required_before_label_ar': 'المرحلة الثالثة',
        },
        {
          'code': 'LC_SHIPMENT_DEADLINE',
          'label_en': 'LC latest shipment date recorded',
          'label_ar': 'تسجيل آخر موعد للشحن في الاعتماد',
          'is_completed': !blocked,
          'required_before_gate': 'PHASE_3',
          'required_before_label_en': 'Phase 3: Booking & Doc Prep',
          'required_before_label_ar': 'المرحلة الثالثة',
        },
      ],
      'gates': [
        {
          'gate': 'PHASE_3',
          'label_en': 'Phase 3: Booking & Doc Prep',
          'label_ar': 'المرحلة الثالثة',
          'required_milestones': ['LC_MT700_ISSUED', 'LC_SHIPMENT_DEADLINE'],
          'missing_milestones': blocked ? ['LC_SHIPMENT_DEADLINE'] : [],
          'is_satisfied': !blocked,
          'is_passed': false,
        },
        {
          'gate': 'STEP_12',
          'label_en': 'STEP_12 Bank Form 4',
          'label_ar': 'STEP_12 نموذج 4',
          'required_milestones': ['LC_DOCS_HONOURED'],
          'missing_milestones': ['LC_DOCS_HONOURED'],
          'is_satisfied': false,
          'is_passed': false,
          'is_waived': true,
        },
      ],
      'completed_count': blocked ? 1 : 2,
      'total_count': 2,
      'next_blocking_gate': blocked ? 'PHASE_3' : null,
      'is_blocked': blocked,
      'blocking_reasons_en': blocked ? ['LC latest shipment date recorded — required before Phase 3'] : [],
      'blocking_reasons_ar': blocked ? ['تسجيل آخر موعد للشحن — مطلوب قبل المرحلة الثالثة'] : [],
    };

Widget _host(PaymentPathwayStatus status, {bool isAr = false}) => ProviderScope(
      overrides: [
        paymentPathwayStatusProvider(7).overrideWith((ref) async => status),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaymentPathwayGuard(importFileId: 7, isAr: isAr, isDark: false),
          ),
        ),
      ),
    );

void main() {
  group('PaymentPathwayStatus model', () {
    test('parses milestones, gates and blocking reasons', () {
      final s = PaymentPathwayStatus.fromJson(_lcJson());
      expect(s.paymentTerm, 'LC');
      expect(s.isPathwaySet, isTrue);
      expect(s.milestones, hasLength(2));
      expect(s.pendingMilestones.single.code, 'LC_SHIPMENT_DEADLINE');
      expect(s.progress, 0.5);
      expect(s.isBlocked, isTrue);
      expect(s.isPhaseBlocked(3), isTrue);
      expect(s.isPhaseBlocked(4), isFalse);
      expect(s.blockingReasons(true).single, contains('مطلوب قبل'));
      expect(s.blockingReasons(false).single, contains('required before'));
    });

    test('waived or satisfied gates are not blocking', () {
      final s = PaymentPathwayStatus.fromJson(_lcJson(blocked: false));
      expect(s.isGateBlocked('PHASE_3'), isFalse);
      // STEP_12 misses its milestone but is waived (skipped step): never blocking.
      expect(s.isGateBlocked('STEP_12'), isFalse);
      expect(s.gates.last.isWaived, isTrue);
      expect(s.isBlocked, isFalse);
    });

    test('tolerates an empty / unset pathway payload', () {
      final s = PaymentPathwayStatus.fromJson({'import_file_id': 3, 'is_pathway_set': false});
      expect(s.isPathwaySet, isFalse);
      expect(s.milestones, isEmpty);
      expect(s.progress, 1.0);
    });
  });

  group('PaymentPathwayGuard widget', () {
    testWidgets('shows pathway, milestones and the blocking banner', (tester) async {
      await tester.pumpWidget(_host(PaymentPathwayStatus.fromJson(_lcJson())));
      await tester.pumpAndSettle();

      expect(find.text('Payment Pathway Guard'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-pathway-label')), findsOneWidget);
      expect(find.text('1/2 completed'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-pathway-blocked')), findsOneWidget);
      expect(find.textContaining('required before Phase 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-milestone-LC_MT700_ISSUED')), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-milestone-LC_SHIPMENT_DEADLINE')), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-gate-PHASE_3')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('no blocking banner when the next gate is satisfied', (tester) async {
      await tester.pumpWidget(_host(PaymentPathwayStatus.fromJson(_lcJson(blocked: false))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('payment-pathway-blocked')), findsNothing);
      expect(find.text('2/2 completed'), findsOneWidget);
    });

    testWidgets('renders Arabic texts', (tester) async {
      await tester.pumpWidget(_host(PaymentPathwayStatus.fromJson(_lcJson()), isAr: true));
      await tester.pumpAndSettle();
      expect(find.text('حارس مسار الدفع والبوابات المصرفية'), findsOneWidget);
      expect(find.text('1/2 مكتمل'), findsOneWidget);
      expect(find.textContaining('مطلوب قبل المرحلة الثالثة'), findsOneWidget);
    });

    testWidgets('unset pathway shows the inactive notice', (tester) async {
      await tester.pumpWidget(_host(
        PaymentPathwayStatus.fromJson({'import_file_id': 7, 'is_pathway_set': false}),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('No payment pathway set yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-pathway-blocked')), findsNothing);
    });

    testWidgets('refresh button re-fetches the live status', (tester) async {
      var calls = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          paymentPathwayStatusProvider(7).overrideWith((ref) async {
            calls++;
            return PaymentPathwayStatus.fromJson(_lcJson());
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PaymentPathwayGuard(importFileId: 7, isAr: false, isDark: false)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.byKey(const ValueKey('payment-pathway-refresh')));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });
  });

  group('PAYMENT_MILESTONE_GATE_BLOCKED error text', () {
    DioException gateError() {
      final req = RequestOptions(path: '/api/v1/original-documents-collection');
      return DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: 409, data: {
          'detail': {
            'code': 'PAYMENT_MILESTONE_GATE_BLOCKED',
            'message': 'لا يمكن نقل ملف الشحنة قبل استيفاء البوابات المصرفية',
            'message_en': 'Import file cannot move until these banking milestones are met',
            'gate': 'PHASE_4',
          },
        }),
      );
    }

    test('English UI uses message_en, Arabic UI uses message', () {
      expect(ApiErrorText.of(const AppLocalizationsEn(), gateError()), contains('banking milestones are met'));
      expect(ApiErrorText.of(const AppLocalizationsAr(), gateError()), contains('البوابات المصرفية'));
    });

    testWidgets('save failure snackbar shows the gate message', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(
                context,
                ApiErrorText.of(const AppLocalizationsEn(), gateError()),
                severity: AppSeverity.danger,
              )),
              child: const Text('save'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('save'));
      await tester.pump();
      expect(find.textContaining('banking milestones are met'), findsOneWidget);
    });
  });
}
