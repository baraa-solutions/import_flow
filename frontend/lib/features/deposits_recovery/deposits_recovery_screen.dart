import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_picker_field.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../core/widgets/back_to_dashboard_button.dart';
import '../../core/widgets/buttons/app_button.dart';
import '../../core/widgets/copyable_data_helper.dart';
import '../../core/widgets/enterprise_data_table/enterprise_data_table.dart';
import '../../core/widgets/master_data_toolbar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/searchable_dropdown_field.dart';
import '../../core/widgets/standard_form_action_bar.dart';
import 'deposits_recovery_provider.dart';
import 'widgets/bank_lg_release_tracker.dart';
import 'widgets/carrier_deposit_claims_table.dart';
import 'widgets/pending_recovery_strip.dart';

/// Coordinator Screen: Deposits Recovery & Guarantee Releases (Type B).
/// < 380 lines, Parallel UI Decomposition, Pure Arabic.
class DepositsRecoveryScreen extends ConsumerStatefulWidget {
  const DepositsRecoveryScreen({super.key});

  @override
  ConsumerState<DepositsRecoveryScreen> createState() => _DepositsRecoveryScreenState();
}

class _DepositsRecoveryScreenState extends ConsumerState<DepositsRecoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateDepositDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final containerController = TextEditingController();
    final lgNumberController = TextEditingController();
    final issuingBankController = TextEditingController();
    DateTime? paidDate = DateTime.now();
    DateTime? lgExpiryDate;
    String depositType = 'SHIPPING_LINE_CONTAINER';
    String beneficiaryType = 'CARRIER';
    bool isSaving = false;

    const typeOptions = [
      SearchableDropdownItem(value: 'SHIPPING_LINE_CONTAINER', label: 'تأمين حاويات توكيل ملاحي'),
      SearchableDropdownItem(value: 'CUSTOMS_DUTY_SECURITY', label: 'أمانة جمركية مؤقتة'),
      SearchableDropdownItem(value: 'BANK_LETTER_OF_GUARANTEE', label: 'خطاب ضمان بنكي جمركي'),
      SearchableDropdownItem(value: 'PORT_AUTHORITY_SECURITY', label: 'تأمين هيئة الميناء'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SelectionArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تسجيل قيد تأمين أو خطاب ضمان جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('إثبات سداد التأمين أو فتح خطاب الضمان لربطه بدورة الاسترداد', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Divider(height: 24),
                    SearchableDropdownField<String>(
                      labelText: 'نوع التأمين أو الضمان',
                      value: depositType,
                      items: typeOptions,
                      onChanged: (v) {
                        setDialogState(() {
                          depositType = v ?? 'SHIPPING_LINE_CONTAINER';
                          beneficiaryType = depositType == 'SHIPPING_LINE_CONTAINER' ? 'CARRIER' : 'CUSTOMS';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'اسم الجهة المستفيدة (التوكيل / الجمرك)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'مبلغ التأمين بالجنيه'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (depositType == 'SHIPPING_LINE_CONTAINER')
                      TextField(
                        controller: containerController,
                        decoration: const InputDecoration(labelText: 'رقم الحاوية (إن وجد)'),
                      ),
                    if (depositType == 'BANK_LETTER_OF_GUARANTEE') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lgNumberController,
                              decoration: const InputDecoration(labelText: 'رقم خطاب الضمان البنكي'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: issuingBankController,
                              decoration: const InputDecoration(labelText: 'البنك المصدر للخطاب'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppDatePickerField(
                        label: 'تاريخ انتهاء صلاحية خطاب الضمان',
                        value: lgExpiryDate,
                        onChanged: (d) => setDialogState(() => lgExpiryDate = d),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppDatePickerField(
                      label: 'تاريخ السداد أو فتح الضمان',
                      value: paidDate,
                      onChanged: (d) => setDialogState(() => paidDate = d),
                    ),
                    const SizedBox(height: 24),
                    StandardFormActionBar(
                      isSaving: isSaving,
                      submitLabel: 'حفظ وقيد التأمين',
                      closeLabel: 'إلغاء',
                      onSubmit: () async {
                        final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                        if (nameController.text.trim().isEmpty || amt <= 0) return;
                        setDialogState(() => isSaving = true);
                        try {
                          await ref.read(depositsRecoveryActionsProvider).createDeposit({
                            'deposit_type': depositType,
                            'beneficiary_type': beneficiaryType,
                            'beneficiary_name': nameController.text.trim(),
                            'container_number': containerController.text.trim().isEmpty ? null : containerController.text.trim(),
                            'deposit_amount': amt,
                            'currency': 'EGP',
                            'paid_date': paidDate?.toIso8601String().substring(0, 10),
                            'bank_lg_number': lgNumberController.text.trim().isEmpty ? null : lgNumberController.text.trim(),
                            'bank_lg_issuing_bank': issuingBankController.text.trim().isEmpty ? null : issuingBankController.text.trim(),
                            'bank_lg_expiry_date': lgExpiryDate?.toIso8601String().substring(0, 10),
                          });
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } finally {
                          if (ctx.mounted) setDialogState(() => isSaving = false);
                        }
                      },
                      onClose: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<EnterpriseColumn<RefundableDepositModel>> _buildColumns() {
    return [
      EnterpriseColumn<RefundableDepositModel>(
        id: 'code',
        title: 'كود التأمين',
        width: 140,
        cellBuilder: (ctx, item, _) => InkWell(
          onTap: () => CopyHelper.copy(ctx, item.depositCode),
          child: Text(item.depositCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
        ),
      ),
      EnterpriseColumn<RefundableDepositModel>(
        id: 'beneficiary',
        title: 'الجهة المستفيدة',
        width: 200,
        cellBuilder: (ctx, item, _) => Text(item.beneficiaryName, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
      EnterpriseColumn<RefundableDepositModel>(
        id: 'amount',
        title: 'المبلغ (جنيه)',
        width: 130,
        isNumeric: true,
        cellBuilder: (ctx, item, _) => Text(item.depositAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      EnterpriseColumn<RefundableDepositModel>(
        id: 'container',
        title: 'الحاوية / رقم الضمان',
        width: 160,
        cellBuilder: (ctx, item, _) => Text(item.containerNumber ?? item.bankLgNumber ?? '-'),
      ),
      EnterpriseColumn<RefundableDepositModel>(
        id: 'eir',
        title: 'إيصال الفارغ',
        width: 140,
        cellBuilder: (ctx, item, _) => Text(item.eirNumber ?? 'معلق', style: TextStyle(color: item.eirNumber != null ? AppTheme.emerald : AppTheme.crimson)),
      ),
      EnterpriseColumn<RefundableDepositModel>(
        id: 'refunded',
        title: 'المسترد فعلياً',
        width: 130,
        isNumeric: true,
        cellBuilder: (ctx, item, _) => Text(item.refundedAmount.toStringAsFixed(2), style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
      ),
      EnterpriseColumn<RefundableDepositModel>(
        id: 'deduction',
        title: 'الاستقطاعات',
        width: 120,
        isNumeric: true,
        cellBuilder: (ctx, item, _) => Text(item.deductionAmount.toStringAsFixed(2), style: TextStyle(color: item.deductionAmount > 0 ? AppTheme.crimson : AppTheme.textSecondary)),
      ),
      EnterpriseColumn<RefundableDepositModel>(
        id: 'status',
        title: 'حالة الاسترداد',
        width: 140,
        cellBuilder: (ctx, item, _) => AppStatusBadge.fromStatus(status: item.recoveryStatus),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final depositsAsync = ref.watch(depositsRecoveryProvider);

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: PageHeader(
          title: 'استرداد تأمينات الحاويات وفك الضمانات',
          subtitle: 'سجل تأمينات التوكيلات الملاحية والأمانات الجمركية وخطابات الضمان البنكية',
          icon: Icons.account_balance_wallet_rounded,
          actions: [
            AppButton(
              label: 'تحديث',
              icon: Icons.refresh,
              variant: AppButtonVariant.ghost,
              onPressed: () {
                ref.invalidate(depositsRecoveryProvider);
                ref.invalidate(depositRecoveryMetricsProvider);
              },
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'تسجيل تأمين أو ضمان',
              icon: Icons.add_card_rounded,
              variant: AppButtonVariant.primary,
              onPressed: _showCreateDepositDialog,
            ),
            const SizedBox(width: 8),
            const BackToDashboardButton(),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: PendingRecoveryStrip(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: MasterDataToolbarWidget(
                moduleEndpoint: 'api/v1/deposits-recovery',
                title: 'تأمينات الحاويات والضمانات',
                onRefreshNeeded: () {
                  ref.invalidate(depositsRecoveryProvider);
                  ref.invalidate(depositRecoveryMetricsProvider);
                },
              ),
            ),
            Container(
              color: AppTheme.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.cobalt,
                indicatorColor: AppTheme.cobalt,
                tabs: const [
                  Tab(icon: Icon(Icons.table_chart), text: 'الجدول الشامل للضمانات والتأمينات'),
                  Tab(icon: Icon(Icons.directions_boat), text: 'تأمينات حاويات التوكيلات الملاحية'),
                  Tab(icon: Icon(Icons.account_balance), text: 'خطابات الضمان البنكية وأمانات الجمارك'),
                ],
              ),
            ),
            Expanded(
              child: depositsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('حدث خطأ في تحميل التأمينات: $e')),
                data: (items) => TabBarView(
                  controller: _tabController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: EnterpriseDataTable<RefundableDepositModel>(
                        storageKey: 'deposits_recovery_master_table',
                        data: items,
                        columns: _buildColumns(),
                        minWidth: 1160,
                        emptyMessage: 'لا توجد قيود تأمينات أو خطابات ضمان مسجلة',
                        emptyIcon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    CarrierDepositClaimsTable(
                      deposits: items.where((x) => x.depositType == 'SHIPPING_LINE_CONTAINER').toList(),
                    ),
                    BankLgReleaseTracker(
                      lgDeposits: items.where((x) => x.depositType == 'BANK_LETTER_OF_GUARANTEE' || x.depositType == 'CUSTOMS_DUTY_SECURITY').toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
