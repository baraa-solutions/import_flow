import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';

/// Central localization helper for PO & Packing Reconciliation.
/// Strictly enforces Pure View Separation & Anti-Stacking rules (no bilingual parentheses).
class PoReconciliationLocalizer {
  static String getLocalizedCheckField(BuildContext context, String fieldName, [String? fieldNameAr]) {
    final l = context.l10n;
    if (l.isArabic && fieldNameAr != null && fieldNameAr.isNotEmpty) {
      return fieldNameAr;
    }
    switch (fieldName) {
      case 'invoice_number':
        return l.poRecCheckFieldInvoiceNumber;
      case 'acid_number':
        return l.poRecCheckFieldAcidNumber;
      case 'total_amount':
        return l.poRecCheckFieldTotalAmount;
      case 'total_packages':
        return l.poRecCheckFieldTotalPackages;
      case 'gross_weight':
        return l.poRecCheckFieldGrossWeight;
      case 'supplier_name':
        return l.poRecCheckFieldSupplierName;
      case 'importer_name':
        return l.poRecCheckFieldImporterName;
      case 'hs_code':
        return l.poRecCheckFieldHsCode;
      case 'tax_id':
        return l.poRecCheckFieldTaxId;
      default:
        return fieldNameAr ?? fieldName;
    }
  }

  static String getLocalizedCheckMessage(BuildContext context, String fieldName, String status, String? rawMessage) {
    final l = context.l10n;
    if (rawMessage != null && rawMessage.isNotEmpty) {
      return rawMessage;
    }
    if (status == 'MATCH') {
      switch (fieldName) {
        case 'invoice_number':
          return l.poRecCheckMsgInvoiceMatched;
        case 'acid_number':
          return l.poRecCheckMsgAcidMatched;
        case 'total_amount':
          return l.poRecCheckMsgTotalAmountMatched;
        default:
          return l.poRecOk;
      }
    }
    return rawMessage ?? '';
  }

  static String getLocalizedSessionStatus(BuildContext context, String status) {
    final l = context.l10n;
    switch (status) {
      case 'FULLY_MATCHED':
        return l.poRecMatchStatusMatched;
      case 'ACCEPTED_WITH_WARNINGS':
        return l.poRecMatchStatusWarning;
      case 'CRITICAL_DISCREPANCY':
        return l.poRecMatchStatusCritical;
      default:
        return status;
    }
  }

  static String formatSessionDate(BuildContext context, String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return context.l10n.idocANotSpecified;
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$y/$m/$d $h:$min';
    } catch (_) {
      return dateStr;
    }
  }
}
