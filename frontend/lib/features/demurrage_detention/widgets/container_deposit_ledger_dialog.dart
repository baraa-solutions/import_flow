import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/container_deposit_model.dart';
import '../services/container_deposit_service.dart';
import 'deposit_ledger/deposit_ledger_card.dart';
import 'deposit_ledger/deposit_ledger_header.dart';
import 'deposit_ledger/deposit_ledger_toolbar.dart';
import 'deposit_ledger/deposit_sub_dialogs.dart';

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
              DepositLedgerHeader(
                overview: _overview,
                onNewDeposit: () => DepositSubDialogs.showNewDepositDialog(
                  context,
                  ref,
                  initialImportFileId: widget.initialImportFileId,
                  onSaved: _loadData,
                ),
                onClose: () => Navigator.of(context).pop(),
              ),
              DepositLedgerToolbar(
                searchController: _searchController,
                onSearchChanged: (_) => _loadData(),
                selectedStatus: _selectedStatus,
                onStatusChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedStatus = val);
                    _loadData();
                  }
                },
                onRefresh: _loadData,
              ),
              const Divider(height: 1),
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
                                    return DepositLedgerCard(
                                      item: item,
                                      onRecordEir: () => DepositSubDialogs.showRecordEirDialog(
                                        context,
                                        ref,
                                        item: item,
                                        onSaved: _loadData,
                                      ),
                                      onEditEir: () => DepositSubDialogs.showRecordEirDialog(
                                        context,
                                        ref,
                                        item: item,
                                        onSaved: _loadData,
                                      ),
                                      onDispute: () => DepositSubDialogs.showDisputeDialog(
                                        context,
                                        ref,
                                        item: item,
                                        onSaved: _loadData,
                                      ),
                                      onRecordRefund: () => DepositSubDialogs.showRecordRefundDialog(
                                        context,
                                        ref,
                                        item: item,
                                        onSaved: _loadData,
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
}
