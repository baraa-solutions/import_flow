import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/localization/stored_text.dart';

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

  // Lab Controllers
  final _labCertController = TextEditingController(text: 'LAB-GOEIC-2026-');
  String _labVerdict = 'PASSED';
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

  Future<void> _submitUnderBondRelease() async {
    final l = context.l10n;
    if (_bondRefController.text.trim().isEmpty || _quarantineLocController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.underBondRequiredFieldsError)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'bond_guarantee_ref': _bondRefController.text.trim(),
        'quarantine_location': _quarantineLocController.text.trim(),
      };

      await dio.post('/customs-clearance/${widget.clearanceId}/under-bond-release', data: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.orange,
            content: Text(l.underBondReleaseSuccess),
          ),
        );
        widget.onDone?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.crimson, content: Text(l.underBondActionError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitLabResult() async {
    final l = context.l10n;
    if (_labCertController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.underBondLabCertRequiredError)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'lab_certificate_number': _labCertController.text.trim(),
        'is_lab_passed': _labVerdict == 'PASSED',
        'remarks': _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
      };

      await dio.post('/customs-clearance/${widget.clearanceId}/lab-inspection-result', data: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _labVerdict == 'PASSED' ? AppTheme.emerald : AppTheme.crimson,
            content: Text(
              _labVerdict == 'PASSED'
                  ? l.underBondLabApprovedSuccess
                  : l.underBondLabRejectedAlert,
            ),
          ),
        );
        widget.onDone?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.crimson, content: Text(l.underBondLabResultError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        color: AppTheme.orange.withOpacity(0.12),
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
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                          ),
                          Text(
                            l.underBondReleaseDeclSubtitle(widget.declarationNo),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.orange.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.orange, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.underBondInfoBanner,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.charcoal, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
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
                  TextFormField(
                    controller: _quarantineLocController,
                    decoration: InputDecoration(
                      labelText: l.underBondQuarantineLocLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitUnderBondRelease,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: Text(l.underBondConfirmReleaseBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],

                // Mode 2: Lab Results & Lifting Form
                if (_modeRecordLab) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cobalt.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.science_outlined, color: AppTheme.cobalt, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.underBondLabInfoBanner,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.charcoal, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
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
                  DropdownButtonFormField<String>(
                    value: _labVerdict,
                    decoration: InputDecoration(
                      labelText: l.underBondLabVerdictLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'PASSED', child: Text(l.underBondLabVerdictPassed)),
                      DropdownMenuItem(value: 'REJECTED', child: Text(l.underBondLabVerdictRejected)),
                    ],
                    onChanged: (v) => setState(() => _labVerdict = v ?? 'PASSED'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _remarksController,
                    decoration: InputDecoration(
                      labelText: l.underBondLabRemarksLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitLabResult,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.verified, color: Colors.white),
                    label: Text(
                      _labVerdict == 'PASSED' ? l.underBondApproveReleaseBtn : l.underBondRejectReleaseBtn,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _labVerdict == 'PASSED' ? AppTheme.emerald : AppTheme.crimson,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
