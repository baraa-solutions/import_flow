import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/lifecycle_board_model.dart';
import '../providers/lifecycle_board_provider.dart';

class StepActionDialog extends ConsumerStatefulWidget {
  final ShipmentStageCardModel shipment;
  final List<PhaseSummaryModel> allPhases;

  const StepActionDialog({
    super.key,
    required this.shipment,
    required this.allPhases,
  });

  @override
  ConsumerState<StepActionDialog> createState() => _StepActionDialogState();
}

class _StepActionDialogState extends ConsumerState<StepActionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _param1Controller = TextEditingController();
  final _param2Controller = TextEditingController();
  final _param3Controller = TextEditingController();

  final List<String> _selectedNextSteps = [];
  bool _isSaving = false;

  final List<String> _allStepCodes = [
    'STEP_01', 'STEP_02', 'STEP_03', 'STEP_04', 'STEP_05',
    'STEP_06', 'STEP_07',
    'STEP_08_PO', 'STEP_08_BL', 'STEP_08_MATCH', 'STEP_08_COO', 'STEP_08_COC',
    'STEP_09', 'STEP_10', 'STEP_11', 'STEP_12', 'STEP_13',
    'STEP_14', 'STEP_15', 'STEP_16', 'STEP_17', 'STEP_18',
    'STEP_19', 'STEP_20', 'STEP_21',
  ];

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.shipment.notes ?? '';
    _initDefaultParams();
    _suggestNextSteps();
  }

  void _initDefaultParams() {
    switch (widget.shipment.stepCode) {
      case 'STEP_01':
        _param1Controller.text = 'MSC Mediterranean Shipping';
        _param2Controller.text = '2450.00';
        _param3Controller.text = '24 Days';
        break;
      case 'STEP_02':
        _param1Controller.text = '8471.30.00.00';
        _param2Controller.text = '5.0%';
        _param3Controller.text = '14.0%';
        break;
      case 'STEP_04':
        _param1Controller.text = '${widget.shipment.estimatedCost != null ? widget.shipment.estimatedCost!.toStringAsFixed(0) : "0"} ${widget.shipment.estimatedCostCurrency ?? "USD"}';
        _param2Controller.text = 'National Bank of Egypt (NBE)';
        _param3Controller.text = 'SWIFT-NBE-2026-9811';
        break;
      case 'STEP_05':
        _param1Controller.text = '2026081700981234567';
        _param2Controller.text = '180 Days';
        _param3Controller.text = 'MFG-REG-IT-88412';
        break;
      case 'STEP_06':
        _param1Controller.text = 'BKG-MSC-9981204';
        _param2Controller.text = 'MSC Oscar';
        _param3Controller.text = '2x 40ft High Cube';
        break;
      case 'STEP_12':
        _param1Controller.text = 'F4-2026-88192';
        _param2Controller.text = 'CIB Egypt';
        _param3Controller.text = '${widget.shipment.estimatedCost != null ? widget.shipment.estimatedCost!.toStringAsFixed(0) : "0"} USD';
        break;
      case 'STEP_13':
        _param1Controller.text = '46-ALX-2026-7781';
        _param2Controller.text = 'Alexandria Port';
        _param3Controller.text = 'Al-Ahram Clearance Group';
        break;
      case 'STEP_19':
        _param1Controller.text = 'GRN-WH-2026-0045';
        _param2Controller.text = 'Main Cairo Warehouse';
        _param3Controller.text = 'Fully Received / Sound Condition';
        break;
      default:
        _param1Controller.text = 'REF-${widget.shipment.importFileCode}';
        _param2Controller.text = 'Standard Approval';
        _param3Controller.text = 'Completed in good order';
    }
  }

  void _suggestNextSteps() {
    final cur = widget.shipment.stepCode;
    final normalized = (cur == 'STEP_08') ? 'STEP_08_PO' : cur;
    final index = _allStepCodes.indexOf(normalized);
    if (index >= 0 && index < _allStepCodes.length - 1) {
      _selectedNextSteps.add(_allStepCodes[index + 1]);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _param1Controller.dispose();
    _param2Controller.dispose();
    _param3Controller.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndAdvance() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final actionData = {
      'param1': _param1Controller.text.trim(),
      'param2': _param2Controller.text.trim(),
      'param3': _param3Controller.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    final notifier = ref.read(lifecycleBoardActionProvider.notifier);
    final success = await notifier.advanceStep(
      importFileCode: widget.shipment.importFileCode,
      currentStepCode: widget.shipment.stepCode,
      nextStepCodes: _selectedNextSteps,
      notes: _notesController.text.trim(),
      actionData: actionData,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Text(
              l10n.stepAdvanceSuccessSnack(_selectedNextSteps.join(', '), widget.shipment.importFileCode),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.crimson,
            content: Text(l10n.stepAdvanceErrorSnack),
          ),
        );
      }
    }
  }

  Future<void> _handleSkipStep() async {
    final l10n = context.l10n;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : null,
          title: Row(
            children: [
              const Icon(Icons.fast_forward_rounded, color: AppTheme.orange),
              const SizedBox(width: 8),
              Text(l10n.skipStepDialogTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 450,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.skipStepConfirmText(l10n.lifecycleStepName(widget.shipment.stepCode), widget.shipment.importFileCode),
                      style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: l10n.skipReasonLabel,
                        hintText: l10n.skipReasonHint,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: l10n.copyValue,
                          onPressed: () => CopyHelper.copy(ctx, reasonController.text),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? l10n.skipReasonRequired : null,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              icon: const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
              label: Text(l10n.confirmSkipAndAdvanceBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isSaving = true);
      final notifier = ref.read(lifecycleBoardActionProvider.notifier);
      final success = await notifier.skipStep(
        importFileCode: widget.shipment.importFileCode,
        currentStepCode: widget.shipment.stepCode,
        skipReason: reasonController.text.trim(),
        nextStepCodes: _selectedNextSteps,
      );
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.orange,
              content: Text(
                l10n.stepSkippedSuccessSnack(_selectedNextSteps.join(', '), widget.shipment.importFileCode),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        } else {
          // Surface the backend error (e.g. "blocked" policy, role restriction) to the user.
          final errorMsg = notifier.lastErrorMessage ?? l10n.stepAdvanceErrorSnack;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.crimson,
              duration: const Duration(seconds: 6),
              content: Text(
                errorMsg,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleHoldOrResume() async {
    final l10n = context.l10n;
    final isOnHold = widget.shipment.status == 'On-Hold';
    if (isOnHold) {
      setState(() => _isSaving = true);
      final notifier = ref.read(lifecycleBoardActionProvider.notifier);
      final success = await notifier.setMultiActiveStages(
        importFileCode: widget.shipment.importFileCode,
        activeStepCodes: [widget.shipment.stepCode],
        notes: 'Resumed workflow from active stage',
      );
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.emerald,
              content: Text(l10n.shipmentResumedSuccessSnack),
            ),
          );
        }
      }
    } else {
      final reasonController = TextEditingController();
      final formKey = GlobalKey<FormState>();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.darkSurface : null,
            title: Row(
              children: [
                const Icon(Icons.pause_circle_outline_rounded, color: AppTheme.crimson),
                const SizedBox(width: 8),
                Text(l10n.holdDialogTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
              ],
            ),
            content: SelectionArea(
              child: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.holdConfirmText(widget.shipment.importFileCode, l10n.lifecycleStepName(widget.shipment.stepCode)),
                        style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: l10n.holdReasonLabel,
                          hintText: l10n.holdReasonHint,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: l10n.copyValue,
                            onPressed: () => CopyHelper.copy(ctx, reasonController.text),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.holdReasonRequired : null,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 18),
                label: Text(l10n.confirmHoldBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      if (confirmed == true && mounted) {
        setState(() => _isSaving = true);
        final notifier = ref.read(lifecycleBoardActionProvider.notifier);
        final success = await notifier.advanceStep(
          importFileCode: widget.shipment.importFileCode,
          currentStepCode: widget.shipment.stepCode,
          nextStepCodes: [widget.shipment.stepCode],
          notes: 'On-Hold: ${reasonController.text.trim()}',
        );
        if (mounted) {
          setState(() => _isSaving = false);
          if (success) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.crimson,
                content: Text(l10n.shipmentHeldSuccessSnack),
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnHold = widget.shipment.status == 'On-Hold';
    final localizedStepName = l10n.lifecycleStepName(widget.shipment.stepCode);

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
        child: Container(
          width: 780,
          constraints: const BoxConstraints(maxHeight: 720),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune_outlined, color: AppTheme.cobalt, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.stepActionCardTitle(localizedStepName),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOnHold ? AppTheme.crimson : AppTheme.cobalt,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOnHold ? '${widget.shipment.stepCode} (${l10n.onHoldStatusTag})' : widget.shipment.stepCode,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            localizedStepName,
                            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Body Form
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shipment Info Pill
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              _buildInfoCol(l10n.importFileLabel, widget.shipment.importFileCode, isBold: true, color: AppTheme.cobalt),
                              _buildInfoCol(l10n.importingCompanyLabel, widget.shipment.companyName),
                              _buildInfoCol(l10n.foreignSupplierLabel, widget.shipment.supplierName),
                              _buildInfoCol(l10n.purchaseOrderLabel, widget.shipment.poNumber ?? 'N/A'),
                              _buildInfoCol(l10n.estimatedValueLabel, '${widget.shipment.estimatedCost != null ? widget.shipment.estimatedCost!.toStringAsFixed(0) : "-"} ${widget.shipment.estimatedCostCurrency ?? ""}', isBold: true, color: AppTheme.emerald),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Step-Specific Parameters Form
                        Text(
                          l10n.currentStepRequirementsHeader,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _param1Controller,
                                decoration: InputDecoration(
                                  labelText: l10n.stepParam1Label(widget.shipment.stepCode),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l10n.copyValue,
                                    onPressed: () => CopyHelper.copy(context, _param1Controller.text),
                                  ),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? l10n.requiredFieldValidation : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _param2Controller,
                                decoration: InputDecoration(
                                  labelText: l10n.stepParam2Label(widget.shipment.stepCode),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: l10n.copyValue,
                                    onPressed: () => CopyHelper.copy(context, _param2Controller.text),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _param3Controller,
                          decoration: InputDecoration(
                            labelText: l10n.stepParam3Label(widget.shipment.stepCode),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: l10n.copyValue,
                              onPressed: () => CopyHelper.copy(context, _param3Controller.text),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Next Step Multi-Target Picker (Supports Concurrent Multi-Stage)
                        Text(
                          l10n.targetNextPhasesHeader,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allStepCodes.map((stepCode) {
                            final isSelected = _selectedNextSteps.contains(stepCode);
                            return FilterChip(
                              backgroundColor: isDark ? AppTheme.darkCardBackground : null,
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                              label: Text(
                                '$stepCode: ${l10n.lifecycleStepName(stepCode)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppTheme.cobalt,
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedNextSteps.add(stepCode);
                                  } else {
                                    _selectedNextSteps.remove(stepCode);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // Notes & Live Updates
                        Text(
                          l10n.stepNotesHeader,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: l10n.stepNotesHint,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: l10n.copyValue,
                              onPressed: () => CopyHelper.copy(context, _notesController.text),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),

                // Action Buttons with Skip and Hold/Resume
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: Text(l10n.close),
                        ),
                        const SizedBox(width: 8),
                        // Skip Step Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.orange,
                            side: const BorderSide(color: AppTheme.orange),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: _isSaving ? null : _handleSkipStep,
                          icon: const Icon(Icons.fast_forward_rounded, size: 16),
                          label: Text(l10n.skipStepBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        // Hold / Resume Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isOnHold ? AppTheme.emerald : AppTheme.crimson,
                            side: BorderSide(color: isOnHold ? AppTheme.emerald : AppTheme.crimson),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: _isSaving ? null : _handleHoldOrResume,
                          icon: Icon(isOnHold ? Icons.play_arrow_rounded : Icons.pause_circle_outline_rounded, size: 16),
                          label: Text(isOnHold ? l10n.resumeShipmentBtn : l10n.holdShipmentBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isSaving ? null : _handleSaveAndAdvance,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                      label: Text(
                        _isSaving ? l10n.savingAndAdvancing : l10n.completeAndAdvanceBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, {bool isBold = false, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: () => CopyHelper.copy(context, value),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                        color: color ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.copy_rounded, size: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
