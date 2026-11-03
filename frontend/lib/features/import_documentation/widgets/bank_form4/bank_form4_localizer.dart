import 'package:flutter/widgets.dart';

class BankForm4Localizer {
  BankForm4Localizer._();

  static bool isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  static String readinessPipelineTitle(BuildContext context) =>
      isArabic(context)
          ? 'مسار جاهزية ما قبل طلب نموذج 4'
          : 'Pre-Form 4 Readiness Pipeline';

  static String readinessPipelineSubtitle(BuildContext context) =>
      isArabic(context)
          ? 'التحقق المسبق من تكويد الأصناف وفحص جهات العرض ومطابقة سويفت البنك قبل الاعتماد'
          : 'Pre-verification of item coding, inspection authorities, and SWIFT matching before bank submission';

  static String readinessNotStarted(BuildContext context) =>
      isArabic(context) ? 'لم تبدأ الجاهزية' : 'Readiness Not Started';

  static String readinessReady100(BuildContext context) =>
      isArabic(context) ? 'جاهز للبنك (100%)' : 'Ready for Bank (100%)';

  static String readinessPendingBlockers(BuildContext context, int count) =>
      isArabic(context)
          ? 'معلق ($count متطلبات)'
          : 'Pending ($count Requirements)';

  static String pendingBlockersHeader(BuildContext context) =>
      isArabic(context)
          ? 'المتطلبات المعلقة للتقديم للبنك:'
          : 'Pending Requirements for Bank Submission:';

  static String stage1Title(BuildContext context) =>
      isArabic(context) ? '1. شيت التكويد الضريبي' : '1. Tax Coding Sheet';

  static String stage1Subtitle(BuildContext context) =>
      isArabic(context)
          ? 'سحب مستخلص ← تكويد محاسب'
          : 'Extract Pull → Accountant Coding';

  static String stage1StepA(BuildContext context) =>
      isArabic(context) ? 'أ) سحب الشيت (مستخلص)' : 'A) Pull Sheet (Extract)';

  static String stage1StepABtn(BuildContext context) =>
      isArabic(context) ? 'تسجيل سحب الشيت' : 'Record Sheet Pull';

  static String stage1StepB(BuildContext context) =>
      isArabic(context) ? 'ب) رفع وتكويد (محاسب)' : 'B) Upload & Code (Accountant)';

  static String stage1StepBBtn(BuildContext context) =>
      isArabic(context) ? 'تأكيد رفع وتكويد المحاسب' : 'Confirm Accountant Coding';

  static String stage2Title(BuildContext context) =>
      isArabic(context) ? '2. سحب وفحص الأصناف' : '2. Item Verification';

  static String stage2Subtitle(BuildContext context) =>
      isArabic(context)
          ? 'تأكيد سحب الأصناف 100% وجهات العرض'
          : 'Confirm 100% Items Pull & Inspection Bodies';

  static String stage2CodingRatio(BuildContext context, int coded, int total) {
    final totalStr = total > 0 ? '$total' : '-';
    return isArabic(context)
        ? 'نسبة التكويد: $coded / $totalStr'
        : 'Coding Ratio: $coded / $totalStr';
  }

  static String stage2Btn(BuildContext context, bool isDone) => isDone
      ? (isArabic(context) ? 'تحديث فحص الأصناف' : 'Update Item Inspection')
      : (isArabic(context) ? 'تأكيد سحب وفحص الأصناف' : 'Confirm Item Inspection');

  static String stage3Title(BuildContext context) =>
      isArabic(context) ? '3. ربط البنك على نافذة' : '3. Nafeza Bank Linkage';

  static String stage3Subtitle(BuildContext context) =>
      isArabic(context)
          ? 'مطابقة بنك السويفت مع إقرار نافذة'
          : 'Match SWIFT Bank with Nafeza Declaration';

  static String stage3SwiftBank(BuildContext context, String bank) =>
      isArabic(context) ? 'سويفت: $bank' : 'SWIFT: $bank';

  static String stage3LinkedBank(BuildContext context, String bank) =>
      isArabic(context) ? 'مربوط: $bank' : 'Linked: $bank';

  static String stage3NotLinked(BuildContext context) =>
      isArabic(context) ? 'لم يتم ربط البنك بعد' : 'Bank not linked yet';

  static String stage3Btn(BuildContext context, bool isDone) => isDone
      ? (isArabic(context) ? 'تعديل الربط البنكي' : 'Edit Bank Linkage')
      : (isArabic(context) ? 'تسجيل الربط بالبنك' : 'Record Bank Linkage');

  static String formalLetterBtn(BuildContext context) =>
      isArabic(context)
          ? 'خطاب تغطية بنكي لنموذج 4'
          : 'Bank Coverage Letter for Form 4';

  static String swiftRefBadge(BuildContext context, String ref) =>
      isArabic(context) ? 'سويفت التحويل: $ref' : 'SWIFT Ref: $ref';

  static String qualifiedBadge(BuildContext context) =>
      isArabic(context)
          ? 'مستوفي لشروط تقديم نموذج 4'
          : 'Qualified for Form 4 Submission';

  static String swiftMatchSuccess(BuildContext context, String bank) =>
      isArabic(context)
          ? 'مطابق للبنك المنفذ لسويفت التحويل ($bank)'
          : 'Matches SWIFT executing bank ($bank)';

  static String swiftMatchWarning(BuildContext context, String bank) =>
      isArabic(context)
          ? 'تحذير: لا يطابق البنك المنفذ لسويفت التحويل ($bank)!'
          : 'Warning: Does not match SWIFT executing bank ($bank)!';

  static String draftReadinessWarning(BuildContext context, int count) =>
      isArabic(context)
          ? 'تنبيه: يمكنك حفظ وتحديث مسودة الطلب، ولكن يجب استيفاء مسار الجاهزية ($count متطلبات) قبل التقديم الفعلي للبنك.'
          : 'Notice: You can save and update the draft request, but readiness pipeline ($count requirements) must be satisfied before actual bank submission.';

  static String historyTitle(BuildContext context) =>
      isArabic(context)
          ? 'سجل طلبات نموذج 4 للشحنة'
          : 'Shipment Form 4 History';

  static String noHistoryFound(BuildContext context) =>
      isArabic(context)
          ? 'لا توجد طلبات سابقة لهذه الشحنة'
          : 'No previous requests found for this shipment';

  static String copyTsv(BuildContext context) =>
      isArabic(context) ? 'نسخ كـ TSV' : 'Copy as TSV';

  static String exportExcel(BuildContext context) =>
      isArabic(context) ? 'تصدير إكسيل' : 'Export Excel';
}
