import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

import '../../customs_tariff/models/customs_tariff_model.dart';
import '../models/purchase_order_model.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class POReconciliationItem {
  final String hsCode;
  final double invoiceQty;
  final double packingQty;
  final double difference; // packingQty - invoiceQty
  final bool isMatched;
  final bool isMissingInPacking;
  final bool isMissingInInvoice;

  POReconciliationItem({
    required this.hsCode,
    required this.invoiceQty,
    required this.packingQty,
    required this.difference,
    required this.isMatched,
    this.isMissingInPacking = false,
    this.isMissingInInvoice = false,
  });
}

class POReconciliationReport {
  final bool hasDiscrepancy;
  final double totalInvoiceQty;
  final double totalPackingQty;
  final double totalDifference;
  final List<POReconciliationItem> items;
  final List<String> discrepancySummaryList;
  final List<String> discrepancySummaryListEn;

  POReconciliationReport({
    required this.hasDiscrepancy,
    required this.totalInvoiceQty,
    required this.totalPackingQty,
    required this.totalDifference,
    required this.items,
    required this.discrepancySummaryList,
    this.discrepancySummaryListEn = const [],
  });
}

POReconciliationReport evaluatePOReconciliation({
  required List<POLineItemModel> invoiceItems,
  required List<PackingListItemModel> packingItems,
  required List<CustomsTariffModel> tariffs,
}) {
  if (packingItems.isEmpty) {
    return POReconciliationReport(
      hasDiscrepancy: false,
      totalInvoiceQty: invoiceItems.fold(0.0, (s, i) => s + i.quantity),
      totalPackingQty: 0.0,
      totalDifference: 0.0,
      items: [],
      discrepancySummaryList: [],
      discrepancySummaryListEn: [],
    );
  }

  final Map<String, double> invoiceHsMap = {};
  double totalInv = 0.0;
  for (final item in invoiceItems) {
    totalInv += item.quantity;
    String hs = 'UNASSIGNED';
    if (item.tariffId != null) {
      final match = tariffs.cast<CustomsTariffModel?>().firstWhere(
        (t) => t?.tariffId == item.tariffId,
        orElse: () => null,
      );
      if (match != null && match.hsCode.isNotEmpty) {
        hs = match.hsCode;
      }
    } else if (item.hsCode != null && item.hsCode!.isNotEmpty) {
      hs = item.hsCode!;
    }
    invoiceHsMap[hs] = (invoiceHsMap[hs] ?? 0.0) + item.quantity;
  }

  final Map<String, double> packingHsMap = {};
  double totalPkg = 0.0;
  for (final p in packingItems) {
    totalPkg += p.qtyPcs;
    final hs = p.hsCode.isNotEmpty ? p.hsCode : 'UNASSIGNED';
    packingHsMap[hs] = (packingHsMap[hs] ?? 0.0) + p.qtyPcs;
  }

  final Set<String> allHs = {...invoiceHsMap.keys, ...packingHsMap.keys};
  final List<POReconciliationItem> items = [];
  final List<String> warnings = [];
  final List<String> warningsEn = [];
  bool hasDiscrepancy = false;

  for (final hs in allHs) {
    final invQty = invoiceHsMap[hs] ?? 0.0;
    final pkgQty = packingHsMap[hs] ?? 0.0;
    final diff = pkgQty - invQty;
    final matched = (diff.abs() < 0.001);

    final isMissingInPkg = (invQty > 0 && pkgQty == 0);
    final isMissingInInv = (pkgQty > 0 && invQty == 0);

    if (isMissingInPkg) {
      hasDiscrepancy = true;
      warnings.add('البند الجمركي $hs موجود بالفاتورة (كمية: $invQty) وغير موجود ببيان التعبئة');
      warningsEn.add('HS Code $hs is present in invoice (Qty: $invQty) but missing in packing list');
    } else if (isMissingInInv) {
      hasDiscrepancy = true;
      warnings.add('البند الجمركي $hs موجود ببيان التعبئة (كمية: $pkgQty) وغير موجود بالفاتورة');
      warningsEn.add('HS Code $hs is present in packing list (Qty: $pkgQty) but missing in invoice');
    } else if (!matched) {
      hasDiscrepancy = true;
      warnings.add('البند الجمركي $hs: كمية الفاتورة ($invQty) تختلف عن كمية الباكينج ($pkgQty) بفارق ($diff)');
      warningsEn.add('HS Code $hs: Invoice Qty ($invQty) differs from Packing Qty ($pkgQty) by ($diff)');
    }

    items.add(
      POReconciliationItem(
        hsCode: hs,
        invoiceQty: invQty,
        packingQty: pkgQty,
        difference: diff,
        isMatched: matched,
        isMissingInPacking: isMissingInPkg,
        isMissingInInvoice: isMissingInInv,
      ),
    );
  }

  final totalDiff = totalPkg - totalInv;
  if (totalDiff.abs() > 0.001) {
    hasDiscrepancy = true;
    warnings.add('إجمالي عدد القطع: الفاتورة ($totalInv) والباكينج ($totalPkg) بفارق ($totalDiff)');
    warningsEn.add('Total PCS: Invoice ($totalInv) vs Packing ($totalPkg) with difference ($totalDiff)');
  }

  return POReconciliationReport(
    hasDiscrepancy: hasDiscrepancy,
    totalInvoiceQty: totalInv,
    totalPackingQty: totalPkg,
    totalDifference: totalDiff,
    items: items,
    discrepancySummaryList: warnings,
    discrepancySummaryListEn: warningsEn,
  );
}

class POReconciliationWarningDialog extends StatefulWidget {
  final POReconciliationReport report;

  const POReconciliationWarningDialog({super.key, required this.report});

  @override
  State<POReconciliationWarningDialog> createState() => _POReconciliationWarningDialogState();
}

class _POReconciliationWarningDialogState extends State<POReconciliationWarningDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final report = widget.report;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : null,
        titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.amber.shade800,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.discrepancyWarningTitle,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 750,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Text('${l.poLineItemsTab} (${l.quantityMetric})', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${report.totalInvoiceQty.toStringAsFixed(1)} PCS', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF332211) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? Colors.orange.shade800 : Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          Text('${l.reviewPackingListTab} (${l.quantityMetric})', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${report.totalPackingQty.toStringAsFixed(1)} PCS', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (report.totalDifference != 0 ? const Color(0xFF3B151E) : const Color(0xFF14301D))
                            : (report.totalDifference != 0 ? Colors.red.shade50 : Colors.green.shade50),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? (report.totalDifference != 0 ? Colors.red.shade800 : Colors.green.shade800)
                              : (report.totalDifference != 0 ? Colors.red.shade300 : Colors.green.shade300),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(l.poRecDiff, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${report.totalDifference > 0 ? "+" : ""}${report.totalDifference.toStringAsFixed(1)} PCS',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: report.totalDifference != 0 ? (isDark ? Colors.redAccent : Colors.red.shade700) : (isDark ? Colors.greenAccent : Colors.green.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                l.summaryByHsCodeReport,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
              const SizedBox(height: 8),

              Table(
                border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(2.0),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.hsCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.poLineItemsTab, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.reviewPackingListTab, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.poRecDiff, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                    ],
                  ),
                  ...report.items.map((item) {
                    Color rowBg = isDark ? AppTheme.darkCardBackground : Colors.white;
                    Color statusColor = Colors.green;
                    String statusText = l.poRecOk;

                    if (item.isMissingInPacking) {
                      rowBg = isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50.withOpacity(0.5);
                      statusColor = isDark ? Colors.redAccent : Colors.red.shade700;
                      statusText = l.poRecMissingInPacking;
                    } else if (item.isMissingInInvoice) {
                      rowBg = isDark ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50.withOpacity(0.5);
                      statusColor = isDark ? Colors.amberAccent : Colors.amber.shade900;
                      statusText = l.poRecMissingInInvoice;
                    } else if (!item.isMatched) {
                      rowBg = isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50.withOpacity(0.5);
                      statusColor = isDark ? Colors.orangeAccent : Colors.deepOrange;
                      statusText = l.poRecQtyDiff;
                    }

                    final displayHs = item.hsCode == 'UNASSIGNED' ? l.poRecUnassignedHsCode : item.hsCode;

                    return TableRow(
                      decoration: BoxDecoration(color: rowBg),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            displayHs,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('${item.invoiceQty}', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('${item.packingQty}', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${item.difference > 0 ? "+" : ""}${item.difference}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: item.difference != 0 ? (isDark ? Colors.redAccent : Colors.red.shade700) : (isDark ? Colors.greenAccent : Colors.green),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Mandatory Justification Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.discrepancyJustificationLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '${l.discrepancyJustificationLabel} *',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.shade800, width: 2)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return l.requiredField;
                        }
                        if (val.trim().length < 5) {
                          return l.requiredField;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.arrow_back, size: 16),
          label: Text(l.backToEdit),
          style: OutlinedButton.styleFrom(foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
          onPressed: () => Navigator.pop(context, null),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: Text(l.continueAndSave),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade800,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _reasonCtrl.text.trim());
            }
          },
        ),
      ],
    ),
  );
}
}

