import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../logistics_invoices/providers/logistics_invoices_provider.dart';
import '../../logistics_invoices/screens/logistics_invoices_screen.dart';
import '../models/import_file_model.dart';
import 'expenses/expenses_invoices_table.dart';
import 'expenses/expenses_metric_box.dart';
import 'expenses/expenses_quick_actions.dart';

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
                child: ExpensesMetricBox(
                  label: 'إجمالي فواتير الخدمات',
                  value: '${totalInvoicedEgp.toStringAsFixed(2)} EGP',
                  icon: Icons.receipt_long,
                  color: AppTheme.cobalt,
                  isDark: isDark,
                  subtitle: '${shipmentInvoices.length} فواتير مسجلة',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ExpensesMetricBox(
                  label: 'المسدد للموردين',
                  value: '${totalPaidEgp.toStringAsFixed(2)} EGP',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.emerald,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ExpensesMetricBox(
                  label: 'المتبقي للاستحقاق',
                  value: '${balanceDueEgp.toStringAsFixed(2)} EGP',
                  icon: Icons.pending_actions,
                  color: balanceDueEgp > 0 ? Colors.orange.shade800 : Colors.grey,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ExpensesMetricBox(
                  label: 'رصيد عهدة المخلص',
                  value: '${totalAdvanceRemainingEgp.toStringAsFixed(2)} EGP',
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF0F766E),
                  isDark: isDark,
                  subtitle: '${shipmentAdvances.length} عهد منصرفة',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Quick Action Buttons Row
          ExpensesQuickActions(shipmentId: file.importFileId),

          const SizedBox(height: 12),

          // Invoices List Preview / Mini Table
          ExpensesInvoicesTable(
            shipmentInvoices: shipmentInvoices,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}
