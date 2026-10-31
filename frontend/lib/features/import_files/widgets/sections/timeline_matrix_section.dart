import 'package:flutter/material.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_file_model.dart';

/// Timeline Matrix comparison section (25-stage lifecycle planned vs actual).
class TimelineMatrixSection extends StatelessWidget {
  final List<ImportFileModel> files;
  final bool isDarkDialog;
  final bool isAr;

  const TimelineMatrixSection({
    super.key,
    required this.files,
    required this.isDarkDialog,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    final targetFile = files.firstWhere(
      (f) => f.importFileCode == 'IMP-2026-0005',
      orElse: () => files.first,
    );
    final stages = _getTimelineStagesForFile(targetFile);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkDialog ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDarkDialog ? AppTheme.darkBorder : AppTheme.cobalt.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkDialog ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isAr ? 'بيانات الجدول الزمني لشحنة: ' : 'Timeline data for: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
              CopyableText(
                '${targetFile.customFileNumber ?? targetFile.importFileCode} (${targetFile.companyName})',
                showIcon: false,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.copy, size: 14, color: Colors.white),
                label: Text(
                  isAr ? 'نسخ الجدول الزمني' : 'Copy Timeline',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final headers = [
                    'م',
                    'كود المرحلة',
                    'اسم المرحلة',
                    'الحزمة',
                    'المخطط',
                    'الفعلي',
                    'الفارق',
                    'الحالة',
                    'الملاحظات التشغيلية',
                  ];
                  final rows = stages.map((s) => [
                    s['num'].toString(),
                    s['code'].toString(),
                    s['name'].toString(),
                    s['phase'].toString(),
                    s['planned'].toString(),
                    s['actual'].toString(),
                    s['variance'].toString(),
                    s['status'].toString(),
                    s['note'].toString(),
                  ]).toList();

                  TableCopyHelper.copyTable(
                    context,
                    headers,
                    rows,
                    customMessage: isAr ? 'تم نسخ الجدول الزمني (25 مرحلة) بنجاح' : 'Timeline table copied successfully',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectionArea(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDarkDialog ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.06)),
                headingTextStyle: TextStyle(color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 11),
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('م')),
                  DataColumn(label: Text('كود المرحلة')),
                  DataColumn(label: Text('المرحلة الإجرائية')),
                  DataColumn(label: Text('الحزمة')),
                  DataColumn(label: Text('التاريخ المخطط')),
                  DataColumn(label: Text('التاريخ الفعلي')),
                  DataColumn(label: Text('الفارق')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('الملاحظات التشغيلية والتوجيهات الحتمية')),
                ],
                rows: stages.map((s) {
                  final isDone = s['status'] == 'منجز';
                  final isCurrent = s['status'] == 'قيد التنفيذ';
                  final statusColor = isDone ? AppTheme.emerald : (isCurrent ? Colors.orange.shade800 : Colors.grey);
                  return DataRow(
                    cells: [
                      DataCell(Text(s['num'].toString(), style: const TextStyle(fontSize: 11))),
                      DataCell(Text(s['code'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataCell(Text(s['name'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataCell(Text(s['phase'].toString(), style: const TextStyle(fontSize: 11))),
                      DataCell(Text(s['planned'].toString(), style: const TextStyle(fontSize: 11))),
                      DataCell(Text(s['actual'].toString(), style: TextStyle(fontSize: 11, fontWeight: isDone ? FontWeight.bold : FontWeight.normal))),
                      DataCell(Text(s['variance'].toString(), style: TextStyle(fontSize: 11, color: s['variance'] == 'في الموعد' ? AppTheme.emerald : Colors.red.shade700))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(s['status'].toString(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 340,
                          child: Text(
                            s['note'].toString(),
                            style: TextStyle(fontSize: 11, color: isDarkDialog ? AppTheme.darkTextSecondary : AppTheme.charcoal, fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getTimelineStagesForFile(ImportFileModel file) {
    if (file.importFileCode == 'IMP-2026-0005') {
      return [
        {"num": 1, "code": "STEP_01", "name": "دراسات ومفاضلة نولون الشحن", "phase": "Phase 1", "planned": "2026-09-15", "actual": "2026-09-15", "variance": "في الموعد", "status": "منجز", "note": "يجب الشحن إلى ميناء الإسكندرية (الميناء القديم حتمي) ومفاضلة عروض الخطوط المباشرة"},
        {"num": 2, "code": "STEP_02", "name": "الدراسات والاستشارات الجمركية", "phase": "Phase 1", "planned": "2026-09-16", "actual": "2026-09-16", "variance": "في الموعد", "status": "منجز", "note": "ألواح عزل صوتي PET (بند 3920.62) تتطلب فحص هيئة الرقابة على الصادرات والواردات GOEIC ومواصفة الحريق (مطلوب شهادة إيلاك/فحص المصنع)"},
        {"num": 3, "code": "STEP_03", "name": "متطلبات واشتراطات الاستيراد للشحنة", "phase": "Phase 1", "planned": "2026-09-17", "actual": "2026-09-17", "variance": "في الموعد", "status": "منجز", "note": "الشحنة شراء جديد (New Purchase) - استيفاء الفحص المسبق واعتماد اشتراطات شركة SCAS"},
        {"num": 4, "code": "STEP_04", "name": "اعتمادات الميزانية وسداد الموردين", "phase": "Phase 1", "planned": "2026-09-18", "actual": "2026-09-18", "variance": "في الموعد", "status": "منجز", "note": "اعتماد ميزانية 39,820 USD وسداد الدفعة المقدمة 30% للمورد بسعر صرف 48.70 ج.م"},
        {"num": 5, "code": "STEP_05", "name": "الرقم التعريفي المبدئي للشحنة ACID", "phase": "Phase 2", "planned": "2026-09-20", "actual": "2026-10-19", "variance": "+29 يوم", "status": "منجز", "note": "استخراج ACID رقم 5281534391025810014 (صالح لـ 90 يوماً حتى 2027-01-17)"},
        {"num": 6, "code": "STEP_06", "name": "حجز النولون وتأكيد الخط الملاحي", "phase": "Phase 3", "planned": "2026-09-22", "actual": "2026-09-22", "variance": "في الموعد", "status": "منجز", "note": "تأكيد حجز THXJ2609015 مع الخط Wan Hai Lines وتثبيت 21 يوماً سماح غرامات باتفاقية الخط"},
        {"num": 7, "code": "STEP_07", "name": "تخصيص وتوزيع الحاويات والبضائع", "phase": "Phase 3", "planned": "2026-09-23", "actual": "2026-09-24", "variance": "+1 يوم", "status": "منجز", "note": "تخصيص حاوية 40HC رقم WHSU81072658 برقم سيل WHA257097 بحمولة 180 طرد (وزن VGM: 24,500 كجم)"},
        {"num": 8, "code": "STEP_08_PO", "name": "مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء", "phase": "Phase 3", "planned": "2026-09-24", "actual": "2026-10-19", "variance": "+25 يوم", "status": "منجز", "note": "مطابقة تامة 100% بين PO-2026-005 والفاتورة وقائمة التعبئة لـ 12 صنفاً (1,800 قطعة)"},
        {"num": 9, "code": "STEP_08_BL", "name": "مراجعة واعتماد مسودة بوليصة الشحن", "phase": "Phase 3", "planned": "2026-09-25", "actual": "2026-10-20", "variance": "+25 يوم", "status": "منجز", "note": "جلسة BL-REV-2026-0002 معتمدة Dual Approved من المستورد والمخلص بدون اختلافات (0 Discrepancies)"},
        {"num": 10, "code": "STEP_08_MATCH", "name": "المطابقة الذكية بين الفاتورة والبوليصة", "phase": "Phase 3", "planned": "2026-09-26", "actual": "2026-10-20", "variance": "+24 يوم", "status": "منجز", "note": "مطابقة الشاحن والمستورد والوزن القائم (12,840 كجم) ورقم ACID مع البوليصة WHL-SHA-2026-9015"},
        {"num": 11, "code": "STEP_08_COO", "name": "مسودة شهادة المنشأ و EUR.1", "phase": "Phase 3", "planned": "2026-10-01", "actual": "قيد التنفيذ", "variance": "+19 يوم", "status": "قيد التنفيذ", "note": "[المرحلة الحالية] متابعة إصدار شهادة المنشأ الصينية Form FTA وتجهيزها للرفع عبر منصة كارجو إكس"},
        {"num": 12, "code": "STEP_08_COC", "name": "شهادات الفحص والتفتيش والمطابقة", "phase": "Phase 3", "planned": "2026-10-05", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "تجهيز شهادات الفحص واختبارات الحريق لألواح الـ PET قبل وصول الباخرة"},
        {"num": 13, "code": "STEP_09", "name": "الاعتماد النهائي للمستندات الجمركية", "phase": "Phase 4", "planned": "2026-10-08", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "اعتماد المخلص نبيل نصيف لكامل ملف المستندات النهائي تمهيداً لرفعه على كارجو إكس"},
        {"num": 14, "code": "STEP_10", "name": "رفع ومتابعة مستندات CargoX", "phase": "Phase 4", "planned": "2026-10-12", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "إرسال ظرف CargoX الرقمي للمستندات لربطه مع منصة نافذة قبل وصول السفينة"},
        {"num": 15, "code": "STEP_11", "name": "تحصيل واستلام أصول المستندات", "phase": "Phase 4", "planned": "2026-10-15", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "متابعة إرسال أصول المستندات عبر البريد السريع DHL ومتابعة رقم البوليصة السريعة"},
        {"num": 16, "code": "STEP_12", "name": "استخراج واعتماد نموذج 4 البنكي", "phase": "Phase 4", "planned": "2026-10-20", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "تقديم مستندات الشحن للبنك لفتح نموذج 4 والتحويل النهائي للرصيد المتبقي 70%"},
        {"num": 17, "code": "STEP_13", "name": "قيد ومطابقة إقرار 46 ك.م", "phase": "Phase 5", "planned": "2026-10-23", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "فتح وتثبيت الشهادة الجمركية الموحدة فور رسو الباخرة بميناء الإسكندرية (ETA: 2026-10-23)"},
        {"num": 18, "code": "STEP_14", "name": "متابعة الكشف والتثمين", "phase": "Phase 5", "planned": "2026-10-25", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "معاينة الحاوية بالساحة المشتركة مع كشاف الجمرك والمثمن لسرعة الإجراءات"},
        {"num": 19, "code": "STEP_15", "name": "سحب العينات / محاضر العجز", "phase": "Phase 5", "planned": "2026-10-27", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "سحب عينات الفحص النوعي لهيئة الرقابة على الصادرات والواردات GOEIC ومطابقة الحريق"},
        {"num": 20, "code": "STEP_16", "name": "محاضر المعاينة والأضرار", "phase": "Phase 5", "planned": "2026-10-29", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "استلام تقرير المطابقة الفنية وسلامة الطرود وخلوها من التلف أو العجز"},
        {"num": 21, "code": "STEP_17", "name": "الحساب والسداد الجمركي النهائي", "phase": "Phase 5", "planned": "2026-10-31", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "احتساب الرسوم الجمركية وسدادها فوراً عبر سداد CBE وإصدار الإفراج الأخضر"},
        {"num": 22, "code": "STEP_18", "name": "إدارة الغرامات وفترات السماح", "phase": "Phase 5", "planned": "2026-11-02", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "خروج الحاوية من بوابة الميناء ضمن فترة السماح (21 يوماً) وترجيع الحاوية فارغة"},
        {"num": 23, "code": "STEP_19", "name": "إذن الإضافة والاستلام المخزني GRN", "phase": "Phase 6", "planned": "2026-11-04", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "وصول الشاحنة لمخازن SCAS، التعتيق وفحص الأصناف وإصدار إذن إضافة مخزني"},
        {"num": 24, "code": "STEP_20", "name": "تسوية التكلفة الاستيرادية الشاملة", "phase": "Phase 6", "planned": "2026-11-06", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "تسوية فواتير النولون والتخليص والنقل واحتساب التكلفة الفعلية Landed Cost بالجنيه"},
        {"num": 25, "code": "STEP_21", "name": "الإغلاق النهائي للملف الاستيرادي", "phase": "Phase 6", "planned": "2026-11-08", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "أرشفة كامل ملف العملية واسترداد تأمين الحاوية من التوكيل الملاحي وإغلاق الملف"},
      ];
    }
    return [
      {"num": 1, "code": "STEP_01", "name": "دراسات ومفاضلة نولون الشحن", "phase": "Phase 1", "planned": file.fileOpeningDate ?? "2026-09-15", "actual": file.fileOpeningDate ?? "2026-09-15", "variance": "في الموعد", "status": "منجز", "note": "مفاضلة عروض النولون والخطوط الملاحية المباشرة"},
      {"num": 2, "code": "STEP_02", "name": "الدراسات والاستشارات الجمركية", "phase": "Phase 1", "planned": "2026-09-16", "actual": "2026-09-16", "variance": "في الموعد", "status": "منجز", "note": "تحديد البند الجمركي والجهات العارضة والاشتراطات"},
      {"num": 3, "code": "STEP_05", "name": "الرقم التعريفي المبدئي للشحنة ACID", "phase": "Phase 2", "planned": file.cargoReadyDate ?? "2026-09-20", "actual": file.acidNumber != null ? "منجز" : "قيد الانتظار", "variance": "—", "status": file.acidNumber != null ? "منجز" : "قيد الانتظار", "note": file.acidNumber != null ? "رقم ACID: ${file.acidNumber}" : "بانتظار استخراج رقم نافذة"},
      {"num": 4, "code": "STEP_06", "name": "حجز النولون وتأكيد الخط الملاحي", "phase": "Phase 3", "planned": file.cargoReadyDate ?? "2026-09-22", "actual": file.bookingNo != null ? "منجز" : "قيد الانتظار", "variance": "—", "status": file.bookingNo != null ? "منجز" : "قيد الانتظار", "note": "حجز الشحن: ${file.bookingNo ?? 'قيد التنسيق'} | السفينة: ${file.vesselName ?? 'قيد الحجز'}"},
      {"num": 5, "code": "STEP_08_BL", "name": "مراجعة واعتماد مسودة بوليصة الشحن", "phase": "Phase 3", "planned": "2026-09-25", "actual": file.blNumber != null ? "منجز" : "قيد الانتظار", "variance": "—", "status": file.blNumber != null ? "منجز" : "قيد الانتظار", "note": "بوليصة الشحن: ${file.blNumber ?? 'قيد المراجعة والاعتماد'}"},
      {"num": 6, "code": "STEP_13", "name": "قيد ومطابقة إقرار 46 ك.م", "phase": "Phase 5", "planned": file.requiredEta ?? "2026-10-23", "actual": file.form46No ?? "قيد الانتظار", "variance": "—", "status": file.form46No != null ? "منجز" : "قيد الانتظار", "note": "فتح الشهادة الجمركية فور وصول السفينة"},
      {"num": 7, "code": "STEP_17", "name": "الحساب والسداد الجمركي النهائي", "phase": "Phase 5", "planned": "2026-10-31", "actual": file.customsReleasePermitNo ?? "قيد الانتظار", "variance": "—", "status": file.customsReleasePermitNo != null ? "منجز" : "قيد الانتظار", "note": "سداد الرسوم واستخراج إذن الإفراج الأخضر"},
      {"num": 8, "code": "STEP_19", "name": "إذن الإضافة والاستلام المخزني GRN", "phase": "Phase 6", "planned": "2026-11-04", "actual": "قيد الانتظار", "variance": "—", "status": file.customsReleasePermitNo != null ? "منجز" : "قيد الانتظار", "note": "إتمام التعتيق والفحص وإصدار إذن إضافة مخزني"},
      {"num": 9, "code": "STEP_20", "name": "تسوية التكلفة الاستيرادية الشاملة", "phase": "Phase 6", "planned": "2026-11-06", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "احتساب تكلفة الوصول النهائية Landed Cost"},
      {"num": 10, "code": "STEP_21", "name": "الإغلاق النهائي للملف الاستيرادي", "phase": "Phase 6", "planned": "2026-11-08", "actual": "قيد الانتظار", "variance": "—", "status": "قيد الانتظار", "note": "الأرشفة الكاملة واسترداد تأمين الحاويات"},
    ];
  }
}
