import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/broker_custody_model.dart';
import '../services/broker_custody_service.dart';
import 'broker_custody/add_broker_custody_expense_dialog.dart';
import 'broker_custody/broker_custody_advance_card.dart';
import 'broker_custody/broker_custody_reconciliation_dialog.dart';
import 'broker_custody/new_broker_custody_advance_dialog.dart';

class BrokerCustodySettlementDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const BrokerCustodySettlementDialog({super.key, this.initialImportFileId});

  static Future<void> show(BuildContext context, {int? initialImportFileId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BrokerCustodySettlementDialog(initialImportFileId: initialImportFileId),
    );
  }

  @override
  ConsumerState<BrokerCustodySettlementDialog> createState() => _BrokerCustodySettlementDialogState();
}

class _BrokerCustodySettlementDialogState extends ConsumerState<BrokerCustodySettlementDialog> {
  List<BrokerCustodyAdvanceModel> _advances = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(brokerCustodyServiceProvider);
      final list = await service.listAdvances(
        importFileId: widget.initialImportFileId,
      );

      if (mounted) {
        setState(() {
          _advances = list;
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

  AppSeverity _statusSeverity(String status) {
    switch (status) {
      case 'SETTLED':
        return AppSeverity.success;
      case 'PARTIALLY_SETTLED':
        return AppSeverity.warning;
      case 'OPEN':
      default:
        return AppSeverity.info;
    }
  }

  void _showNewAdvanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => NewBrokerCustodyAdvanceDialog(
        initialImportFileId: widget.initialImportFileId,
        onSubmit: ({
          required int importFileId,
          required int brokerId,
          required String brokerName,
          required double advanceAmount,
          required String disbursementDate,
          required String paymentMethod,
          String? notes,
        }) async {
          final service = ref.read(brokerCustodyServiceProvider);
          await service.createAdvance(
            importFileId: importFileId,
            brokerId: brokerId,
            brokerName: brokerName,
            advanceAmount: advanceAmount,
            disbursementDate: disbursementDate,
            paymentMethod: paymentMethod,
            notes: notes,
          );
          if (!mounted) return;
          AppTheme.snackBar(context, 'تم صرف وقيد عهدة المخلص بنجاح', severity: AppSeverity.success);
          _loadData();
        },
      ),
    );
  }

  void _showAddExpenseDialog(BrokerCustodyAdvanceModel advance) {
    showDialog(
      context: context,
      builder: (ctx) => AddBrokerCustodyExpenseDialog(
        advance: advance,
        onSubmit: ({
          required String expenseCategory,
          required double amount,
          required bool isEInvoiceBacked,
          String? eInvoiceUuid,
          String? receiptReference,
          String? notes,
        }) async {
          final service = ref.read(brokerCustodyServiceProvider);
          await service.addExpenseItem(
            advance.advanceId,
            expenseCategory: expenseCategory,
            amount: amount,
            isEInvoiceBacked: isEInvoiceBacked,
            eInvoiceUuid: eInvoiceUuid,
            receiptReference: receiptReference,
            notes: notes,
          );
          if (!mounted) return;
          AppTheme.snackBar(context, 'تمت إضافة بند المصروف وحساب ضريبة الخصم 1% بنجاح', severity: AppSeverity.success);
          _loadData();
        },
      ),
    );
  }

  void _approveItem(BrokerExpenseItemModel item) async {
    try {
      final service = ref.read(brokerCustodyServiceProvider);
      await service.approveExpenseItem(
        item.itemId,
        approvalStatus: 'APPROVED',
        verifiedBy: 'المراجع المالي',
      );
      if (!mounted) return;
      AppTheme.snackBar(context, 'تم اعتماد البند بنجاح تمهيداً للتسوية', severity: AppSeverity.success);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      AppTheme.snackBar(context, 'فشل في اعتماد البند: $e', severity: AppSeverity.danger);
    }
  }

  void _settleAdvance(BrokerCustodyAdvanceModel advance) async {
    try {
      final service = ref.read(brokerCustodyServiceProvider);
      final reconciliation = await service.settleAdvance(advance.advanceId);
      if (!mounted) return;

      BrokerCustodyReconciliationDialog.show(
        context,
        reconciliation: reconciliation,
        onDismissed: _loadData,
      );
    } catch (e) {
      if (!mounted) return;
      AppTheme.snackBar(context, 'فشل في تنفيذ التسوية: $e', severity: AppSeverity.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
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
        child: SelectionArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.emerald, size: 26),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تسوية عهد ومصروفات المخلصين الجمركيين',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'صرف العهد المالية، تسجيل المصروفات واحتساب ضريبة الخصم 1% (نموذج 41)، وإجراء المقاصة النهائية',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      label: 'صرف عهدة جديدة',
                      icon: Icons.add_circle_outline,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: _showNewAdvanceDialog,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text('خطأ: $_errorMessage', style: const TextStyle(color: AppTheme.crimson)))
                        : _advances.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 10),
                                    const Text('لا توجد عهد مخلصين مسجلة لهذا الملف حالياً', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                  ],
                                ),
                              )
                            : SelectionArea(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _advances.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, idx) {
                                    return BrokerCustodyAdvanceCard(
                                      advance: _advances[idx],
                                      onAddExpense: _showAddExpenseDialog,
                                      onSettleAdvance: _settleAdvance,
                                      onApproveItem: _approveItem,
                                      statusSeverity: _statusSeverity,
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
}
