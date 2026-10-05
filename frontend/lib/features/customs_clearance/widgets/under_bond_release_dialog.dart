import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
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

  // Release Controllers
  final _bondRefController = TextEditingController(text: 'BOND-EG-2026-');
  final _quarantineLocController = TextEditingController();
  DateTime _releaseDate = DateTime.now();

  // Lab Controllers
  final _labCertController = TextEditingController(text: 'LAB-GOEIC-2026-');
  String _labVerdict = kLabConforming;
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

  void _snack(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: color, content: Text(text)),
    );
  }

  Future<void> _submitUnderBondRelease() async {
    final l = context.l10n;
    if (_isSubmitting) return;
    if (_bondRefController.text.trim().isEmpty || _quarantineLocController.text.trim().isEmpty) {
      _snack(l.underBondRequiredFieldsError, AppTheme.crimson);
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
        _snack(l.underBondReleaseSuccess, AppTheme.orange);
        widget.onDone?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      _snack(l.underBondActionError(ApiErrorText.of(l, e)), AppTheme.crimson);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitLabResult() async {
    final l = context.l10n;
    if (_isSubmitting) return;
    if (_labCertController.text.trim().isEmpty) {
      _snack(l.underBondLabCertRequiredError, AppTheme.crimson);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(customsClearanceProvider.notifier).recordLabTestResult(
            widget.clearanceId,
            buildLabResultPayload(
              verdict: _labVerdict,
              certificateNumber: _labCertController.text,
              completionDate: _testDate,
              remarks: _remarksController.text,
            ),
          );
      if (mounted) {
        final passed = _labVerdict == kLabConforming;
        _snack(
          passed ? l.underBondLabApprovedSuccess : l.underBondLabRejectedAlert,
          passed ? AppTheme.emerald : AppTheme.crimson,
        );
        widget.onDone?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      _snack(l.underBondLabResultError(ApiErrorText.of(l, e)), AppTheme.crimson);
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
                if (!_modeRecordLab) ...[
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

                // Mode 2: Lab Results & Lifting Form
                if (_modeRecordLab) ...[
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
                  ),
                  const SizedBox(height: 14),
                  SearchableDropdownField<String>(
                    key: const Key('underBondLabVerdictDropdown'),
                    value: _labVerdict,
                    isDense: false,
                    isRequired: true,
                    labelText: l.underBondLabVerdictLabel,
                    decoration: InputDecoration(
                      labelText: l.underBondLabVerdictLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      SearchableDropdownItem(value: kLabConforming, label: l.underBondLabVerdictPassed),
                      SearchableDropdownItem(value: kLabNonConforming, label: l.underBondLabVerdictRejected),
                    ],
                    onChanged: (v) => setState(() => _labVerdict = v ?? kLabConforming),
                  ),
                  const SizedBox(height: 14),
                  _dateField(l.ccTestCompletionDateLabel, _testDate, (d) => _testDate = d,
                      key: const Key('underBondTestDateField')),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _remarksController,
                    decoration: InputDecoration(
                      labelText: l.underBondLabRemarksLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    key: const Key('underBondLabSubmitBtn'),
                    label: _labVerdict == kLabConforming ? l.underBondApproveReleaseBtn : l.underBondRejectReleaseBtn,
                    icon: Icons.verified,
                    variant: _labVerdict == kLabConforming ? AppButtonVariant.success : AppButtonVariant.danger,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submitLabResult,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
