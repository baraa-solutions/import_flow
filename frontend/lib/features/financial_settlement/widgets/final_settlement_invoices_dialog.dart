import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/invoices_aggregation_model.dart';
import '../providers/financial_settlement_provider.dart';
import 'invoices/final_settlement_invoices_table.dart';
import 'invoices/final_settlement_kpis.dart';
import 'invoices/final_settlement_parties_filter.dart';
import 'invoices/final_settlement_signoff_form.dart';
import 'settlement_ui.dart';

class FinalSettlementInvoicesDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;

  const FinalSettlementInvoicesDialog({
    super.key,
    required this.importFileId,
    required this.importFileCode,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int importFileId,
    required String importFileCode,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FinalSettlementInvoicesDialog(
        importFileId: importFileId,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<FinalSettlementInvoicesDialog> createState() =>
      _FinalSettlementInvoicesDialogState();
}

class _FinalSettlementInvoicesDialogState
    extends ConsumerState<FinalSettlementInvoicesDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  InvoicesAggregationResponseModel? _aggregationData;

  String _selectedPartyFilter = 'ALL';
  bool _acknowledgeUnpaid = false;
  final _settledByController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _settledByController.text = ref.read(authProvider).user?.fullName ?? '';
    _loadData();
  }

  @override
  void dispose() {
    _settledByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ref
          .read(financialSettlementProvider.notifier)
          .fetchInvoicesAggregation(widget.importFileId);
      if (mounted) {
        setState(() {
          _aggregationData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiErrorText.of(context.l10n, e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleConfirmSettlement() async {
    if (_aggregationData == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final req = ConfirmInvoicesSettlementRequestModel(
        importFileId: widget.importFileId,
        settlementNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        acknowledgeUnpaid: _acknowledgeUnpaid,
      );

      final res = await ref
          .read(financialSettlementProvider.notifier)
          .confirmInvoicesSettlement(req);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            res.message,
            severity: AppSeverity.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            ApiErrorText.of(context.l10n, e),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.85).clamp(800.0, 1250.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(600.0, 850.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 16,
      child: SelectionArea(
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              _buildHeader(l10n),
              Expanded(
                child: _isLoading
                    ? SettlementStateView.loading(message: l10n.settlementClo01Loading)
                    : _errorMessage != null
                        ? SettlementStateView.error(
                            message: _errorMessage!,
                            actionLabel: l10n.settlementRetry,
                            onAction: _loadData,
                          )
                        : _buildBody(l10n),
              ),
              _buildFooter(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final settled = _aggregationData?.financialSettlementStatus == 'INVOICES_SETTLED';
    return SettlementDialogHeader(
      icon: Icons.receipt_long_rounded,
      title: l10n.settlementClo01Title,
      subtitle: l10n.settlementClo01Subtitle(widget.importFileCode),
      trailing: _aggregationData == null
          ? null
          : SettlementStatusChip(
              label: settled
                  ? l10n.settlementClo01StatusSettled
                  : l10n.settlementClo01StatusPending,
              color: settled ? AppTheme.emerald : AppTheme.cobalt,
              icon: settled ? Icons.check_circle : Icons.hourglass_top_rounded,
              dense: true,
            ),
      onClose: () => Navigator.of(context).pop(false),
      closeTooltip: l10n.settlementClose,
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final data = _aggregationData!;
    final filteredInvoices = _selectedPartyFilter == 'ALL'
        ? data.invoices
        : data.invoices
            .where((inv) => inv.partyType == _selectedPartyFilter)
            .toList();

    final warnings = settlementWarningLines(l10n, data.messages, data.unsettledWarnings);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinalSettlementKpis(data: data),
          const SizedBox(height: 16),
          if (warnings.isNotEmpty) ...[
            FinalSettlementWarningsCard(warnings: warnings),
            const SizedBox(height: 16),
          ],
          FinalSettlementPartiesFilter(
            data: data,
            selectedPartyFilter: _selectedPartyFilter,
            onFilterChanged: (filter) => setState(() => _selectedPartyFilter = filter),
            importFileId: widget.importFileId,
            onReloadNeeded: _loadData,
          ),
          const SizedBox(height: 16),
          FinalSettlementInvoicesTable(invoices: filteredInvoices),
          const SizedBox(height: 20),
          FinalSettlementSignoffForm(
            settledByController: _settledByController,
            notesController: _notesController,
            settlementReadinessPercent: data.settlementReadinessPercent,
            acknowledgeUnpaid: _acknowledgeUnpaid,
            onAcknowledgeChanged: (val) => setState(() => _acknowledgeUnpaid = val),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    return SettlementDialogFooter(
      actions: [
        SettlementFit(
          child: AppButton(
            key: const Key('finalSettlementInvoicesCancelBtn'),
            label: l10n.settlementCancel,
            icon: Icons.close,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        SettlementFit(
          child: AppButton(
            key: const Key('confirmInvoicesSettlementBtn'),
            label: _isSubmitting
                ? l10n.settlementClo01Confirming
                : l10n.settlementClo01Confirm,
            icon: Icons.check_circle,
            variant: AppButtonVariant.success,
            isLoading: _isSubmitting,
            onPressed: (_isLoading || _isSubmitting) ? null : _handleConfirmSettlement,
          ),
        ),
      ],
    );
  }
}
