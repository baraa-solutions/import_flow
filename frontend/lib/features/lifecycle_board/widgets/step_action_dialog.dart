import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/lifecycle_board_model.dart';
import '../providers/lifecycle_board_provider.dart';
import 'step_action/step_action_dialog_handlers.dart';
import 'step_action/step_action_info_pill.dart';
import 'step_action/step_action_param_fields.dart';

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
        _param1Controller.text = (widget.shipment.estimatedCost != null && widget.shipment.estimatedCostCurrency != null)
            ? '${widget.shipment.estimatedCost!.toStringAsFixed(0)} ${widget.shipment.estimatedCostCurrency!}'
            : '';
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
        _param3Controller.text = (widget.shipment.estimatedCost != null && widget.shipment.estimatedCostCurrency != null)
            ? '${widget.shipment.estimatedCost!.toStringAsFixed(0)} ${widget.shipment.estimatedCostCurrency!}'
            : '';
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isOnHold = widget.shipment.status == 'On-Hold';
    final localizedStepName = l10n.lifecycleStepName(widget.shipment.stepCode);

    return SelectionArea(
      child: Dialog(
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
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
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
                              Flexible(
                                child: Text(
                                  l10n.stepActionCardTitle(localizedStepName),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryOf(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppStatusBadge(
                                label: isOnHold
                                    ? '${widget.shipment.stepCode} (${l10n.onHoldStatusTag})'
                                    : widget.shipment.stepCode,
                                severity: isOnHold ? AppSeverity.danger : AppSeverity.info,
                                size: AppStatusBadgeSize.small,
                              ),
                            ],
                          ),
                          Text(
                            localizedStepName,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context),
                            ),
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
                        StepActionInfoPill(shipment: widget.shipment),
                        const SizedBox(height: 18),

                        // Step-Specific Parameters Form & Next Step Target Picker
                        StepActionParamFields(
                          stepCode: widget.shipment.stepCode,
                          param1Controller: _param1Controller,
                          param2Controller: _param2Controller,
                          param3Controller: _param3Controller,
                          notesController: _notesController,
                          allStepCodes: _allStepCodes,
                          selectedNextSteps: _selectedNextSteps,
                          onToggleNextStep: (sCode, selected) {
                            setState(() {
                              if (selected) {
                                _selectedNextSteps.add(sCode);
                              } else {
                                _selectedNextSteps.remove(sCode);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),

                // Action Buttons with Skip and Hold/Resume
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: Text(l10n.close),
                        ),
                        // Skip Step Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.orange,
                            side: const BorderSide(color: AppTheme.orange),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () => StepActionDialogHandlers.handleSkipStep(
                                    context: context,
                                    ref: ref,
                                    shipment: widget.shipment,
                                    selectedNextSteps: _selectedNextSteps,
                                    setSaving: (val) => setState(() => _isSaving = val),
                                  ),
                          icon: const Icon(Icons.fast_forward_rounded, size: 16),
                          label: Text(l10n.skipStepBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        // Hold / Resume Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isOnHold ? AppTheme.emerald : AppTheme.crimson,
                            side: BorderSide(color: isOnHold ? AppTheme.emerald : AppTheme.crimson),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () => StepActionDialogHandlers.handleHoldOrResume(
                                    context: context,
                                    ref: ref,
                                    shipment: widget.shipment,
                                    setSaving: (val) => setState(() => _isSaving = val),
                                  ),
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
}
