import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';
import '../repositories/logistics_invoices_repository.dart';
import '../widgets/advance_payment_dialog.dart';
import '../widgets/insurance_policy_dialog.dart';
import '../widgets/invoice_form_dialog.dart';
import '../widgets/logistics_payment_dialog.dart';
import '../widgets/three_way_match_badge.dart';

class LogisticsInvoicesScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const LogisticsInvoicesScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<LogisticsInvoicesScreen> createState() => _LogisticsInvoicesScreenState();
}

class _LogisticsInvoicesScreenState extends ConsumerState<LogisticsInvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    Future.microtask(() {
      ref.invalidate(logisticsInvoicesListProvider);
      ref.invalidate(paymentVouchersListProvider);
      ref.invalidate(clearanceAdvancesListProvider);
      ref.invalidate(insurancePoliciesListProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openNewInvoiceDialog([String defaultType = 'freight']) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InvoiceFormDialog(defaultPartnerType: defaultType),
    );
  }

  void _openEditInvoiceDialog(LogisticsInvoiceModel inv) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InvoiceFormDialog(initialInvoice: inv),
    );
  }

  void _openPaymentDialog([int partnerId = 1, String partnerName = 'Logistics Partner']) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LogisticsPaymentDialog(defaultPartnerId: partnerId, defaultPartnerName: partnerName),
    );
  }

  void _openAdvanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AdvancePaymentDialog(),
    );
  }

  void _openInsuranceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const InsurancePolicyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101419) : AppTheme.cloudWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar / Header
            _buildHeader(context, isDark),

            // Tab Bar
            Container(
              color: isDark ? const Color(0xFF1E2630) : Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.cobalt,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.cobalt,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.receipt_long), text: 'Service Invoices (فواتير الخدمات)'),
                  Tab(icon: Icon(Icons.payment), text: 'Payment Vouchers & Knock-off (سندات الصرف والإقفال)'),
                  Tab(icon: Icon(Icons.account_balance_wallet), text: 'Clearance Advances (عهد المخلصين)'),
                  Tab(icon: Icon(Icons.shield), text: 'Marine Insurance Policies (بوالص التأمين البحري)'),
                ],
              ),
            ),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInvoicesTab(context, isDark),
                  _buildPaymentsTab(context, isDark),
                  _buildAdvancesTab(context, isDark),
                  _buildInsuranceTab(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.charcoal,
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppTheme.cobalt, size: 24),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logistics Service Invoices & Payments Hub',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Freight · Customs Broker · Inspection Agency · Marine Insurance · CBE Rates',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            tooltip: 'Live Refresh',
            onPressed: () {
              ref.invalidate(logisticsInvoicesListProvider);
              ref.invalidate(paymentVouchersListProvider);
              ref.invalidate(clearanceAdvancesListProvider);
              ref.invalidate(insurancePoliciesListProvider);
            },
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
        ],
      ),
    );
  }

  // ── Tab 1: Service Invoices ────────────────────────────────────────────────

  Widget _buildInvoicesTab(BuildContext context, bool isDark) {
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
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Partners (الكل)')),
                  DropdownMenuItem(value: 'freight', child: Text('Freight Forwarders (شحن)')),
                  DropdownMenuItem(value: 'clearance', child: Text('Customs Brokers (تخليص)')),
                  DropdownMenuItem(value: 'inspection', child: Text('Inspection Agencies (فحص)')),
                  DropdownMenuItem(value: 'insurance', child: Text('Marine Insurance (تأمين)')),
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
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses (كل الحالات)')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft (مسودة)')),
                  DropdownMenuItem(value: 'submitted', child: Text('Submitted (مرفوعة)')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved (معتمدة)')),
                  DropdownMenuItem(value: 'partially_paid', child: Text('Partially Paid (سداد جزئي)')),
                  DropdownMenuItem(value: 'fully_paid', child: Text('Fully Paid (مسددة بالكامل)')),
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
                tooltip: 'Create New Invoice',
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'freight', child: Text('🚢 New Freight Forwarder Invoice')),
                  const PopupMenuItem(value: 'clearance', child: Text('📋 New Customs Broker Invoice')),
                  const PopupMenuItem(value: 'inspection', child: Text('🔍 New Inspection Agency Invoice')),
                  const PopupMenuItem(value: 'insurance', child: Text('🛡️ New Marine Insurance Invoice')),
                ],
                onSelected: (val) => _openNewInvoiceDialog(val),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('+ New Service Invoice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading invoices: $err', style: const TextStyle(color: Colors.red))),
            data: (invoices) {
              if (invoices.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No logistics invoices found.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: invoices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _buildInvoiceCard(ctx, invoices[i], isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(BuildContext context, LogisticsInvoiceModel inv, bool isDark) {
    Color partnerColor;
    IconData partnerIcon;

    switch (inv.partnerType) {
      case 'freight':
        partnerColor = AppTheme.cobalt;
        partnerIcon = Icons.directions_boat;
        break;
      case 'clearance':
        partnerColor = AppTheme.orange;
        partnerIcon = Icons.assignment;
        break;
      case 'insurance':
        partnerColor = Colors.purple;
        partnerIcon = Icons.shield;
        break;
      default:
        partnerColor = AppTheme.emerald;
        partnerIcon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B232D) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: partnerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(partnerIcon, color: partnerColor, size: 22),
          ),
          const SizedBox(width: 12),

          // Code and Partner Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      inv.invoiceCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: partnerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        inv.partnerType.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: partnerColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${inv.partnerName} · Inv #${inv.invoiceNumber}',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                Text(
                  'B/L: ${inv.blNumber ?? "N/A"} · Containers: ${inv.containers.length} · Shipment ID: ${inv.shipmentId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 3-Way Match Badge
          ThreeWayMatchBadge(invoiceId: inv.invoiceId),
          const SizedBox(width: 16),

          // Financial Amounts
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${inv.netPayableEgp.toStringAsFixed(2)} EGP',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${inv.totalAmountFx.toStringAsFixed(2)} ${inv.currency} @ ${inv.exchangeRate.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  'Remaining: ${inv.remainingAmountEgp.toStringAsFixed(2)} EGP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: inv.remainingAmountEgp > 0 ? AppTheme.crimson : AppTheme.emerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Status Badges & Quick Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatusPill(inv.status),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Invoice',
                    onPressed: () => _openEditInvoiceDialog(inv),
                  ),
                  if (inv.status == 'draft')
                    IconButton(
                      icon: const Icon(Icons.send_outlined, size: 18, color: Colors.blue),
                      tooltip: 'Submit Invoice',
                      onPressed: () async {
                        final repo = ref.read(logisticsInvoicesRepositoryProvider);
                        await repo.submitInvoice(inv.invoiceId);
                        ref.invalidate(logisticsInvoicesListProvider);
                      },
                    ),
                  if (inv.status == 'submitted')
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                      tooltip: 'Approve Invoice',
                      onPressed: () async {
                        final repo = ref.read(logisticsInvoicesRepositoryProvider);
                        await repo.approveInvoice(inv.invoiceId);
                        ref.invalidate(logisticsInvoicesListProvider);
                      },
                    ),
                  if (inv.remainingAmountEgp > 0 && inv.status == 'approved')
                    IconButton(
                      icon: const Icon(Icons.payments_outlined, size: 18, color: Colors.purple),
                      tooltip: 'Pay / Knock-off',
                      onPressed: () => _openPaymentDialog(inv.partnerId, inv.partnerName),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'draft':
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade700;
        break;
      case 'submitted':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue;
        break;
      case 'approved':
        bg = AppTheme.emerald.withValues(alpha: 0.15);
        fg = AppTheme.emerald;
        break;
      case 'partially_paid':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade800;
        break;
      case 'fully_paid':
        bg = AppTheme.emerald.withValues(alpha: 0.2);
        fg = AppTheme.emerald;
        break;
      default:
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ── Tab 2: Payments & Knock-offs ───────────────────────────────────────────

  Widget _buildPaymentsTab(BuildContext context, bool isDark) {
    final vouchersAsync = ref.watch(paymentVouchersListProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF161E28) : Colors.white,
          child: Row(
            children: [
              const Text('Logistics Payment Vouchers & Invoice Knock-offs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              AppButton(
                label: '+ Create Payment Voucher',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: Icons.add,
                onPressed: () => _openPaymentDialog(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: vouchersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (vouchers) {
              if (vouchers.isEmpty) {
                return const Center(child: Text('No payment vouchers recorded yet.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: vouchers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final v = vouchers[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B232D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_outlined, color: AppTheme.emerald, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${v.voucherCode} · ${v.partnerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                'Method: ${v.paymentMethod} · Ref: ${v.bankReference ?? "N/A"} · Date: ${v.paymentDate.toIso8601String().split("T").first}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${v.amountEgp.toStringAsFixed(2)} EGP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('Knocked Off: ${v.knockoffs.length} Invoices', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Clearance Advances ──────────────────────────────────────────────

  Widget _buildAdvancesTab(BuildContext context, bool isDark) {
    final advancesAsync = ref.watch(clearanceAdvancesListProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF161E28) : Colors.white,
          child: Row(
            children: [
              const Text('Broker Advance Payments & Custody (عهد ودفعات التخليص)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              AppButton(
                label: '+ Record Broker Advance',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: Icons.add,
                onPressed: _openAdvanceDialog,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: advancesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (advances) {
              if (advances.isEmpty) {
                return const Center(child: Text('No advance payments recorded yet.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: advances.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final adv = advances[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B232D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${adv.advanceCode} · ${adv.clearancePartnerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                'Shipment: ${adv.shipmentId} · B/L: ${adv.blNumber ?? "N/A"} · Date: ${adv.paymentDate.toIso8601String().split("T").first}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${adv.amountEgp.toStringAsFixed(2)} EGP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              'Settled: ${adv.settledAmountEgp.toStringAsFixed(2)} | Rem: ${adv.remainingAmountEgp.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: adv.remainingAmountEgp > 0 ? AppTheme.orange : AppTheme.emerald,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Tab 4: Marine Insurance Policies ───────────────────────────────────────

  Widget _buildInsuranceTab(BuildContext context, bool isDark) {
    final policiesAsync = ref.watch(insurancePoliciesListProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF161E28) : Colors.white,
          child: Row(
            children: [
              const Text('Marine Insurance Policies (بوالص التأمين البحري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              AppButton(
                label: '+ Issue Marine Policy',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: Icons.add,
                onPressed: _openInsuranceDialog,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: policiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (policies) {
              if (policies.isEmpty) {
                return const Center(child: Text('No marine insurance policies issued yet.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: policies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final pol = policies[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B232D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.purple, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${pol.policyCode} — #${pol.policyNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                '${pol.insuranceCompanyName} · Clause: ${pol.coverageType.toUpperCase()}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Text(
                                'Insured Value (CIF+10%): ${pol.insuredValueFx.toStringAsFixed(2)} ${pol.insuredValueCurrency}',
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${pol.netPremiumEgp.toStringAsFixed(2)} EGP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              pol.invoiceGenerated ? 'Invoice Generated ✅' : 'Invoice Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: pol.invoiceGenerated ? AppTheme.emerald : AppTheme.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
