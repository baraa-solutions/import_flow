import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';
import '../widgets/advance_payment_dialog.dart';
import '../widgets/insurance_policy_dialog.dart';
import '../widgets/invoice_form_dialog.dart';
import '../widgets/logistics_payment_dialog.dart';
import '../widgets/invoices_screen/invoices_screen_header.dart';
import '../widgets/invoices_screen/logistics_advances_tab.dart';
import '../widgets/invoices_screen/logistics_insurance_tab.dart';
import '../widgets/invoices_screen/logistics_invoices_tab.dart';
import '../widgets/invoices_screen/logistics_payments_tab.dart';

class LogisticsInvoicesScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final int? initialShipmentId;
  final String? initialBlNumber;

  const LogisticsInvoicesScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialShipmentId,
    this.initialBlNumber,
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
    if (widget.initialShipmentId != null) {
      ref.read(selectedShipmentFilterProvider.notifier).state = widget.initialShipmentId;
    }
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
      builder: (ctx) => InvoiceFormDialog(
        defaultPartnerType: defaultType,
        initialShipmentId: widget.initialShipmentId,
        initialBlNumber: widget.initialBlNumber,
      ),
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
      builder: (ctx) => AdvancePaymentDialog(
        defaultShipmentId: widget.initialShipmentId,
        defaultBlNumber: widget.initialBlNumber,
      ),
    );
  }

  void _openInsuranceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InsurancePolicyDialog(
        defaultShipmentId: widget.initialShipmentId,
        defaultBlNumber: widget.initialBlNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isArabic = context.l10n.isArabic;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101419) : AppTheme.cloudWhite,
      body: SelectionArea(
        child: SafeArea(
          child: Column(
            children: [
              // Top App Bar / Header
              InvoicesScreenHeader(initialBlNumber: widget.initialBlNumber),

              // Tab Bar
              Container(
                color: isDark ? const Color(0xFF1E2630) : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.cobalt,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.cobalt,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(icon: const Icon(Icons.receipt_long), text: isArabic ? 'فواتير الخدمات' : 'Service Invoices'),
                    Tab(icon: const Icon(Icons.payment), text: isArabic ? 'سندات الصرف والإقفال' : 'Payment Vouchers & Knock-off'),
                    Tab(icon: const Icon(Icons.account_balance_wallet), text: isArabic ? 'عهد ودفعات التخليص' : 'Clearance Advances'),
                    Tab(icon: const Icon(Icons.shield), text: isArabic ? 'بوالص التأمين البحري' : 'Marine Insurance Policies'),
                  ],
                ),
              ),

              // Tab View Body
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    LogisticsInvoicesTab(
                      isDark: isDark,
                      onNewInvoice: _openNewInvoiceDialog,
                      onEditInvoice: _openEditInvoiceDialog,
                      onPayInvoice: _openPaymentDialog,
                    ),
                    LogisticsPaymentsTab(
                      isDark: isDark,
                      onCreatePayment: () => _openPaymentDialog(),
                    ),
                    LogisticsAdvancesTab(
                      isDark: isDark,
                      onCreateAdvance: _openAdvanceDialog,
                    ),
                    LogisticsInsuranceTab(
                      isDark: isDark,
                      onIssuePolicy: _openInsuranceDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
