import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/localization/system_messages/system_message_renderer.dart';
import 'package:frontend/core/services/display_name_resolver.dart';
import 'package:frontend/features/experience_guide/models/guide_entry_model.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/lifecycle_board/models/lifecycle_board_model.dart';
import 'package:frontend/features/notifications/models/notification_model.dart';
import 'package:frontend/features/smart_tasks/models/smart_task_model.dart';
import 'package:frontend/core/helpers/table_copy_helper.dart';
import 'package:frontend/core/services/table_export_service.dart';
import 'package:frontend/core/utils/bidi_text.dart';

const AppLocalizations ar = AppLocalizationsAr();
const AppLocalizations en = AppLocalizationsEn();

String r(String? code, Map<String, dynamic>? params, String part, AppLocalizations l10n, {String fallback = 'FALLBACK'}) =>
    SystemMessageRenderer.stripIsolates(
      SystemMessageRenderer.render(code: code, params: params, part: part, l10n: l10n, fallback: fallback),
    );

void main() {
  group('param formatting', () {
    test('step codes -> step names (sub-steps keep their own name)', () {
      expect(r('NA_FOLLOW_UP_STEP', {'step_code': 'STEP_06'}, 'action', en), 'Follow up Booking Confirmation');
      expect(r('NA_FOLLOW_UP_STEP', {'step_code': 'STEP_06'}, 'action', ar), 'متابعة وتنفيذ تأكيد الحجز الملاحي');
      expect(r('LC_STEP_COMPLETED', {'step_code': 'STEP_08_PO'}, 'note', en), 'PO & Packing Reconciliation completed');
      expect(DisplayNameResolver.resolveStepName('STEP_08_BL', isArabic: true), 'مراجعة مسودة بوليصة الشحن');
    });

    test('phase_id -> phase name', () {
      final params = {
        'completed_step_code': 'STEP_05',
        'import_file_code': 'IMP-2026-0001',
        'step_code': 'STEP_06',
        'phase_id': 3,
      };
      expect(r('LC_TASK_NEXT_STEP', params, 'body', en), contains('in 3. Booking & Doc Prep.'));
      expect(r('LC_TASK_NEXT_STEP', params, 'body', ar), contains('ضمن المرحلة الثالثة: حجز الشحن والتدقيق المستندي المبدئي.'));
      expect(r('LC_TASK_NEXT_STEP', params, 'title', ar), '[IMP-2026-0001] — تأكيد الحجز الملاحي');
    });

    test('dates are formatted per language', () {
      final p = {'company_name': 'ACME', 'importer_id': '123', 'days_left': 5, 'expiry_date': '2026-10-04'};
      expect(r('NOTIF_COMPANY_IMPORTER_ID_EXPIRY', p, 'body', en), contains('expires on 4 Oct 2026'));
      expect(r('NOTIF_COMPANY_IMPORTER_ID_EXPIRY', p, 'body', ar), contains('وتنتهي في 4 أكتوبر 2026'));
      expect(SystemMessageRenderer.formatDate('not a date', isArabic: true), 'not a date');
    });

    test('numbers are grouped with Western digits in both languages', () {
      expect(SystemMessageRenderer.formatNumber(1234567.5), '1,234,567.5');
      expect(SystemMessageRenderer.formatNumber(12.345), '12.35');
      expect(SystemMessageRenderer.formatNumber(-1000), '-1,000');
      final p = {'claim_no': 'C-1', 'import_file_code': 'IMP-2026-0001', 'total_amount': 250000};
      expect(r('CC_DUTIES_ASSESSED', p, 'note', en), contains('total 250,000 EGP'));
      expect(r('CC_DUTIES_ASSESSED', p, 'note', ar), contains('بإجمالي (250,000 ج.م)'));
      expect(r('ALERT_BACKUP_OVERDUE', {'hours': '30.25'}, 'body', en), contains('30.25 h old'));
    });

    test('month int -> month name', () {
      expect(r('GUIDE_SEASONAL_CONGESTION', {'month': 8}, 'title', en), 'Seasonal shipment congestion in August');
      expect(r('GUIDE_SEASONAL_CONGESTION', {'month': 8}, 'title', ar), 'تأثيرات الازدحام الموسمي للشحنات خلال شهر أغسطس');
    });

    test('*_enum_<type> -> T3 label in the user language', () {
      final p = {'receipt_no': 'R-9', 'bank_enum_duty_bank': 'NBE'};
      expect(r('CC_DUTIES_PAID_BANK', p, 'note', en), contains('at National Bank of Egypt (NBE).'));
      expect(r('CC_DUTIES_PAID_BANK', p, 'note', ar), contains(ar.domainEnumLabel('duty_bank', 'NBE')!));
      final hold = {'reason_enum_hold_reason': 'AWAITING_SUPPLIER_APPROVAL'};
      expect(r('LC_STEP_ON_HOLD_CODED', hold, 'note', en), 'On hold: Awaiting foreign supplier approval');
      expect(r('LC_STEP_ON_HOLD_CODED', hold, 'note', ar),
          'معلقة مؤقتاً: ${ar.domainEnumLabel('hold_reason', 'AWAITING_SUPPLIER_APPROVAL')}');
      final task = {'import_file_code': 'IMP-2026-0001', 'task_enum_phase_follow_up_task': 'ARCHIVE_REVIEW'};
      expect(r('TASK_AUTO_PHASE_FOLLOW_UP', task, 'title', ar), 'IMP-2026-0001 — مراجعة شروط الأرشفة وإغلاق الملف التاريخي');
      // Unknown enum value is shown as sent.
      expect(r('LC_STEP_ON_HOLD_CODED', {'reason_enum_hold_reason': 'NEW_CODE'}, 'note', en), 'On hold: NEW_CODE');
    });

    test('number rules: count, *_days, *_qty, *_gb, *_factor', () {
      expect(r('ALERT_DISK_LOW', {'free_gb': 4.567}, 'body', en), contains('(4.57 GB)'));
      expect(r('NOTIF_FORM4_DELAY', {'bank_name': 'NBE', 'pending_days': 1200, 'bank_doc_code': 'B-1'}, 'body', en),
          contains('pending for 1,200 days'));
      expect(r('ALERT_SLOW_QUERY_SPIKE', {'count': 12000}, 'body', ar), contains('12,000'));
    });

    test('phase_id uses the backend phase titles, unknown ids are shown as sent', () {
      expect(r('NA_RESUME_OPERATIONS', {'phase_id': 5}, 'action', en), 'Resume operations at 5. Port Operations & Clearance');
      expect(r('NA_RESUME_OPERATIONS', {'phase_id': '6'}, 'action', ar), 'استئناف العمل عند المرحلة السادسة: الاستلام المخزني والتسوية المالية');
      expect(r('NA_RESUME_OPERATIONS', {'phase_id': 9}, 'action', en), 'Resume operations at 9');
    });

    test('comma-separated enum lists and the new enum types', () {
      final p = {'hs_code': '1234', 'product_category': 'X', 'regulatory_bodies_enum_regulatory_body': 'GOEIC, UNKNOWN_BODY', 'shipment_count': 3};
      final enText = r('GUIDE_HS_LAB_INSPECTION', p, 'body', en);
      expect(enText, contains('(${en.domainEnumLabel('regulatory_body', 'GOEIC')}, UNKNOWN_BODY)'));
      final arText = r('GUIDE_HS_LAB_INSPECTION', p, 'body', ar);
      expect(arText, contains('${ar.domainEnumLabel('regulatory_body', 'GOEIC')}، UNKNOWN_BODY'));
      final ch = {'declaration_no': 'D-1', 'channel_enum_customs_channel': 'RED'};
      expect(r('CC_DECLARATION_46_REGISTERED', ch, 'note', en), contains('on the Red Channel;'));
      expect(r('CC_DECLARATION_46_REGISTERED', ch, 'note', ar), contains('على (المسار الأحمر)'));
      expect(r('ALERT_DISPATCHED', {'severity_enum_alert_severity': 'CRITICAL', 'alert_title': 'T'}, 'title', ar), '[حرج] T');
    });

    test('verbatim params get an LTR isolate in Arabic only', () {
      final raw = SystemMessageRenderer.render(
          code: 'NA_STEP06_FOLLOW_BOOKING_CONFIRMATION_REF',
          params: {'booking_no': 'BK-77'},
          part: 'action',
          l10n: ar,
          fallback: '');
      expect(raw, contains('${SystemMessageRenderer.lri}BK-77${SystemMessageRenderer.pdi}'));
      final rawEn = SystemMessageRenderer.render(
          code: 'NA_STEP06_FOLLOW_BOOKING_CONFIRMATION_REF',
          params: {'booking_no': 'BK-77'},
          part: 'action',
          l10n: en,
          fallback: '');
      expect(rawEn, 'Follow up the booking confirmation (booking BK-77)');
    });

    test('an empty string param is valid (optional suffix)', () {
      final p = {'import_file_code': 'IMP-2026-0001', 'notes': '', 'phase_id': 2, 'reason_enum_hold_reason': 'OTHER'};
      expect(r('LC_FILE_ON_HOLD_CODED_WITH_NOTES', p, 'note', en), 'Shipment put on hold at [2. Shipment Initiation]: Other | ');
    });
  });

  group('fallback to the stored text', () {
    test('null / empty / unknown code', () {
      expect(r(null, null, 'title', ar, fallback: 'stored'), 'stored');
      expect(r('', null, 'title', ar, fallback: 'stored'), 'stored');
      expect(r('FUTURE_CODE_X', {'a': 1}, 'title', ar, fallback: 'stored'), 'stored');
    });

    test('part without template or missing param', () {
      expect(r('NA_FILE_CLOSED', null, 'title', en, fallback: 'stored'), 'stored');
      expect(r('NA_FOLLOW_UP_STEP', {}, 'action', ar, fallback: 'stored'), 'stored');
      expect(r('NA_FOLLOW_UP_STEP', {'step_code': null}, 'action', ar, fallback: 'stored'), 'stored');
      expect(
        SystemMessageRenderer.tryRender(code: 'NA_FOLLOW_UP_STEP', params: null, part: 'action', l10n: en),
        isNull,
      );
    });

    test('parseParams accepts a map, a JSON string or garbage', () {
      expect(SystemMessageRenderer.parseParams({'a': 1}), {'a': 1});
      expect(SystemMessageRenderer.parseParams('{"a": 2}'), {'a': 2});
      expect(SystemMessageRenderer.parseParams('not json'), isNull);
      expect(SystemMessageRenderer.parseParams(null), isNull);
      expect(SystemMessageRenderer.parseCode('  '), isNull);
    });
  });

  group('models', () {
    test('smart task: new fields, rendered title, legacy fallback', () {
      final coded = SmartTaskModel.fromJson({
        'task_id': 1,
        'title': '[IMP-2026-0001] - Booking Confirmation',
        'description': 'stored en description',
        'msg_code': 'LC_TASK_NEXT_STEP',
        'msg_params': {
          'import_file_code': 'IMP-2026-0001',
          'step_code': 'STEP_06',
          'completed_step_code': 'STEP_05',
          'phase_id': 3,
        },
        'step_code': 'STEP_06',
      });
      expect(coded.msgCode, 'LC_TASK_NEXT_STEP');
      expect(coded.stepCode, 'STEP_06');
      expect(SystemMessageRenderer.stripIsolates(coded.displayTitle(ar)), '[IMP-2026-0001] — تأكيد الحجز الملاحي');
      expect(SystemMessageRenderer.stripIsolates(coded.displayDescription(ar)), startsWith('تم إكمال'));
      expect(coded.localizedNotes(en), 'Auto-generated after Nafeza ACID Issue was completed');
      expect(coded.toJson()['msg_code'], 'LC_TASK_NEXT_STEP');

      final legacy = SmartTaskModel.fromJson({'task_id': 2, 'title': 'مهمة يدوية', 'notes': 'n'});
      expect(legacy.msgCode, isNull);
      expect(legacy.msgParams, isNull);
      expect(legacy.stepCode, isNull);
      expect(legacy.displayTitle(ar), DisplayNameResolver.cleanTaskTitle('مهمة يدوية', isArabic: true));
      expect(legacy.localizedNotes(ar), 'n');
      expect(legacy.toJson().containsKey('msg_code'), isFalse);
    });

    test('notification: rendered title/message, legacy fallback, copyWith keeps code', () {
      final n = NotificationModel.fromJson({
        'notification_id': 1,
        'title': 'Demurrage warning: IMP-2026-0002',
        'message': 'stored',
        'msg_code': 'NOTIF_DEMURRAGE_WARNING',
        'msg_params': {'import_file_code': 'IMP-2026-0002', 'days_left': 2},
        'created_at': '2026-09-29',
      });
      expect(SystemMessageRenderer.stripIsolates(n.localizedTitle(ar)), 'تحذير أرضيات: IMP-2026-0002');
      expect(n.localizedTitle(en), 'Demurrage warning: IMP-2026-0002');
      expect(n.copyWith(isRead: true).msgCode, 'NOTIF_DEMURRAGE_WARNING');
      final legacy = NotificationModel.fromJson({'notification_id': 2, 'title': 'قديم', 'message': 'نص'});
      expect(legacy.localizedTitle(en), 'قديم');
      expect(legacy.localizedMessage(en), 'نص');
    });

    test('import file: codes drive step/phase/next action; legacy rows keep text', () {
      final f = ImportFileModel.fromJson({
        'import_file_id': 1,
        'import_file_code': 'IMP-2026-0001',
        'current_module': 'STEP_06 Freight Booking',
        'current_stage': 'Phase 3: Booking & Doc Prep',
        'next_action': 'Follow up Freight Booking',
        'current_step_code': 'STEP_06',
        'current_phase_id': 3,
        'current_stage_code': 'PHASE_3',
        'next_action_code': 'NA_FOLLOW_UP_STEP',
        'next_action_params': {'step_code': 'STEP_06'},
        'hold_reason_code': 'OTHER',
      });
      expect(f.currentStepCode, 'STEP_06');
      expect(f.currentPhaseId, 3);
      expect(f.currentStageCode, 'PHASE_3');
      expect(f.holdReasonCode, 'OTHER');
      expect(f.displayStepKey, 'STEP_06');
      expect(f.codedStageLabel(en), '3. Booking & Doc Prep');
      expect(f.codedStageLabel(ar), 'المرحلة الثالثة: حجز الشحن والتدقيق المستندي المبدئي');
      expect(f.displayNextAction(ar), 'متابعة وتنفيذ تأكيد الحجز الملاحي');

      final legacy = ImportFileModel.fromJson({
        'import_file_id': 2,
        'import_file_code': 'IMP-2025-0009',
        'current_module': 'STEP_02 الدراسات',
        'current_stage': 'Phase 1',
        'next_action': 'متابعة قديمة',
      });
      expect(legacy.currentStepCode, isNull);
      expect(legacy.nextActionParams, isNull);
      expect(legacy.displayStepKey, 'STEP_02 الدراسات');
      expect(legacy.codedStageLabel(en), isNull);
      expect(legacy.displayStage(en, (t) => 'legacy:$t'), 'legacy:Phase 1');
      expect(legacy.displayNextAction(en), DisplayNameResolver.resolveActionTitle('متابعة قديمة', isArabic: false));
    });

    test('import file: special stage codes show the STAGE label, not the phase', () {
      Map<String, dynamic> json(String? stageCode, {Object? phaseId = 5, String stage = 'Customs Released'}) => {
            'import_file_id': 3,
            'import_file_code': 'IMP-2026-0003',
            'current_module': 'STEP_17 Final Customs Calculation',
            'current_stage': stage,
            'next_action': 'x',
            'current_step_code': 'STEP_17',
            'current_phase_id': phaseId,
            'current_stage_code': stageCode,
          };
      final released = ImportFileModel.fromJson(json('CUSTOMS_RELEASED'));
      expect(released.codedStageLabel(en), 'Customs Released');
      expect(released.codedStageLabel(ar), 'تم الإفراج الجمركي النهائي وبدء النقل');
      // Operational step / closed fallback / chips all go through displayStage.
      expect(released.displayStage(ar, (t) => 'legacy'), 'تم الإفراج الجمركي النهائي وبدء النقل');
      // Unknown special stage: the stored text, then the code.
      expect(ImportFileModel.fromJson(json('NEW_STAGE', stage: 'Stored stage')).codedStageLabel(en), 'Stored stage');
      expect(ImportFileModel.fromJson(json('NEW_STAGE', stage: '')).codedStageLabel(en), 'NEW_STAGE');
      // PHASE_n uses the phase title; a string phase id is accepted.
      expect(ImportFileModel.fromJson(json('PHASE_5', phaseId: '5')).codedStageLabel(en), '5. Port Operations & Clearance');
      expect(ImportFileModel.fromJson(json('PHASE_6', phaseId: null)).codedStageLabel(en), '6. Inbound & Final Closure');
      expect(ImportFileModel.fromJson(json(null, phaseId: ' 2 ')).currentPhaseId, 2);
    });

    test('non-finite numbers are shown as sent', () {
      expect(SystemMessageRenderer.formatNumber(double.nan), 'NaN');
      expect(SystemMessageRenderer.formatNumber(double.infinity), 'Infinity');
    });

    test('export paths strip the bidi isolates', () {
      final f = ImportFileModel.fromJson({
        'import_file_id': 4,
        'import_file_code': 'IMP-2026-0004',
        'current_module': '',
        'current_stage': '',
        'next_action': '',
        'next_action_code': 'NA_STEP06_FOLLOW_BOOKING_CONFIRMATION_REF',
        'next_action_params': {'booking_no': 'BK-9'},
      });
      expect(f.displayNextAction(ar), contains(SystemMessageRenderer.lri));
      final exported = f.displayNextAction(ar, forExport: true);
      expect(exported, isNot(contains(SystemMessageRenderer.lri)));
      expect(exported, contains('(Booking: BK-9)'));
      final cell = '${SystemMessageRenderer.lri}IMP-1${SystemMessageRenderer.pdi}';
      expect(TableCopyHelper.cleanCell(cell), 'IMP-1');
      expect(TableExportService.buildCsvContent(['h'], [[cell]]), isNot(contains(SystemMessageRenderer.lri)));
      expect(TableExportService.buildTsvContent(['h'], [[cell]]), isNot(contains(SystemMessageRenderer.pdi)));
      expect(stripBidiIsolates('a${SystemMessageRenderer.lri}b'), 'ab');
    });

    test('guide evidence/reason: null when neither a rendered part nor a stored text exists', () {
      final g = GuideEntryModel.fromJson({'entry_id': 3, 'title': 't', 'content': 'c', 'msg_code': 'NA_FILE_CLOSED'});
      expect(g.localizedEvidence(en), isNull);
      expect(g.localizedReason(en), isNull);
    });

    test('lifecycle stage card + live item', () {
      final card = ShipmentStageCardModel.fromJson({
        'step_code': 'STEP_07',
        'status': 'In-Progress',
        'notes': 'Activated after Freight Booking completed',
        'msg_code': 'LC_STEP_ACTIVATED',
        'msg_params': {'completed_step_code': 'STEP_06'},
      });
      expect(card.localizedNotes(ar), 'تم التفعيل بعد إكمال تأكيد الحجز الملاحي');
      final legacyCard = ShipmentStageCardModel.fromJson({'step_code': 'STEP_07', 'status': 'x', 'notes': 'قديم'});
      expect(legacyCard.msgCode, isNull);
      expect(legacyCard.localizedNotes(en), 'قديم');

      final item = LiveLogisticsTrackingItemModel.fromJson({
        'import_file_id': 1,
        'import_file_code': 'IMP-2026-0001',
        'next_action': 'Import file closed',
        'next_action_code': 'NA_FILE_CLOSED',
      });
      expect(item.nextActionCode, 'NA_FILE_CLOSED');
    });

    test('guide entry: title/content/evidence/reason', () {
      final g = GuideEntryModel.fromJson({
        'entry_id': 1,
        'title': 'stored title',
        'content': 'stored content',
        'msg_code': 'GUIDE_SEASONAL_CONGESTION',
        'msg_params': {'month': 1, 'shipment_count': 4},
      });
      expect(g.localizedTitle(ar), 'تأثيرات الازدحام الموسمي للشحنات خلال شهر يناير');
      expect(g.localizedContent(en), startsWith('Shipments opened in January'));
      expect(g.localizedEvidence(en), contains('4 shipments'));
      expect(g.localizedReason(ar), contains('يناير'));
      final human = GuideEntryModel.fromJson({'entry_id': 2, 'title': 'يدوي', 'content': 'c'});
      expect(human.localizedTitle(en), 'يدوي');
      expect(human.localizedEvidence(en), isNull);
    });
  });
}
