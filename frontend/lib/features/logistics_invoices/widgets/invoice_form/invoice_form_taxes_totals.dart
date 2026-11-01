import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class InvoiceFormTaxesTotals extends StatelessWidget {
  final bool isDark;
  final bool isArabic;
  final bool vatIncluded;
  final ValueChanged<bool> onVatChanged;
  final bool whtDeducted;
  final ValueChanged<bool> onWhtChanged;
  final double subtotalFx;
  final double subtotalEgp;
  final double vatAmount;
  final double whtAmount;
  final double netPayableEgp;
  final String currency;

  const InvoiceFormTaxesTotals({
    super.key,
    required this.isDark,
    required this.isArabic,
    required this.vatIncluded,
    required this.onVatChanged,
    required this.whtDeducted,
    required this.onWhtChanged,
    required this.subtotalFx,
    required this.subtotalEgp,
    required this.vatAmount,
    required this.whtAmount,
    required this.netPayableEgp,
    required this.currency,
  });

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF1A222D) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tax Toggles
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: Text(
                      isArabic ? 'إضافة 14% ضريبة القيمة المضافة' : 'Add 14% VAT',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: vatIncluded,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => onVatChanged(v ?? false),
                  ),
                  CheckboxListTile(
                    title: Text(
                      isArabic ? 'خصم أرباح تجارية وصناعية (نموذج 41)' : 'Deduct WHT Form 41',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: whtDeducted,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => onWhtChanged(v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Totals summary
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _summaryRow(
                    isArabic ? 'المجموع الفرعي (عملة أجنبية):' : 'Subtotal (FX):',
                    '${subtotalFx.toStringAsFixed(2)} $currency',
                  ),
                  _summaryRow(
                    isArabic ? 'المجموع الفرعي (بالجنيه):' : 'Subtotal (EGP):',
                    '${subtotalEgp.toStringAsFixed(2)} EGP',
                  ),
                  if (vatIncluded)
                    _summaryRow(
                      isArabic ? 'قيمة ضريبة القيمة المضافة (+):' : 'VAT Amount (+):',
                      '${vatAmount.toStringAsFixed(2)} EGP',
                      color: Colors.blue,
                    ),
                  if (whtDeducted)
                    _summaryRow(
                      isArabic ? 'خصم ضريبة المنبع (-):' : 'WHT Deducted (-):',
                      '${whtAmount.toStringAsFixed(2)} EGP',
                      color: Colors.orange,
                    ),
                  const Divider(height: 14),
                  _summaryRow(
                    isArabic ? 'صافي المبلغ المستحق (بالجنيه):' : 'Net Payable (EGP):',
                    '${netPayableEgp.toStringAsFixed(2)} EGP',
                    isBold: true,
                    color: AppTheme.emerald,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
