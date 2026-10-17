import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../logistics_invoices/providers/logistics_invoices_provider.dart';
import '../../logistics_invoices/screens/logistics_invoices_screen.dart';
import '../../logistics_invoices/widgets/advance_payment_dialog.dart';
import '../../logistics_invoices/widgets/insurance_policy_dialog.dart';
import '../../logistics_invoices/widgets/invoice_form_dialog.dart';
import '../models/import_file_model.dart';

class LogisticsShipmentExpensesSummaryCard extends ConsumerWidget {
  final ImportFileModel file;

  const LogisticsShipmentExpensesSummaryCard({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);

    final invoicesAsync = ref.watch(logisticsInvoicesListProvider);
    final advancesAsync = ref.watch(clearanceAdvancesListProvider);

    final allInvoices = invoicesAsync.valueOrNull ?? [];
    final shipmentInvoices = allInvoices.where((inv) => inv.shipmentId == file.importFileId).toList();

    final allAdvances = advancesAsync.valueOrNull ?? [];
    final shipmentAdvances = allAdvances.where((adv) => adv.shipmentId == file.importFileId).toList();

    double totalInvoicedEgp = 0.0;
    double totalPaidEgp = 0.0;
    double balanceDueEgp = 0.0;

    for (final inv in shipmentInvoices) {
      totalInvoicedEgp += inv.netPayableEgp;
      totalPaidEgp += inv.paidAmountEgp;
      balanceDueEgp += inv.remainingAmountEgp;
    }

    double totalAdvanceRemainingEgp = 0.0;
    for (final adv in shipmentAdvances) {
      totalAdvanceRemainingEgp += adv.remainingAmountEgp;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2630) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.cobalt.withValues(alpha: 0.3) : AppTheme.cobalt.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'فواتير ومصروفات الشركاء اللوجستيين (Logistics Invoices & Expenses)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'شحن بحري · تخليص جمركي وعهدة · فحص ومعاينة · تأمين بحري (مرتبطة بـ ${file.displayName})',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cobalt,
                  side: const BorderSide(color: AppTheme.cobalt),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('فتح المركز اللوجستي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => LogisticsInvoicesScreen(
                        initialShipmentId: file.importFileId,
                        initialBlNumber: null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Metric Summary Pills
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'إجمالي فواتير الخدمات',
                  '${totalInvoicedEgp.toStringAsFixed(2)} EGP',
                  Icons.receipt_long,
                  AppTheme.cobalt,
                  isDark,
                  subtitle: '${shipmentInvoices.length} فواتير مسجلة',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBox(
                  'المسدد للموردين',
                  '${totalPaidEgp.toStringAsFixed(2)} EGP',
                  Icons.check_circle_outline,
                  AppTheme.emerald,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBox(
                  'المتبقي للاستحقاق',
                  '${balanceDueEgp.toStringAsFixed(2)} EGP',
                  Icons.pending_actions,
                  balanceDueEgp > 0 ? Colors.orange.shade800 : Colors.grey,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricBox(
                  'رصيد عهدة المخلص',
                  '${totalAdvanceRemainingEgp.toStringAsFixed(2)} EGP',
                  Icons.account_balance_wallet,
                  const Color(0xFF0F766E),
                  isDark,
                  subtitle: '${shipmentAdvances.length} عهد منصرفة',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Quick Action Buttons Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                context: context,
                label: '+ فاتورة شحن ونولون',
                icon: Icons.directions_boat,
                color: const Color(0xFF0284C7),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => InvoiceFormDialog(
                      defaultPartnerType: 'freight',
                      initialShipmentId: file.importFileId,
                      initialBlNumber: null,
                    ),
                  );
                },
              ),
              _buildActionButton(
                context: context,
                label: '+ فاتورة تخليص جمركي',
                icon: Icons.assignment,
                color: const Color(0xFF059669),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => InvoiceFormDialog(
                      defaultPartnerType: 'clearance',
                      initialShipmentId: file.importFileId,
                      initialBlNumber: null,
                    ),
                  );
                },
              ),
              _buildActionButton(
                context: context,
                label: '+ فاتورة فحص ومعاينة',
                icon: Icons.fact_check,
                color: const Color(0xFFD97706),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => InvoiceFormDialog(
                      defaultPartnerType: 'inspection',
                      initialShipmentId: file.importFileId,
                      initialBlNumber: null,
                    ),
                  );
                },
              ),
              _buildActionButton(
                context: context,
                label: '💼 صرف عهدة مخلص',
                icon: Icons.payment,
                color: const Color(0xFF4F46E5),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AdvancePaymentDialog(
                      defaultShipmentId: file.importFileId,
                      defaultBlNumber: null,
                    ),
                  );
                },
              ),
              _buildActionButton(
                context: context,
                label: '🛡️ إصدار وثيقة تأمين',
                icon: Icons.security,
                color: const Color(0xFF1E3A8A),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => InsurancePolicyDialog(
                      defaultShipmentId: file.importFileId,
                      defaultBlNumber: null,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Invoices List Preview / Mini Table
          if (shipmentInvoices.isEmpty) ...[
            Container(
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
                  Text(
                    'لا توجد فواتير خدمات مسجلة لهذه الشحنة بعد. استخدم الأزرار السريعة أعلاه لإدخال فواتير الشحن أو التخليص أو التأمين.',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color color, bool isDark, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : color),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      onPressed: onTap,
    );
  }

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
}
