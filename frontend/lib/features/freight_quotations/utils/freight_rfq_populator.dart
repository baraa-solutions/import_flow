import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/freight_quotation_model.dart';
import '../providers/freight_quotations_provider.dart';

class FreightRfqPopulatedData {
  final String title;
  final String shippingMethod;
  final DateTime? crdDate;
  final String polName;
  final String podName;
  final double calcCbm;
  final double calcWeight;
  final bool? isStackable;

  const FreightRfqPopulatedData({
    required this.title,
    required this.shippingMethod,
    this.crdDate,
    required this.polName,
    required this.podName,
    required this.calcCbm,
    required this.calcWeight,
    this.isStackable,
  });
}

class FreightRfqPopulator {
  static FreightRfqPopulatedData? populate({
    required int fileId,
    required List<ImportFileModel> importFilesList,
    required List<PurchaseOrderModel> allPOs,
  }) {
    final file = importFilesList.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) return null;

    final title = '${file.primaryNameWithCode} - ${file.supplierName}';
    String shippingMethod = 'Ocean FCL';
    final sm = file.shipmentMode.trim();
    if (sm == 'Sea FCL' || sm == 'Sea') {
      shippingMethod = 'Ocean FCL';
    } else if (sm == 'Sea LCL') {
      shippingMethod = 'Ocean LCL';
    } else if (sm == 'Air') {
      shippingMethod = 'Air Freight';
    } else if (sm == 'Courier') {
      shippingMethod = 'Courier Express';
    } else if (sm == 'Land') {
      shippingMethod = 'Inland Trucking';
    } else if (sm == 'Multimodal' || sm == 'Multi-Modal') {
      shippingMethod = 'Multi-Modal';
    } else if (sm.isNotEmpty) {
      shippingMethod = sm;
    }

    DateTime? crdDate;
    if (file.cargoReadyDate != null && file.cargoReadyDate!.trim().isNotEmpty) {
      crdDate = DateTime.tryParse(file.cargoReadyDate!.trim());
    }

    final polName = file.portOfLoading?.trim() ?? '';
    final podName = file.portOfDischarge?.trim() ?? '';

    double calcCbm = 0.0;
    double calcWeight = 0.0;
    bool? foundStackable;

    if (file.packingListsData.isNotEmpty) {
      for (final pl in file.packingListsData) {
        calcCbm += pl.cbm;
        calcWeight += pl.grossWeightKg;
        foundStackable = pl.isStackable;
      }
    }
    if (calcCbm == 0 && calcWeight == 0) {
      final filePoIds = file.poIds ?? [];
      for (final po in allPOs) {
        if (filePoIds.contains(po.poId) || po.importFileId == file.importFileId) {
          if (po.packingListItems.isNotEmpty) {
            for (final pl in po.packingListItems) {
              calcCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
              calcWeight += (pl.totalGrossWeightKg > 0
                  ? pl.totalGrossWeightKg
                  : (pl.grossWeightUnitKg * pl.qtyPkg));
            }
          } else {
            calcCbm += po.totalCbm;
            calcWeight += po.totalGrossWeightKg;
          }
        }
      }
    }

    return FreightRfqPopulatedData(
      title: title,
      shippingMethod: shippingMethod,
      crdDate: crdDate,
      polName: polName,
      podName: podName,
      calcCbm: calcCbm,
      calcWeight: calcWeight,
      isStackable: foundStackable,
    );
  }

  static Future<bool> saveRfq({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String shippingMethod,
    required DateTime crdDate,
    required String polName,
    required String podName,
    required int? importFileId,
    required int? poId,
    required int? projectId,
    required double totalCbm,
    required double totalGrossWeightKg,
    required String notes,
    required List<FreightQuotationItemModel> quotations,
    required Future<void> Function() onRetry,
  }) async {
    final payload = {
      'title': title,
      'shipping_method': shippingMethod,
      'crd_date': crdDate.toString().substring(0, 10),
      'pol_name': polName,
      'pod_name': podName,
      'import_file_id': importFileId,
      'po_id': poId,
      'project_id': projectId,
      'total_cbm': totalCbm,
      'total_gross_weight_kg': totalGrossWeightKg,
      'chargeable_weight_kg': totalGrossWeightKg,
      'notes': notes,
      'quotations': quotations.map((q) => q.toJson()).toList(),
    };
    try {
      final created = await ref.read(freightQuotationsProvider.notifier).createRFQ(payload);
      if (context.mounted && created != null) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${isArabic ? "تم حفظ وتثبيت طلب مقارنة أسعار الشحن! كود الطلب:" : "Freight RFQ saved successfully! Code:"} ${created.rfqCode}',
            severity: AppSeverity.success,
            action: SnackBarAction(
              label: isArabic ? 'دراسات النولون' : 'Studies',
              textColor: Colors.white,
              onPressed: () => selectNavigationIndex(ref, 4),
            ),
          ),
        );
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        await showErrorDetailsDialog(
          context,
          title: '❌ تعذر حفظ طلب مقارنة أسعار الشحن',
          error: e,
          onRetry: onRetry,
        );
      }
    }
    return false;
  }
}
