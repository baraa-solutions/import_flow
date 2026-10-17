import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../providers/customs_clearance_provider.dart';

/// Lab verdict codes accepted by `POST /customs-clearance/{id}/lab-test-result`.
const String kLabConforming = 'CONFORMING';
const String kLabNonConforming = 'NON_CONFORMING';

/// Payload of `POST /customs-clearance/{id}/under-bond-release`.
Map<String, dynamic> buildUnderBondPayload({
  required String bondRef,
  required DateTime releaseDate,
  required String warehouseLocation,
}) =>
    {
      'bond_guarantee_ref': bondRef.trim(),
      'temporary_release_date': releaseDate.toIso8601String(),
      'customs_warehouse_location': warehouseLocation.trim(),
    };

/// Payload of `POST /customs-clearance/{id}/lab-test-result`.
Map<String, dynamic> buildLabResultPayload({
  required String verdict,
  required String certificateNumber,
  required DateTime completionDate,
  String? remarks,
}) =>
    {
      'lab_test_result': verdict,
      'lab_certificate_number': certificateNumber.trim(),
      'test_completion_date': completionDate.toIso8601String(),
      'lift_quarantine_lock': true,
      'remarks': (remarks ?? '').trim().isNotEmpty ? remarks!.trim() : null,
    };

void showUnderBondReleaseDialog(BuildContext context, WidgetRef ref, {
  required int clearanceId,
  required String declarationNo,
  bool isAlreadyUnderBond = false,
  VoidCallback? onDone,
}) {
  showDialog(
    context: context,
    builder: (ctx) => UnderBondReleaseDialog(
      clearanceId: clearanceId,
      declarationNo: declarationNo,
      isAlreadyUnderBond: isAlreadyUnderBond,
      onDone: onDone,
    ),
  );
}

class UnderBondReleaseDialog extends ConsumerStatefulWidget {
  final int clearanceId;
  final String declarationNo;
  final bool isAlreadyUnderBond;
  final VoidCallback? onDone;

  const UnderBondReleaseDialog({
    super.key,
    required this.clearanceId,
    required this.declarationNo,
    this.isAlreadyUnderBond = false,
    this.onDone,
  });

  @override
  ConsumerState<UnderBondReleaseDialog> createState() => _UnderBondReleaseDialogState();
}

class _UnderBondReleaseDialogState extends ConsumerState<UnderBondReleaseDialog> {
  late bool _modeRecordLab;

  final _formKeyRelease = GlobalKey<FormState>();
  final _formKeyLab = GlobalKey<FormState>();

  // Release Controllers
  final _bondRefController = TextEditingController();
  final _quarantineLocController = TextEditingController();
  DateTime _releaseDate = DateTime.now();

  // Lab Controllers
  final _labCertController = TextEditingController();
  String? _labVerdict;
  DateTime _testDate = DateTime.now();
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  bool _initializedDefaults = false;

  @override
  void initState() {
    super.initState();
    _modeRecordLab = widget.isAlreadyUnderBond;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedDefaults) {
      _initializedDefaults = true;
      if (_quarantineLocController.text.isEmpty) {
        _quarantineLocController.text = storedText.underBondDefaultQuarantineLoc;
      }
    }
  }

  @override
  void dispose() {
    _bondRefController.dispose();
    _quarantineLocController.dispose();
    _labCertController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _snack(String text, AppSeverity severity) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, text, severity: severity),
    );
  }

  Future<void> _submitUnderBondRelease() async {
    final l = context.l10n;
    if (_isSubmitting) return;
    if (!(_formKeyRelease.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(customsClearanceProvider.notifier).releaseUnderBond(
            widget.clearanceId,
            buildUnderBondPayload(
              bondRef: _bondRefController.text,
              releaseDate: _releaseDate,
              warehouseLocation: _quarantineLocController.text,
            ),
          );
      if (mounted) {
        _snack(l.underBondReleaseSuccess, AppSeverity.warning);
        widget.onDone?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _snack(l.underBondActionError(ApiErrorText.of(l, e)), AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitLabResult() async {
    final l = context.l10n;
    if (_isSubmitting) return;
    if (!(_formKeyLab.currentState?.validate() ?? false)) {
      return;
    }
    final verdict = _labVerdict;
    if (verdict == null) return;

    if (verdict == kLabConforming) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.underBondConfirmLiftTitle),
          content: Text(l.underBondConfirmLiftBody),
          actions: [
            TextButton(
              key: const Key('underBondConfirmLiftCancelBtn'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.underBondConfirmLiftCancel),
            ),
            AppButton(
              key: const Key('underBondConfirmLiftConfirmBtn'),
              label: l.underBondConfirmLiftConfirm,
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(customsClearanceProvider.notifier).recordLabTestResult(
            widget.clearanceId,
            buildLabResultPayload(
              verdict: verdict,
              certificateNumber: _labCertController.text,
              completionDate: _testDate,
              remarks: _remarksController.text,
            ),
          );
      if (mounted) {
        final passed = verdict == kLabConforming;
        _snack(
          passed ? l.underBondLabApprovedSuccess : l.underBondLabRejectedAlert,
          passed ? AppSeverity.success : AppSeverity.danger,
        );
        widget.onDone?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _snack(l.underBondLabResultError(ApiErrorText.of(l, e)), AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onPicked, {Key? key}) {
    final text = '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return InkWell(
      key: key,
      onTap: _isSubmitting
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => onPicked(picked));
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _banner(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimaryOf(context), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      child: SelectionArea(
        child: Container(
          width: 680,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_clock_outlined, color: AppTheme.orange, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.underBondReleaseDialogTitle,
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                          ),
                          Text(
                            l.underBondReleaseDeclSubtitle(widget.declarationNo),
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 18),

                // Mode Selector
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l.underBondModeUnderBond),
                      icon: const Icon(Icons.assignment_returned_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(l.underBondModeLabVerdict),
                      icon: const Icon(Icons.science_outlined),
                    ),
                  ],
                  selected: {_modeRecordLab},
                  onSelectionChanged: (val) => setState(() => _modeRecordLab = val.first),
                ),
                const SizedBox(height: 20),

                // Mode 1: Under-Bond Release Form
                if (!_modeRecordLab)
                  Form(
                    key: _formKeyRelease,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _banner(Icons.info_outline, AppTheme.orange, l.underBondInfoBanner),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('underBondRefField'),
                          controller: _bondRefController,
                          decoration: InputDecoration(
                            labelText: l.underBondGuaranteeRefLabel,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: l.customsClearanceCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(context, _bondRefController.text),
                            ),
                          ),
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) {
                              return l.underBondRefRequired;
                            }
                            if (text.length < 3) {
                              return l.underBondRefMinLength;
                            }
                            if (text == 'BOND-EG-2026-' || text == 'BOND-EG-' || text == 'BOND-') {
                              return l.underBondRefInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _dateField(l.ccBondReleaseDateLabel, _releaseDate, (d) => _releaseDate = d,
                            key: const Key('underBondReleaseDateField')),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('underBondLocationField'),
                          controller: _quarantineLocController,
                          decoration: InputDecoration(
                            labelText: l.underBondQuarantineLocLabel,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) {
                              return l.underBondLocationRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          key: const Key('underBondConfirmBtn'),
                          label: l.underBondConfirmReleaseBtn,
                          icon: Icons.check_circle_outline,
                          variant: AppButtonVariant.warning,
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submitUnderBondRelease,
                        ),
                      ],
                    ),
                  ),

                // Mode 2: Lab Results & Lifting Form
                if (_modeRecordLab)
                  Form(
                    key: _formKeyLab,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _banner(Icons.science_outlined, AppTheme.cobalt, l.underBondLabInfoBanner),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('underBondLabCertField'),
                          controller: _labCertController,
                          decoration: InputDecoration(
                            labelText: l.underBondLabCertLabel,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: l.customsClearanceCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(context, _labCertController.text),
                            ),
                          ),
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) {
                              return l.underBondCertRequired;
                            }
                            if (text.length < 3) {
                              return l.underBondCertMinLength;
                            }
                            if (text == 'LAB-GOEIC-2026-' || text == 'LAB-GOEIC-' || text == 'LAB-') {
                              return l.underBondCertInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        FormField<String>(
                          key: const Key('underBondLabVerdictField'),
                          initialValue: _labVerdict,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return l.underBondLabVerdictRequired;
                            }
                            return null;
                          },
                          builder: (fieldState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.underBondLabVerdictLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: fieldState.hasError ? AppTheme.crimson : AppTheme.textPrimaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                IgnorePointer(
                                  ignoring: _isSubmitting,
                                  child: RadioGroup<String>(
                                    groupValue: _labVerdict,
                                    onChanged: (val) {
                                      if (_isSubmitting) return;
                                      setState(() => _labVerdict = val);
                                      fieldState.didChange(val);
                                    },
                                    child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      RadioListTile<String>(
                                        key: const Key('underBondVerdictConformingRadio'),
                                        title: Text(l.underBondLabVerdictPassed),
                                        value: kLabConforming,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                      RadioListTile<String>(
                                        key: const Key('underBondVerdictNonConformingRadio'),
                                        title: Text(l.underBondLabVerdictRejected),
                                        value: kLabNonConforming,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (fieldState.hasError)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
                                    child: Text(
                                      fieldState.errorText!,
                                      style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _dateField(l.ccTestCompletionDateLabel, _testDate, (d) => _testDate = d,
                            key: const Key('underBondTestDateField')),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('underBondRemarksField'),
                          controller: _remarksController,
                          decoration: InputDecoration(
                            labelText: l.underBondLabRemarksLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          key: const Key('underBondLabSubmitBtn'),
                          label: _labVerdict == kLabConforming
                              ? l.underBondApproveReleaseBtn
                              : (_labVerdict == kLabNonConforming ? l.underBondRejectReleaseBtn : l.underBondModeLabVerdict),
                          icon: _labVerdict == kLabNonConforming ? Icons.cancel_outlined : Icons.verified,
                          variant: _labVerdict == kLabConforming
                              ? AppButtonVariant.success
                              : (_labVerdict == kLabNonConforming ? AppButtonVariant.danger : AppButtonVariant.primary),
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submitLabResult,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
