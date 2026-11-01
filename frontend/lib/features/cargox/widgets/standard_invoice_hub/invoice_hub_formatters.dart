import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/cargox_model.dart';

/// Formats a DateTime into a clean readable string `YYYY-MM-DD HH:MM`.
String formatInvoiceHubDateTime(DateTime dt) {
  final str = dt.toIso8601String();
  if (str.length >= 16) {
    return str.substring(0, 16).replaceAll('T', ' ');
  }
  return str;
}

/// Safely extracts error details from Dio exceptions or dynamic errors.
String extractInvoiceHubErrorMessage(dynamic err) {
  if (err is DioException && err.response?.data != null) {
    final data = err.response!.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
  }
  return err.toString();
}

/// Localized status label ensuring pure separation without bilingual stacking.
String resolveInvoiceHubStatusLabel(BuildContext context, String status) {
  final l10n = context.l10n;
  final isAr = Localizations.localeOf(context).languageCode == 'ar';

  switch (status.toUpperCase()) {
    case 'APPROVED':
      return l10n.standardInvoiceStatusApproved;
    case 'MATCH':
      return isAr ? 'مطابق' : 'Match';
    case 'UNDER_REVIEW':
      return l10n.standardInvoiceStatusUnderReview;
    case 'WARNING':
      return isAr ? 'فرق طفيف' : 'Warning';
    case 'CRITICAL_MISMATCH':
      return isAr ? 'فرق حرج' : 'Critical Mismatch';
    case 'REJECTED_NEEDS_MODIFICATION':
      return l10n.standardInvoiceStatusRejected;
    case 'DRAFT':
      return l10n.standardInvoiceStatusDraft;
    case 'SEALED':
      return l10n.customsTrackStatusSealed;
    default:
      return status;
  }
}

/// Assembles the standardized payload for saving or upserting an invoice session.
Map<String, dynamic> buildStandardInvoiceSessionPayload({
  required ImportFileModel file,
  required StandardInvoicePayloadModel? supplierData,
  required StandardInvoiceComparisonResponseModel? comparisonResult,
  required String status,
  required String overrideReason,
  required String notes,
}) {
  return {
    'import_file_id': file.importFileId,
    'import_file_code': file.importFileCode,
    'acid_number': supplierData?.acidNumber ?? file.acidNumber,
    'invoice_number': supplierData?.invoiceNumber ?? 'INV-${file.importFileCode}',
    'invoice_date': supplierData?.invoiceDate,
    'invoice_type': supplierData?.invoiceType ?? 'Commercial Invoice',
    'purchase_order_number': supplierData?.purchaseOrderNumber,
    'exporter_name': supplierData?.sellerName ?? file.supplierName,
    'exporter_tax_id': supplierData?.sellerTaxId,
    'exporter_country_code': supplierData?.sellerCountryCode,
    'importer_name': supplierData?.buyerName ?? file.companyName,
    'importer_tax_id': supplierData?.buyerTaxId,
    'currency_code': supplierData?.currencyCode ?? 'EUR',
    'incoterm': supplierData?.incoterm ?? file.incotermCode,
    'pol_code': supplierData?.originPort,
    'pod_code': supplierData?.destinationPort,
    'gross_weight_kg': supplierData?.grossWeight ?? 0.0,
    'net_weight_kg': supplierData?.netWeight ?? 0.0,
    'weight_unit': supplierData?.weightUnit ?? 'KGM',
    'subtotal_amount': supplierData?.subtotal ?? 0.0,
    'freight_cost': supplierData?.freightCost ?? 0.0,
    'insurance_cost': supplierData?.insuranceCost ?? 0.0,
    'other_costs': supplierData?.otherCosts ?? 0.0,
    'total_amount': supplierData?.totalAmount ?? 0.0,
    'line_items_count': supplierData?.items.length ?? 0,
    'has_discrepancies': comparisonResult?.hasDiscrepancies ?? false,
    'has_critical_mismatch': comparisonResult?.hasCriticalMismatch ?? false,
    'discrepancy_override_reason': overrideReason.trim(),
    'status': status,
    'notes': notes.trim(),
  };
}
