import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../models/demurrage_model.dart';
import '../../providers/demurrage_provider.dart';
import 'ancillary_fees_section.dart';
import 'demurrage_lookups.dart';

/// Record / correct the gate-out and empty-return dates of a tracking.
class UpdateTrackingDatesDialog extends ConsumerStatefulWidget {
  const UpdateTrackingDatesDialog({super.key, required this.item});

  final DemurrageTrackingModel item;

  static Future<void> show(BuildContext context, DemurrageTrackingModel item) =>
      showDialog<void>(context: context, builder: (_) => UpdateTrackingDatesDialog(item: item));

  @override
  ConsumerState<UpdateTrackingDatesDialog> createState() => _UpdateTrackingDatesDialogState();
}

class _UpdateTrackingDatesDialogState extends ConsumerState<UpdateTrackingDatesDialog> {
  late DateTime? _gateOut;
  late DateTime? _emptyReturn;
  late final DateTime _discharge;
  bool _isSaving = false;
  late List<Map<String, dynamic>> _ancillaryFees;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _gateOut = item.gateOutDate != null ? DateTime.tryParse(item.gateOutDate!) : null;
    _emptyReturn = item.emptyReturnDate != null ? DateTime.tryParse(item.emptyReturnDate!) : null;
    _discharge = DateTime.tryParse(item.dischargeDate) ?? DateTime.now();
    _ancillaryFees = item.ancillaryFees
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_emptyReturn != null && _gateOut == null) {
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          'لا يمكن تسجيل إعادة الحاوية الفارغة بدون تاريخ خروجها من الميناء.',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await ref.read(demurrageProvider.notifier).updateTrackingDates(
          widget.item.trackingId,
          gateOutDate: _gateOut != null ? fmtDemurrageDate(_gateOut!) : null,
          emptyReturnDate: _emptyReturn != null ? fmtDemurrageDate(_emptyReturn!) : null,
          ancillaryFees: _ancillaryFees,
        );
    final error = ref.read(demurrageProvider).errorObject;
    if (!mounted) return;
    final snack = AppTheme.snackBar(
      context,
      ok ? l.datesUpdatedAndRecalculatedSuccessSnack : ApiErrorText.of(l, error, fallback: l.datesUpdateErrorSnack),
      severity: ok ? AppSeverity.success : AppSeverity.danger,
    );
    if (ok) {
      navigator.pop();
    } else {
      setState(() => _isSaving = false);
    }
    messenger.showSnackBar(snack);
  }

  Future<DateTime?> _pick(DateTime initial, DateTime first) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: DateTime(2030),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final item = widget.item;
    return SelectionArea(
      child: CcStageDialogShell(
        title: l.updateTrackingDatesDialogTitle(item.trackingCode),
        icon: Icons.edit_calendar_outlined,
        maxWidth: 620,
        chips: [
          CcHeaderChip(Icons.tag, item.trackingCode, ltr: true),
          CcHeaderChip(Icons.directions_boat_outlined, item.carrierName),
        ],
        confirmLabel: l.saveAndRecalculateBtn,
        confirmVariant: AppButtonVariant.primary,
        confirmIcon: Icons.calculate_outlined,
        isSubmitting: _isSaving,
        onConfirm: _submit,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CcFormSection(
              title: l.updateGateOutAndReturnDatesBtn,
              icon: Icons.event_available_outlined,
              child: Column(
                children: [
                  CcField(
                    label: l.gateOutDateTile,
                    child: CcDateTile(
                      date: _gateOut,
                      placeholder: l.notRecordedOption,
                      onTap: () async {
                        final picked = await _pick(_gateOut ?? _discharge, _discharge);
                        if (picked != null) setState(() => _gateOut = picked);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  CcField(
                    label: l.emptyReturnDateTile,
                    child: CcDateTile(
                      date: _emptyReturn,
                      placeholder: l.notRecordedOption,
                      onTap: () async {
                        final picked = await _pick(_emptyReturn ?? (_gateOut ?? _discharge), _gateOut ?? _discharge);
                        if (picked != null) setState(() => _emptyReturn = picked);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AncillaryFeesSection(
              fees: _ancillaryFees,
              onFeesChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
