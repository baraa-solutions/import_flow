import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/actual_landed_cost_model.dart';
import '../providers/financial_settlement_provider.dart';
import 'actual/actual_landed_cost_footer.dart';
import 'actual/actual_landed_cost_summary.dart';
import 'actual/actual_landed_cost_tables.dart';
import 'settlement_ui.dart';

class ActualLandedCostDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;

  const ActualLandedCostDialog({
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
      builder: (ctx) => ActualLandedCostDialog(
        importFileId: importFileId,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<ActualLandedCostDialog> createState() => _ActualLandedCostDialogState();
}

class _ActualLandedCostDialogState extends ConsumerState<ActualLandedCostDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  ActualLandedCostCalculationResponseModel? _calcData;

  String _selectedAllocationPreference = 'Value-Based';
  late TabController _tabController;

  final _approvedByController = TextEditingController();
  String _defaultApprovedBy = '';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _defaultApprovedBy = ref.read(authProvider).user?.fullName ?? '';
    _approvedByController.text = _defaultApprovedBy;
    _tabController = TabController(length: 2, vsync: this);
    _loadCalculation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _approvedByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCalculation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ref
          .read(financialSettlementProvider.notifier)
          .calculateActualLandedCost(
            widget.importFileId,
            allocationPreference: _selectedAllocationPreference,
          );
      if (mounted) {
        setState(() {
          _calcData = data;
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

  Future<void> _handleApprove() async {
    if (_approvedByController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.settlementClo02ApproveRequired,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final res = await ref
          .read(financialSettlementProvider.notifier)
          .approveActualLandedCost(
            importFileId: widget.importFileId,
            approvedBy: _approvedByController.text.trim(),
            allocationPreference: _selectedAllocationPreference,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          );

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

  bool get _isDirty {
    if (_notesController.text.trim().isNotEmpty) return true;
    if (_selectedAllocationPreference != 'Value-Based') return true;
    if (_approvedByController.text.trim() != _defaultApprovedBy) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1200,
            maxHeight: 880,
          ),
          child: SelectionArea(
            child: Column(
              children: [
                SettlementDialogHeader(
                  icon: Icons.calculate_outlined,
                  title: l10n.settlementClo02Title,
                  subtitle: l10n.settlementClo02Subtitle(widget.importFileCode),
                  closeKey: const Key('actualLandedCostCloseBtn'),
                  closeTooltip: l10n.settlementClose,
                  onClose: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
                ),
                Expanded(
                  child: _isLoading
                      ? SettlementStateView.loading(message: l10n.settlementClo02Loading)
                      : _errorMessage != null
                          ? SettlementStateView.error(
                              message: '${l10n.settlementClo02ErrorTitle}\n${_errorMessage ?? ''}',
                              actionLabel: l10n.settlementRetry,
                              onAction: _loadCalculation,
                            )
                          : _buildContent(l10n),
                ),
                if (!_isLoading && _errorMessage == null)
                  ActualLandedCostFooter(
                    approvedByController: _approvedByController,
                    notesController: _notesController,
                    isSubmitting: _isSubmitting,
                    onCancel: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
                    onApprove: _handleApprove,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final calc = _calcData!;
    return Column(
      children: [
        ActualLandedCostSummary(calc: calc),
        _buildAllocationControlBar(l10n),
        _buildTabBar(l10n),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ActualLandedCostTables.buildCategoriesVarianceTab(context, calc),
              ActualLandedCostTables.buildItemsLandedCostTab(context, calc),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationControlBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 18, color: AppTheme.flatCharcoal),
              const SizedBox(width: 8),
              Text(
                l10n.settlementClo02AllocationLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.flatCharcoal,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 260,
                child: SearchableDropdownField<String>(
                  key: const Key('actualLandedCostAllocationDropdown'),
                  value: _selectedAllocationPreference,
                  labelText: l10n.financialSettlementAllocationRuleLabel,
                  searchHintText: l10n.financialSettlementAllocationRuleSearchHint,
                  items: [
                    SearchableDropdownItem(value: 'Value-Based', label: l10n.financialSettlementRuleValueBased),
                    SearchableDropdownItem(value: 'Weight-Based', label: l10n.financialSettlementRuleWeightBased),
                    SearchableDropdownItem(value: 'Volume-Based', label: l10n.financialSettlementRuleVolumeBased),
                    SearchableDropdownItem(value: 'Equal', label: l10n.financialSettlementRuleEqual),
                  ],
                  onChanged: (val) {
                    if (val != null && val != _selectedAllocationPreference) {
                      setState(() {
                        _selectedAllocationPreference = val;
                      });
                      _loadCalculation();
                    }
                  },
                ),
              ),
            ],
          ),
          Text(
            l10n.settlementClo02Counts(
              _calcData?.itemsBreakdown.length ?? 0,
              _calcData?.categoriesBreakdown.length ?? 0,
            ),
            style: const TextStyle(fontSize: 12, color: AppTheme.textStrong),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return Container(
      color: SettlementTokens.panelFill,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.flatCobalt,
        unselectedLabelColor: AppTheme.flatCharcoal.withValues(alpha: 0.7),
        indicatorColor: AppTheme.flatCobalt,
        indicatorWeight: 3,
        tabs: [
          Tab(
            key: const Key('actualLandedCostExpensesTab'),
            icon: const Icon(Icons.pie_chart_outline, size: 18),
            text: l10n.settlementClo02TabExpenses(_calcData?.categoriesBreakdown.length ?? 0),
          ),
          Tab(
            key: const Key('actualLandedCostItemsTab'),
            icon: const Icon(Icons.view_list_outlined, size: 18),
            text: l10n.settlementClo02TabItems(_calcData?.itemsBreakdown.length ?? 0),
          ),
        ],
      ),
    );
  }
}
