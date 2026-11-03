import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/smart_reference_card_model.dart';

class SmartReferenceCardExportHelper {
  static void copyCardData(BuildContext context, SmartReferenceCardModel card, {required bool isArabic}) {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln('=== ${l10n.smartReferenceCardTitle} ===');
    buffer.writeln('${isArabic ? "كود الملف" : "File Code"}: ${card.importFileCode}');
    if (card.customFileNumber != null && card.customFileNumber!.isNotEmpty) {
      buffer.writeln('${isArabic ? "الرقم المخصص" : "Custom File No"}: ${card.customFileNumber}');
    }
    buffer.writeln('\n[${l10n.refCardProductSection}]');
    buffer.writeln('${isArabic ? "بند التعريفة" : "HS Code"}: ${card.hsCode}');
    buffer.writeln('${isArabic ? "تصنيف الصنف" : "Category"}: ${card.productCategory}');
    buffer.writeln('${isArabic ? "إجمالي الحجم" : "Total Volume"}: ${card.totalCbm} ${isArabic ? "متر مكعب" : "m³"}');
    buffer.writeln('${isArabic ? "الوزن الإجمالي" : "Gross Weight"}: ${card.totalGrossWeightKg} ${isArabic ? "كجم" : "kg"}');
    buffer.writeln('${isArabic ? "عدد الطرود" : "Packages Count"}: ${card.packagesCount} ${isArabic ? "طرد" : "pkgs"}');

    buffer.writeln('\n[${l10n.refCardRouteSection}]');
    buffer.writeln('${isArabic ? "ميناء الشحن" : "POL"}: ${card.originPort}');
    buffer.writeln('${isArabic ? "ميناء الوصول" : "POD"}: ${card.destinationPort}');
    buffer.writeln('${isArabic ? "الناقل والخط الملاحي" : "Carrier"}: ${card.carrier}');

    buffer.writeln('\n[${l10n.refCardDatesSection}]');
    buffer.writeln('${isArabic ? "فترة سماح الحاويات" : "Free Days"}: ${card.freeDays} ${isArabic ? "يوم" : "days"}');
    buffer.writeln('${isArabic ? "حالة السماح" : "Free Time Status"}: ${card.freeTimeStatus}');

    buffer.writeln('\n[${l10n.refCardDocsSection}]');
    buffer.writeln('${isArabic ? "حالة الجاهزية" : "Docs Status"}: ${card.isDocsComplete ? (isArabic ? "مكتملة" : "Complete") : (isArabic ? "غير مكتملة" : "Incomplete")}');
    buffer.writeln('${isArabic ? "شهادة المنشأ" : "COO"}: ${card.hasCooAttached ? (isArabic ? "مرفقة ومصدقة" : "Attached") : (isArabic ? "غير مرفقة" : "Missing")}');
    if (card.pendingDocuments.isNotEmpty) {
      buffer.writeln('${isArabic ? "المستندات المعلقة" : "Pending Docs"}: ${card.pendingDocuments.join(", ")}');
    }

    buffer.writeln('\n[${l10n.refCardCostSection}]');
    buffer.writeln('${isArabic ? "المقدر" : "Estimated"}: ${card.estimatedCost} ${card.currency}');
    buffer.writeln('${isArabic ? "الفعلي" : "Actual"}: ${card.actualCost} ${card.currency}');
    buffer.writeln('${isArabic ? "الفارق" : "Variance"}: ${card.varianceAmount} (${card.variancePercentage}%)');

    CopyHelper.copy(context, buffer.toString(), customMessage: l10n.referenceCardCopiedSuccess);
  }
}
