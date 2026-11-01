import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/logistics_invoice_models.dart';
import '../../providers/logistics_invoices_provider.dart';
import 'invoice_list_card.dart';

class LogisticsInvoicesTab extends ConsumerWidget {
  final bool isDark;
  final void Function(String partnerType) onNewInvoice;
  final void Function(LogisticsInvoiceModel invoice) onEditInvoice;
  final void Function(int partnerId, String partnerName) onPayInvoice;

  const LogisticsInvoicesTab({
    super.key,
    required this.isDark,
    required this.onNewInvoice,
    required this.onEditInvoice,
    required this.onPayInvoice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = context.l10n.isArabic;
    final invoicesAsync = ref.watch(logisticsInvoicesListProvider);
    final partnerType = ref.watch(invoicePartnerTypeFilterProvider);
    final statusFilter = ref.watch(invoiceStatusFilterProvider);

    return Column(
      children: [
        // Compact Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF161E28) : Colors.white,
          child: Row(
            children: [
              // Partner Type Filter
              DropdownButton<String>(
                value: partnerType,
                isDense: true,
                items: [
                  DropdownMenuItem(value: 'all', child: Text(isArabic ? 'كل الشركاء' : 'All Partners')),
                  DropdownMenuItem(value: 'freight', child: Text(isArabic ? 'شركات الشحن' : 'Freight Forwarders')),
                  DropdownMenuItem(value: 'clearance', child: Text(isArabic ? 'مخلصون جمركيون' : 'Customs Brokers')),
                  DropdownMenuItem(value: 'inspection', child: Text(isArabic ? 'جهات الفحص' : 'Inspection Agencies')),
                  DropdownMenuItem(value: 'insurance', child: Text(isArabic ? 'التأمين البحري' : 'Marine Insurance')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(invoicePartnerTypeFilterProvider.notifier).state = val;
                  }
                },
              ),
              const SizedBox(width: 12),
              // Status Filter
              DropdownButton<String>(
                value: statusFilter,
                isDense: true,
                items: [
                  DropdownMenuItem(value: 'all', child: Text(isArabic ? 'كل الحالات' : 'All Statuses')),
                  DropdownMenuItem(value: 'draft', child: Text(isArabic ? 'مسودة' : 'Draft')),
                  DropdownMenuItem(value: 'submitted', child: Text(isArabic ? 'مرفوعة' : 'Submitted')),
                  DropdownMenuItem(value: 'approved', child: Text(isArabic ? 'معتمدة' : 'Approved')),
                  DropdownMenuItem(value: 'partially_paid', child: Text(isArabic ? 'سداد جزئي' : 'Partially Paid')),
                  DropdownMenuItem(value: 'fully_paid', child: Text(isArabic ? 'مسددة بالكامل' : 'Fully Paid')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(invoiceStatusFilterProvider.notifier).state = val;
                  }
                },
              ),
              const Spacer(),
              // New Invoice Menu
              PopupMenuButton<String>(
                tooltip: isArabic ? 'تسجيل فاتورة جديدة' : 'Create New Invoice',
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'freight', child: Text(isArabic ? '🚢 فاتورة شركة شحن جديدة' : '🚢 New Freight Forwarder Invoice')),
                  PopupMenuItem(value: 'clearance', child: Text(isArabic ? '📋 فاتورة مخلص جمركي جديدة' : '📋 New Customs Broker Invoice')),
                  PopupMenuItem(value: 'inspection', child: Text(isArabic ? '🔍 فاتورة جهة فحص جديدة' : '🔍 New Inspection Agency Invoice')),
                  PopupMenuItem(value: 'insurance', child: Text(isArabic ? '🛡️ فاتورة تأمين بحري جديدة' : '🛡️ New Marine Insurance Invoice')),
                ],
                onSelected: onNewInvoice,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? '+ فاتورة خدمة جديدة' : '+ New Service Invoice',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Invoices List
        Expanded(
          child: invoicesAsync.when(
            loading: () => const AppLoadingState(),
            error: (err, _) => AppErrorState(
              error: err,
              onRetry: () => ref.invalidate(logisticsInvoicesListProvider),
            ),
            data: (invoices) {
              if (invoices.isEmpty) {
                return AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: isArabic
                      ? 'لا توجد فواتير خدمات مسجلة.'
                      : 'No logistics invoices found.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: invoices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => InvoiceListCard(
                  inv: invoices[i],
                  isDark: isDark,
                  onEdit: () => onEditInvoice(invoices[i]),
                  onPay: onPayInvoice,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
