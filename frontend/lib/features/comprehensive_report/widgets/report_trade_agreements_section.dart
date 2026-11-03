import 'package:flutter/material.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/widgets/hs_code_compliance_insight_card.dart';
import '../../import_files/models/import_file_model.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import 'report_card_container.dart';

/// Trade agreements, HS code compliance, and preferential origin section.
class ReportTradeAgreementsSection extends StatelessWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> allPOs;
  final List<CustomsTariffModel> registeredTariffs;

  const ReportTradeAgreementsSection({
    super.key,
    required this.file,
    this.allPOs = const [],
    this.registeredTariffs = const [],
  });

  @override
  Widget build(BuildContext context) {
    final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
    final allItems = <({
      String description,
      String hsCode,
      double quantity,
      String uom,
      double unitPrice,
      String currency,
      String poNumber,
    })>[];

    for (final po in linkedPOs) {
      if (po.items.isNotEmpty) {
        for (final item in po.items) {
          String resolvedHs = item.hsCode?.trim() ?? '';
          if (resolvedHs.isEmpty && po.packingListItems.isNotEmpty) {
            for (final pl in po.packingListItems) {
              if (pl.hsCode.trim().isNotEmpty) {
                resolvedHs = pl.hsCode.trim();
                break;
              }
            }
          }
          if (resolvedHs.isEmpty && file.hsCode != null) {
            resolvedHs = file.hsCode!.trim();
          }
          allItems.add((
            description: item.itemDescription.trim().isNotEmpty
                ? item.itemDescription.trim()
                : 'منتج غير محدد',
            hsCode: resolvedHs,
            quantity: item.quantity,
            uom: item.unitOfMeasure,
            unitPrice: item.unitPrice,
            currency: po.currencyCode ?? 'USD',
            poNumber: po.poNumber,
          ));
        }
      } else if (po.packingListItems.isNotEmpty) {
        for (final pl in po.packingListItems) {
          allItems.add((
            description: pl.mainDescription?.trim().isNotEmpty == true
                ? pl.mainDescription!.trim()
                : (pl.description?.trim().isNotEmpty == true
                    ? pl.description!.trim()
                    : 'منتج غير محدد'),
            hsCode: pl.hsCode.trim(),
            quantity: pl.qtyPcs > 0 ? pl.qtyPcs : pl.qtyPkg,
            uom: pl.packageType.trim().isNotEmpty ? pl.packageType.trim() : 'CTN',
            unitPrice: 0.0,
            currency: po.currencyCode ?? 'USD',
            poNumber: po.poNumber,
          ));
        }
      }
    }

    if (allItems.isEmpty && file.packingListsData.isNotEmpty) {
      for (final pl in file.packingListsData) {
        allItems.add((
          description: file.productCategory ?? 'قائمة تعبئة (${pl.plNo})',
          hsCode: file.hsCode ?? '',
          quantity: pl.totalPackages.toDouble(),
          uom: 'PKG',
          unitPrice: 0.0,
          currency: 'USD',
          poNumber: file.poNumber ?? file.importFileCode,
        ));
      }
    }

    final distinctHsCodes = <String>{};
    for (final item in allItems) {
      if (item.hsCode.isNotEmpty) distinctHsCodes.add(item.hsCode);
    }
    if (distinctHsCodes.isEmpty && file.hsCode != null && file.hsCode!.trim().isNotEmpty) {
      distinctHsCodes.add(file.hsCode!.trim());
    }

    final hsCodes = distinctHsCodes.toList()..sort();
    if (hsCodes.isEmpty) return const SizedBox.shrink();

    return ReportCardContainer(
      title: 'شروط الاستيراد الرقابية والاتفاقيات التفضيلية (Compliance & Trade Agreements)',
      icon: Icons.verified_user_outlined,
      iconColor: const Color(0xFF0D9488),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...hsCodes.map((hs) {
            final cleanHs = hs.trim();
            final tariff = registeredTariffs.where(
              (t) => t.hsCode == cleanHs || t.hsCode.replaceAll('.', '') == cleanHs.replaceAll('.', ''),
            ).firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: HsCodeComplianceInsightCard(
                hsCode: hs,
                tariff: tariff,
                countryOfOrigin: linkedPOs.firstOrNull?.countryOfOrigin,
              ),
            );
          }),
        ],
      ),
    );
  }
}
