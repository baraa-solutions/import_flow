import 'package:flutter/widgets.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_ar.dart';

class CooReviewLocalizer {
  static String getFieldLabel(String fieldKey, String? labelAr, AppLocalizations l10n) {
    switch (fieldKey) {
      case 'exporter_name':
        return l10n.cooExporterNameLabel.replaceAll('*', '').trim();
      case 'exporter_reg_id':
        return l10n.cooExporterRegIdLabel;
      case 'importer_name':
        return l10n.cooImporterNameLabel.replaceAll('*', '').trim();
      case 'country_of_origin':
        return l10n.cooOriginCountryLabel;
      case 'destination_country':
        return l10n.cooDestinationCountryLabel;
      case 'invoice_number':
        return l10n.cooInvoiceNumberLabel;
      case 'certificate_type':
        return l10n.cooCertTypeLabel;
      case 'certificate_number':
        return l10n.cooDraftCertNumberLabel;
      default:
        return (l10n is AppLocalizationsAr && labelAr != null && labelAr.isNotEmpty) ? labelAr : fieldKey;
    }
  }

  static String localizeAlert(BuildContext context, String? alert) {
    if (alert == null || alert.isEmpty) return '';
    if (context.l10n.isArabic) return alert;
    if (alert.contains('الصين') || alert.contains('China')) {
      return context.l10n.cooChinaRecommendationAlert;
    }
    if (alert.contains('الاتحاد الأوروبي') || alert.contains('EUR.1') || alert.contains('EU')) {
      return context.l10n.cooEuRecommendationAlert;
    }
    if (alert.contains('أغادير') || alert.contains('Agadir')) {
      return context.l10n.cooAgadirGaftaRecommendationAlert;
    }
    return alert;
  }

  static String localizeExemption(BuildContext context, String? notes) {
    if (notes == null || notes.isEmpty) return '';
    if (context.l10n.isArabic) return notes;
    if (notes.contains('China') || notes.contains('الصين')) {
      return context.l10n.cooChinaGeneralExemptionNote;
    }
    return notes;
  }

  static String localizeCertType(BuildContext context, String type) {
    if (type == 'Agadir Agreement') {
      return context.l10n.cooCertTypeAgadir;
    }
    if (type == 'GAFTA') {
      return context.l10n.cooCertTypeGafta;
    }
    if (type == 'EUR.1') {
      return context.l10n.cooCertTypeEur1;
    }
    if (type.contains('China')) {
      return context.l10n.cooCertTypeChina;
    }
    return type;
  }
}
