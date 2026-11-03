import 'package:flutter/material.dart';
import '../../models/logistics_invoice_models.dart';

class InvoiceFormLinesTable extends StatelessWidget {
  final List<LogisticsInvoiceLineModel> lines;
  final String currency;
  final double exchangeRate;
  final bool isDark;
  final bool isArabic;
  final void Function(int index, LogisticsInvoiceLineModel updatedLine) onLineChanged;
  final void Function(int index) onRemoveLine;

  const InvoiceFormLinesTable({
    super.key,
    required this.lines,
    required this.currency,
    required this.exchangeRate,
    required this.isDark,
    required this.isArabic,
    required this.onLineChanged,
    required this.onRemoveLine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3.5), // Description
          1: FlexColumnWidth(1.2), // Group / Category
          2: FlexColumnWidth(1.0), // Qty
          3: FlexColumnWidth(1.4), // Unit Price FX
          4: FlexColumnWidth(1.4), // Amount FX
          5: FlexColumnWidth(1.5), // Amount EGP
          6: FixedColumnWidth(44), // Action
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2630) : const Color(0xFFEDF2F7),
            ),
            children: [
              Padding(padding: const EdgeInsets.all(8), child: Text(isArabic ? 'الوصف' : 'Description', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: const EdgeInsets.all(8), child: Text(isArabic ? 'المجموعة' : 'Group', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: const EdgeInsets.all(8), child: Text(isArabic ? 'الكمية' : 'Qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: const EdgeInsets.all(8), child: Text(isArabic ? 'سعر الوحدة' : 'Unit Price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: const EdgeInsets.all(8), child: Text(isArabic ? 'الإجمالي (أجنبي)' : 'Total FX', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: const EdgeInsets.all(8), child: Text(isArabic ? 'الإجمالي (ج.م)' : 'Total EGP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          for (int i = 0; i < lines.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i % 2 == 1
                    ? (isDark ? const Color(0xFF141A22) : const Color(0xFFF8FAFC))
                    : Colors.transparent,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: TextFormField(
                    key: ValueKey('desc_${lines[i].lineId}_$i'),
                    initialValue: lines[i].lineDescription,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: (v) {
                      onLineChanged(
                        i,
                        LogisticsInvoiceLineModel(
                          lineId: lines[i].lineId,
                          expenseCode: lines[i].expenseCode,
                          lineDescription: v,
                          lineGroup: lines[i].lineGroup,
                          quantity: lines[i].quantity,
                          unitPriceFx: lines[i].unitPriceFx,
                          currency: currency,
                          exchangeRate: exchangeRate,
                          taxType: lines[i].taxType,
                          isFromQuotation: lines[i].isFromQuotation,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    lines[i].lineGroup ?? 'Other',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: TextFormField(
                    key: ValueKey('qty_${lines[i].lineId}_$i'),
                    initialValue: lines[i].quantity.toString(),
                    style: const TextStyle(fontSize: 12),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: (v) {
                      final q = double.tryParse(v);
                      if (q != null) {
                        onLineChanged(
                          i,
                          LogisticsInvoiceLineModel(
                            lineId: lines[i].lineId,
                            expenseCode: lines[i].expenseCode,
                            lineDescription: lines[i].lineDescription,
                            lineGroup: lines[i].lineGroup,
                            quantity: q,
                            unitPriceFx: lines[i].unitPriceFx,
                            currency: currency,
                            exchangeRate: exchangeRate,
                            taxType: lines[i].taxType,
                            isFromQuotation: lines[i].isFromQuotation,
                          ),
                        );
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: TextFormField(
                    key: ValueKey('price_${lines[i].lineId}_$i'),
                    initialValue: lines[i].unitPriceFx.toString(),
                    style: const TextStyle(fontSize: 12),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: (v) {
                      final p = double.tryParse(v);
                      if (p != null) {
                        onLineChanged(
                          i,
                          LogisticsInvoiceLineModel(
                            lineId: lines[i].lineId,
                            expenseCode: lines[i].expenseCode,
                            lineDescription: lines[i].lineDescription,
                            lineGroup: lines[i].lineGroup,
                            quantity: lines[i].quantity,
                            unitPriceFx: p,
                            currency: currency,
                            exchangeRate: exchangeRate,
                            taxType: lines[i].taxType,
                            isFromQuotation: lines[i].isFromQuotation,
                          ),
                        );
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    '${lines[i].amountFx.toStringAsFixed(2)} $currency',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    '${lines[i].amountEgp.toStringAsFixed(2)} EGP',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  onPressed: () => onRemoveLine(i),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
