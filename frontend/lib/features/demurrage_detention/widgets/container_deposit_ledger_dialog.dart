import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../models/container_deposit_model.dart';
import '../services/container_deposit_service.dart';

class ContainerDepositLedgerDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const ContainerDepositLedgerDialog({super.key, this.initialImportFileId});

  static Future<void> show(BuildContext context, {int? initialImportFileId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContainerDepositLedgerDialog(initialImportFileId: initialImportFileId),
    );
  }

  @override
  ConsumerState<ContainerDepositLedgerDialog> createState() => _ContainerDepositLedgerDialogState();
}

class _ContainerDepositLedgerDialogState extends ConsumerState<ContainerDepositLedgerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<ContainerDepositModel> _deposits = [];
  ContainerDepositOverviewModel? _overview;
  bool _isLoading = false;
  String _selectedStatus = 'All';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(containerDepositServiceProvider);
      final list = await service.listDeposits(
        importFileId: widget.initialImportFileId,
        refundStatus: _selectedStatus,
        containerNumber: _searchController.text.trim(),
      );
      final over = await service.getOverviewAndAlerts();

      if (mounted) {
        setState(() {
          _deposits = list;
          _overview = over;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  AppSeverity _refundStatusSeverity(DepositRefundStatus status) {
    switch (status) {
      case DepositRefundStatus.overdue30Days:
        return AppSeverity.danger;
      case DepositRefundStatus.pendingReturn:
        return AppSeverity.warning;
      case DepositRefundStatus.claimSubmitted:
        return AppSeverity.info;
      case DepositRefundStatus.refundedFull:
      case DepositRefundStatus.refundedPartial:
        return AppSeverity.success;
    }
  }

  void _showNewDepositDialog() {
    final fileIdController = TextEditingController(text: widget.initialImportFileId?.toString() ?? '');
    final carrierController = TextEditingController();
    final containerNoController = TextEditingController();
    final containerTypeController = TextEditingController(text: '40HC');
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);

    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_card_rounded, color: AppTheme.cobalt),
              SizedBox(width: 8),
              Text('تسجيل تأمين حاوية جديد مدفوع للخط الملاحي'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'معرف الملف الاستيرادي',
                          controller: fileIdController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'اسم الخط الملاحي / التوكيل',
                          controller: carrierController,
                          hint: 'Maersk, MSC, CMA CGM...',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: CustomTextField(
                          label: 'رقم الحاوية',
                          controller: containerNoController,
                          hint: 'MSKU1234567',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'نوع الحاوية',
                          controller: containerTypeController,
                          hint: '20ft, 40HC, Reefer',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'مبلغ التأمين (ج.م)',
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'تاريخ الدفع (YYYY-MM-DD)',
                          controller: dateController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    label: 'رقم إيصال / شيك / مرجع السداد',
                    controller: refController,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'حفظ التأمين',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final fid = int.tryParse(fileIdController.text.trim());
                final amt = double.tryParse(amountController.text.trim());
                if (fid == null || amt == null || containerNoController.text.trim().isEmpty || carrierController.text.trim().isEmpty) {
                  AppTheme.snackBar(ctx, 'يرجى استيفاء الحقول الإجبارية ورقم الحاوية والمبلغ', severity: AppSeverity.warning);
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(containerDepositServiceProvider);
                  await service.createDeposit(
                    importFileId: fid,
                    carrierName: carrierController.text.trim(),
                    containerNumber: containerNoController.text.trim(),
                    containerType: containerTypeController.text.trim(),
                    depositAmountEgp: amt,
                    paymentDate: dateController.text.trim(),
                    paymentReference: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                  );
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'تم تسجيل تأمين الحاوية بنجاح', severity: AppSeverity.success);
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'فشل في حفظ التأمين: $e', severity: AppSeverity.danger);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordEirDialog(ContainerDepositModel item) {
    final eirNoController = TextEditingController(text: item.eirReturnNumber ?? '');
    final eirDateController = TextEditingController(text: item.eirReturnDate ?? DateTime.now().toIso8601String().split('T').first);
    String condition = item.containerCondition.name.toUpperCase();
    if (condition == 'SOUNDCLEAN') condition = 'SOUND_CLEAN';
    if (condition == 'DAMAGECLAIMED') condition = 'DAMAGE_CLAIMED';
    if (condition == 'CLEANINGFEEDEDUCTED') condition = 'CLEANING_FEE_DEDUCTED';

    final deductionController = TextEditingController(text: item.deductionAmountEgp > 0 ? item.deductionAmountEgp.toStringAsFixed(2) : '0');
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => SelectionArea(
          child: AlertDialog(
            title: Text('تسجيل إيصال استرجاع الفارغ (EIR) — ${item.containerNumber}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'تسجيل إيصال الـ EIR يبدأ مهلة الـ 30 يوماً القانونية الممنوحة للخط الملاحي لرد مبلغ التأمين.',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.cobalt),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'رقم إيصال التسليم',
                            controller: eirNoController,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomTextField(
                            label: 'تاريخ الإيصال (YYYY-MM-DD)',
                            controller: eirDateController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: condition,
                      labelText: 'حالة الحاوية في محطة الإرجاع',
                      items: const [
                        SearchableDropdownItem<String>(value: 'SOUND_CLEAN', label: 'سليمة ونظيفة'),
                        SearchableDropdownItem<String>(value: 'DAMAGE_CLAIMED', label: 'مطالبة بأضرار وتلفيات'),
                        SearchableDropdownItem<String>(value: 'CLEANING_FEE_DEDUCTED', label: 'خصم غسيل ونظافة'),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => condition = v);
                      },
                    ),
                    if (condition != 'SOUND_CLEAN') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'مبلغ الخصم المدعى (ج.م)',
                              controller: deductionController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextField(
                              label: 'سبب الخصم / التلفيات',
                              controller: reasonController,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
              AppButton(
                label: 'حفظ إيصال الـ EIR',
                variant: AppButtonVariant.primary,
                onPressed: () async {
                  if (eirNoController.text.trim().isEmpty) {
                    AppTheme.snackBar(ctx, 'يرجى إدخال رقم إيصال الـ EIR', severity: AppSeverity.warning);
                    return;
                  }
                  final ded = double.tryParse(deductionController.text.trim()) ?? 0.0;
                  Navigator.of(ctx).pop();
                  try {
                    final service = ref.read(containerDepositServiceProvider);
                    await service.recordEirReturn(
                      item.depositId,
                      eirReturnNumber: eirNoController.text.trim(),
                      eirReturnDate: eirDateController.text.trim(),
                      containerCondition: condition,
                      deductionAmountEgp: ded,
                      deductionReason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                    );
                    if (!mounted) return;
                    AppTheme.snackBar(context, 'تم حفظ إيصال استرجاع الحاوية بنجاح وبدء مهلة المطالبة', severity: AppSeverity.success);
                    _loadData();
                  } catch (e) {
                    if (!mounted) return;
                    AppTheme.snackBar(context, 'فشل في حفظ إيصال EIR: $e', severity: AppSeverity.danger);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordRefundDialog(ContainerDepositModel item) {
    final refController = TextEditingController(text: item.refundChequeOrTransferNo ?? '');
    final dateController = TextEditingController(text: item.refundReceivedDate ?? DateTime.now().toIso8601String().split('T').first);
    final expectedAmount = item.depositAmountEgp - item.deductionAmountEgp;
    final amountController = TextEditingController(text: expectedAmount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: Text('تسجيل استرداد مبلغ التأمين — ${item.containerNumber}'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الخط الملاحي: ${item.carrierName} | التأمين الأصلي: ${item.depositAmountEgp.toStringAsFixed(2)} ج.م',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              if (item.deductionAmountEgp > 0)
                Text(
                  'الخصومات المقتطعة: ${item.deductionAmountEgp.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'رقم الشيك أو التحويل البنكي المستلم',
                controller: refController,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'المبلغ المسترد فعلياً (ج.م EGP)',
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomTextField(
                      label: 'تاريخ الاستلام (YYYY-MM-DD)',
                      controller: dateController,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          AppButton(
            label: 'تأكيد استلام الاسترداد',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (refController.text.trim().isEmpty || amt <= 0) {
                AppTheme.snackBar(ctx, 'يرجى إدخال رقم الشيك/التحويل والمبلغ المسترد', severity: AppSeverity.warning);
                return;
              }
              Navigator.of(ctx).pop();
              try {
                final service = ref.read(containerDepositServiceProvider);
                await service.recordRefund(
                  item.depositId,
                  refundChequeOrTransferNo: refController.text.trim(),
                  refundReceivedDate: dateController.text.trim(),
                  refundAmountEgp: amt,
                );
                if (!mounted) return;
                AppTheme.snackBar(context, 'تم تسجيل استرداد تأمين الحاوية بنجاح وإغلاق المطالبة', severity: AppSeverity.success);
                _loadData();
              } catch (e) {
                if (!mounted) return;
                AppTheme.snackBar(context, 'فشل في حفظ استرداد التأمين: $e', severity: AppSeverity.danger);
              }
            },
          ),
        ],
      ),
      ),
    );
  }

  void _showDisputeDialog(ContainerDepositModel item) {
    final reasonController = TextEditingController();
    final revisedController = TextEditingController(text: '0.00');
    bool waive = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => SelectionArea(
          child: AlertDialog(
            title: Text('اعتراض على خصومات التأمين — ${item.containerNumber}'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قيمة الخصم الحالية: ${item.deductionAmountEgp.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'أسباب الاعتراض ومبررات إلغاء الخصم',
                  controller: reasonController,
                  maxLines: 2,
                  hint: 'تقديم صور الحاوية عند التحميل، أو تقرير سلامة سليم...',
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('إلغاء الخصم بالكامل (إعفاء 100%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  value: waive,
                  onChanged: (v) => setDlgState(() => waive = v ?? false),
                ),
                if (!waive) ...[
                  const SizedBox(height: 8),
                  CustomTextField(
                    label: 'قيمة الخصم المتفق عليها بعد التفاوض (ج.م EGP)',
                    controller: revisedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'حفظ نتيجة الاعتراض',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  AppTheme.snackBar(ctx, 'يرجى كتابة سبب ومستند الاعتراض', severity: AppSeverity.warning);
                  return;
                }
                final revised = waive ? 0.0 : (double.tryParse(revisedController.text.trim()) ?? 0.0);
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(containerDepositServiceProvider);
                  await service.disputeDeduction(
                    item.depositId,
                    disputeReason: reasonController.text.trim(),
                    revisedDeductionAmountEgp: revised,
                    waived: waive,
                  );
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'تم تسجيل نتيجة الاعتراض وتعديل قيمة الخصم', severity: AppSeverity.success);
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  AppTheme.snackBar(context, 'فشل في تسجيل الاعتراض: $e', severity: AppSeverity.danger);
                }
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
          width: 1150,
          height: 760,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: AppTheme.emerald, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجل تأمين الحاويات وإيصالات الاسترجاع (Container Deposit & EIR Ledger)',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'إدارة تأمينات الخطوط الملاحية، تتبع إيصالات الـ EIR، وحصر التأمينات المتأخرة عن مهلة الـ 30 يوماً',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'تسجيل تأمين حاوية',
                    icon: Icons.add_card_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: _showNewDepositDialog,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Metrics Bar
            if (_overview != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.grey.shade100,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMetricChip('إجمالي التأمينات المسجلة', '${_overview!.totalActiveDeposits}', Colors.blueGrey),
                      const SizedBox(width: 8),
                      _buildMetricChip('إجمالي المدفوع للخطوط', '${_overview!.totalDepositAmountEgp.toStringAsFixed(0)} ج.م', AppTheme.cobalt),
                      const SizedBox(width: 8),
                      _buildMetricChip('قيد الإرجاع الفارغ 🟡', '${_overview!.pendingReturnCount}', AppTheme.orange),
                      const SizedBox(width: 8),
                      _buildMetricChip('تم تقديم الـ EIR 🔵', '${_overview!.claimSubmittedCount}', Colors.blue.shade700),
                      const SizedBox(width: 8),
                      _buildMetricChip('متأخرة عن 30 يوم 🔴', '${_overview!.overdue30DaysCount}', AppTheme.crimson),
                      const SizedBox(width: 8),
                      _buildMetricChip('مستردة بالكامل 🟢', '${_overview!.refundedFullCount}', AppTheme.emerald),
                    ],
                  ),
                ),
              ),

            // Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 250,
                    child: AppSearchField(
                      controller: _searchController,
                      hint: 'بحث برقم الحاوية أو الخط...',
                      onChanged: (_) => _loadData(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('حالة الاسترداد: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('كافة الحالات')),
                      DropdownMenuItem(value: 'OVERDUE_30_DAYS', child: Text('🔴 متأخرة عن 30 يوماً')),
                      DropdownMenuItem(value: 'CLAIM_SUBMITTED', child: Text('🔵 تم تقديم المطالبة والـ EIR')),
                      DropdownMenuItem(value: 'PENDING_RETURN', child: Text('🟡 قيد الإرجاع (لم تسلم)')),
                      DropdownMenuItem(value: 'REFUNDED_FULL', child: Text('🟢 مستردة بالكامل')),
                      DropdownMenuItem(value: 'REFUNDED_PARTIAL', child: Text('🟠 مستردة جزئياً')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatus = val);
                        _loadData();
                      }
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث القائمة',
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Records List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text('خطأ: $_errorMessage', style: const TextStyle(color: AppTheme.crimson)))
                      : _deposits.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 54, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  const Text('لا توجد سجلات تأمين حاويات مسجلة حالياً', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            )
                          : SelectionArea(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _deposits.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = _deposits[idx];

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: item.daysOverdue > 0 ? AppTheme.crimson.withValues(alpha: 0.5) : Colors.grey.shade300,
                                        width: item.daysOverdue > 0 ? 1.5 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Left Icon Badge
                                        Container(
                                          width: 80,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: item.daysOverdue > 0 ? AppTheme.crimson.withValues(alpha: 0.12) : Colors.blueGrey.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.inventory_2_outlined,
                                                color: item.daysOverdue > 0 ? AppTheme.crimson : AppTheme.cobalt,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.containerType,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: item.daysOverdue > 0 ? AppTheme.crimson : AppTheme.cobalt,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Main Details
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    item.containerNumber,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.cobalt),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  AppStatusBadge(
                                                    label: item.refundStatus.labelAr,
                                                    severity: _refundStatusSeverity(item.refundStatus),
                                                  ),
                                                  if (item.daysOverdue > 0) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.crimson.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'متأخر ${item.daysOverdue} يوم',
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'الخط الملاحي: ${item.carrierName} | التأمين المدفوع: ${item.depositAmountEgp.toStringAsFixed(2)} ج.م | تاريخ الدفع: ${item.paymentDate}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                              Row(
                                                children: [
                                                  if (item.eirReturnNumber != null) ...[
                                                    const Icon(Icons.assignment_turned_in_outlined, size: 14, color: Colors.green),
                                                    const SizedBox(width: 3),
                                                    Text('EIR: ${item.eirReturnNumber} (${item.eirReturnDate})', style: const TextStyle(fontSize: 11, color: Colors.green)),
                                                    const SizedBox(width: 10),
                                                    Text('الحالة: ${item.containerCondition.labelAr}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                                    const SizedBox(width: 10),
                                                  ],
                                                  if (item.deductionAmountEgp > 0) ...[
                                                    const Icon(Icons.money_off_rounded, size: 14, color: AppTheme.crimson),
                                                    const SizedBox(width: 3),
                                                    Text('خصم: ${item.deductionAmountEgp.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 11, color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                                                    const SizedBox(width: 10),
                                                  ],
                                                  if (item.refundChequeOrTransferNo != null) ...[
                                                    const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.emerald),
                                                    const SizedBox(width: 3),
                                                    Text('مسترد: شيك/تحويل ${item.refundChequeOrTransferNo}', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Operations Buttons
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (item.eirReturnNumber == null)
                                              AppButton(
                                                label: 'تسجيل EIR',
                                                icon: Icons.assignment_outlined,
                                                variant: AppButtonVariant.primary,
                                                size: AppButtonSize.small,
                                                onPressed: () => _showRecordEirDialog(item),
                                              )
                                            else ...[
                                              AppButton(
                                                label: 'تعديل EIR',
                                                icon: Icons.edit_note_rounded,
                                                variant: AppButtonVariant.secondary,
                                                size: AppButtonSize.small,
                                                onPressed: () => _showRecordEirDialog(item),
                                              ),
                                              const SizedBox(width: 6),
                                              if (item.deductionAmountEgp > 0) ...[
                                                AppButton(
                                                  label: 'اعتراض خصم',
                                                  icon: Icons.gavel_rounded,
                                                  variant: AppButtonVariant.secondary,
                                                  size: AppButtonSize.small,
                                                  onPressed: () => _showDisputeDialog(item),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              if (item.refundChequeOrTransferNo == null)
                                                AppButton(
                                                  label: 'استلام الاسترداد',
                                                  icon: Icons.payments_outlined,
                                                  variant: AppButtonVariant.success,
                                                  size: AppButtonSize.small,
                                                  onPressed: () => _showRecordRefundDialog(item),
                                                ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
