import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../logistics_invoices/models/logistics_invoice_models.dart';

class ExpensesInvoicesTable extends StatelessWidget {
  final List<LogisticsInvoiceModel> shipmentInvoices;
  final bool isDark;

  const ExpensesInvoicesTable({
    super.key,
    required this.shipmentInvoices,
    required this.isDark,
  });

  Color _getPartnerTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'freight':
        return const Color(0xFF0284C7);
      case 'clearance':
        return const Color(0xFF059669);
      case 'inspection':
        return const Color(0xFFD97706);
      case 'insurance':
        return const Color(0xFF1E3A8A);
      default:
        return AppTheme.cobalt;
    }
  }

  String _getPartnerTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'freight':
        return 'شحن ونولون';
      case 'clearance':
        return 'تخليص جمركي';
      case 'inspection':
        return 'فحص ومعاينة';
      case 'insurance':
        return 'تأمين بحري';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (shipmentInvoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.black12 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'لا توجد فواتير خدمات مسجلة لهذه الشحنة بعد. استخدم الأزرار السريعة أعلاه لإدخال فواتير الشحن أو التخليص أو التأمين.',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.8),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.3),
            4: FlexColumnWidth(1.3),
            5: FlexColumnWidth(1.0),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF25303D) : const Color(0xFFF1F5F9),
              ),
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('رقم الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('مقدم الخدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('صافي المستحق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('المتبقي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
            for (final inv in shipmentInvoices)
              TableRow(
                decoration: BoxDecoration(
                  color: isDark ? Colors.transparent : Colors.white,
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
                ),
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(inv.partnerName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPartnerTypeColor(inv.partnerType).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getPartnerTypeLabel(inv.partnerType),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getPartnerTypeColor(inv.partnerType)),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.all(8), child: Text('${inv.netPayableEgp.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${inv.remainingAmountEgp.toStringAsFixed(2)} EGP',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: inv.remainingAmountEgp > 0 ? Colors.orange.shade800 : Colors.green),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      inv.paymentStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: inv.paymentStatus == 'FULLY_PAID' ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
