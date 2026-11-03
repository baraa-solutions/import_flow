import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

/// Pure localized document type resolver avoiding bilingual stacked strings.
String localizeCargoXDocType(BuildContext context, String? docType) {
  if (docType == null) return '—';
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  if (docType.contains('Commercial Invoice') || docType.contains('فاتورة تجارية')) {
    return isAr ? context.l10n.cargoxDocTypeCommercialInvoice : 'Commercial Invoice';
  }
  if (docType.contains('Packing List') || docType.contains('قائمة التعبئة')) {
    return isAr ? context.l10n.cargoxDocTypePackingList : 'Packing List';
  }
  if (docType.contains('B/L') || docType.contains('بوليصة')) {
    return isAr ? context.l10n.cargoxDocTypeDraftBl : 'Draft Bill of Lading';
  }
  if (docType.contains('Certificate of Origin') ||
      docType.contains('EUR.1') ||
      docType.contains('شهادة المنشأ')) {
    return isAr ? context.l10n.cargoxDocTypeCooEur1 : 'Certificate of Origin / EUR.1';
  }
  if (docType.contains('COA') || docType.contains('Analysis') || docType.contains('مخبري')) {
    return isAr ? context.l10n.cargoxDocTypeCoa : 'Certificate of Analysis';
  }
  return docType;
}
