import 'package:flutter/material.dart';

import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/shipping_scenario_model.dart';

class ShippingScenarioExporter {
  static Future<void> exportScenarioCsv(
    BuildContext context,
    ShippingEvaluationModel sess, [
    List<ImportFileModel>? importFiles,
  ]) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rawFileCode = sess.importFileCode ?? (sess.importFileId != null ? 'IMP-${sess.importFileId}' : '-');
    final shipmentTitle = rawFileCode != '-' ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic) : '-';

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('Sorour Logistics ERP — تقرير دراسة وتقييم سيناريوهات الشحن');
    buffer.writeln('كود الدراسة,${sess.sessionCode}');
    buffer.writeln('عنوان الدراسة,"${(sess.title ?? '').replaceAll('"', '""')}"');
    buffer.writeln('كود ملف الاستيراد,$rawFileCode');
    if (shipmentTitle != '-') {
      buffer.writeln('اسم الشحنة التجاري,"${shipmentTitle.replaceAll('"', '""')}"');
    }
    buffer.writeln('أمر الشراء,${sess.poNumber ?? "-"}');
    buffer.writeln('المشروع,${sess.projectName ?? "-"}');
    buffer.writeln('تاريخ الجاهزية CRD,${sess.cargoReadyDate}');
    buffer.writeln('عنوان الاستلام,"${(sess.pickUpAddress ?? "-").replaceAll('"', '""')}"');
    buffer.writeln('الخط الموصى به,"${(sess.recommendedScenarioProvider ?? "-").replaceAll('"', '""')}"');
    buffer.writeln('');
    buffer.writeln('--- سيناريوهات الشحن المقارنة ---');
    buffer.writeln('الخط الملاحي / الناقل,الباخرة,ميناء الشحن,ميناء الوصول,مدة الإبحار (أيام),تاريخ الإبحار,تاريخ الوصول التقديري ETA,تاريخ وصول المخزن المتوقع,التكلفة التقديرية,العملة,مستوى المخاطر,موصى به');
    for (final it in sess.items) {
      buffer.writeln('"${it.providerName.replaceAll('"', '""')}","${it.vesselName.replaceAll('"', '""')}","${it.polName ?? '-'}","${it.podName ?? '-'}","${it.vesselLeadTimeDays}","${it.sailingDate}","${it.estimatedArrivalDate}","${it.expectedWarehouseArrivalDate}","${it.totalQuotationAmount ?? '-'}","${it.quotationCurrency ?? '-'}","${it.riskLevel}","${it.isRecommended ? "نعم" : "لا"}"');
    }

    final filename = 'Phase1_Shipping_Evaluation_${sess.sessionCode}_${DateTime.now().millisecondsSinceEpoch}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'حفظ دراسة سيناريوهات الشحن بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }
}
