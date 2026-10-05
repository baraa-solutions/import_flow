import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../models/freight_booking_model.dart';
import '../providers/freight_booking_provider.dart';
import 'freight_booking_ui.dart';

/// SH-01: confirm the actual sailing (ATD), issue / update the B/L number and
/// the revised ETA of a confirmed or sailed booking.
class DepartureConfirmationDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel booking;

  const DepartureConfirmationDialog({
    super.key,
    required this.booking,
  });

  static Future<bool?> show(
    BuildContext context,
    ShipmentBookingModel booking,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DepartureConfirmationDialog(booking: booking),
    );
  }

  @override
  ConsumerState<DepartureConfirmationDialog> createState() => _DepartureConfirmationDialogState();
}

class _DepartureConfirmationDialogState extends ConsumerState<DepartureConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bolController;
  late TextEditingController _vesselController;
  late TextEditingController _voyageController;
  late TextEditingController _notesController;

  DateTime _actualDepartureDate = DateTime.now();
  DateTime? _revisedEta;
  DateTime? _shippedOnBoardDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _bolController = TextEditingController(text: b.billOfLadingNo ?? '');
    _vesselController = TextEditingController(text: b.vesselName ?? '');
    _voyageController = TextEditingController(text: b.voyageNumber ?? '');
    _notesController = TextEditingController();

    if (b.atd != null) {
      final parsed = DateTime.tryParse(b.atd!);
      if (parsed != null) _actualDepartureDate = parsed;
    } else if (b.etd != null) {
      final parsed = DateTime.tryParse(b.etd!);
      if (parsed != null) _actualDepartureDate = parsed;
    }

    if (b.eta != null) {
      _revisedEta = DateTime.tryParse(b.eta!);
    } else {
      _revisedEta = _actualDepartureDate.add(Duration(days: b.transitTimeDays > 0 ? b.transitTimeDays : 15));
    }
  }

  @override
  void dispose() {
    _bolController.dispose();
    _vesselController.dispose();
    _voyageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _calculatedDelayDays {
    if (widget.booking.etd == null) return 0;
    final etdDate = DateTime.tryParse(widget.booking.etd!);
    if (etdDate == null) return 0;
    final diff = _actualDepartureDate.difference(etdDate).inDays;
    return diff > 0 ? diff : 0;
  }

  int get _calculatedTransitDays {
    if (_revisedEta == null) return widget.booking.transitTimeDays;
    final diff = _revisedEta!.difference(_actualDepartureDate).inDays;
    return diff > 0 ? diff : 0;
  }

  Future<void> _selectDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2035),
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);

    setState(() => _isSubmitting = true);
    try {
      final payload = <String, dynamic>{
        'actual_departure_date': _actualDepartureDate.toIso8601String(),
        'bill_of_lading_no': _bolController.text.trim(),
        if (_revisedEta != null) 'revised_eta': _revisedEta!.toIso8601String(),
        if (_vesselController.text.trim().isNotEmpty) 'vessel_name': _vesselController.text.trim(),
        if (_voyageController.text.trim().isNotEmpty) 'voyage_number': _voyageController.text.trim(),
        if (_shippedOnBoardDate != null)
          'shipped_on_board_date': _shippedOnBoardDate!.toIso8601String().substring(0, 10),
        if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
      };

      await ref.read(freightBookingProvider.notifier).confirmDepartureAndBol(
            widget.booking.bookingId,
            payload,
          );

      ref.invalidate(importFilesProvider);
      ref.invalidate(smartTasksProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l.fbkDepSuccess(_bolController.text.trim()),
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        FbkUi.snack(context, l.fbkDepError(ApiErrorText.of(l, e)), severity: AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.booking;
    final delayDays = _calculatedDelayDays;
    final transitDays = _calculatedTransitDays;
    final fileCode = b.importFileCode ?? (b.importFileId != null ? 'IMP-${b.importFileId}' : l.fbkDepNotLinked);

    return CcStageDialogShell(
      title: l.fbkDepTitle,
      icon: Icons.sailing_rounded,
      maxWidth: 720,
      chips: [
        CcHeaderChip(Icons.tag, b.bookingConfirmationNo ?? b.bookingCode, ltr: true),
        CcHeaderChip(Icons.folder_special, fileCode, ltr: true),
      ],
      isSubmitting: _isSubmitting,
      confirmKey: const Key('fbkDepartureConfirmBtn'),
      confirmLabel: l.fbkDepBtn,
      loadingLabel: l.fbkDepBtnBusy,
      confirmVariant: AppButtonVariant.primary,
      onConfirm: _onSubmit,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _context(context, l, delayDays),
            const SizedBox(height: 14),
            CcFormSection(
              title: l.fbkDepSectionBl,
              icon: Icons.receipt_long,
              child: Column(
                children: [
                  CcField(
                    label: l.fbkDepBolLabel,
                    child: TextFormField(
                      controller: _bolController,
                      textDirection: TextDirection.ltr,
                      decoration: ccInputDecoration(prefix: Icons.receipt_long),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return l.fbkDepBolRequired;
                        if (v.trim().length < 3) return l.fbkDepBolShort;
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  CcFieldRow(
                    children: [
                      CcField(
                        label: l.fbkDepAtdLabel,
                        child: CcDateTile(
                          date: _actualDepartureDate,
                          onTap: () => _selectDate(
                            initialDate: _actualDepartureDate,
                            onSelected: (d) => _actualDepartureDate = d,
                          ),
                        ),
                      ),
                      CcField(
                        label: l.fbkDepRevisedEtaLabel,
                        child: CcDateTile(
                          date: _revisedEta,
                          placeholder: l.fbkDepAuto,
                          onTap: () => _selectDate(
                            initialDate: _revisedEta ?? _actualDepartureDate.add(const Duration(days: 15)),
                            firstDate: _actualDepartureDate,
                            onSelected: (d) => _revisedEta = d,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CcField(
                    label: l.fbkDepSobLabel,
                    child: CcDateTile(
                      date: _shippedOnBoardDate,
                      placeholder: l.fbkDepSobSameAsAtd(CcFormat.date(_actualDepartureDate)),
                      onTap: () => _selectDate(
                        initialDate: _shippedOnBoardDate ?? _actualDepartureDate,
                        onSelected: (d) => _shippedOnBoardDate = d,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CcFormSection(
              title: l.fbkSectionVessel,
              icon: Icons.directions_boat_filled_outlined,
              child: Column(
                children: [
                  CcFieldRow(
                    children: [
                      CcField(
                        label: l.freightBookingVesselNameInput,
                        child: TextFormField(
                          controller: _vesselController,
                          decoration: ccInputDecoration(prefix: Icons.directions_boat_filled_outlined),
                        ),
                      ),
                      CcField(
                        label: l.freightBookingVoyageNoInput,
                        child: TextFormField(
                          controller: _voyageController,
                          textDirection: TextDirection.ltr,
                          decoration: ccInputDecoration(prefix: Icons.tag),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CcField(
                    label: l.fbkDepNotesLabel,
                    child: TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: ccInputDecoration(hint: l.fbkDepNotesHint(transitDays)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CcSectionCard(
              title: l.fbkDepAutoTitle,
              icon: Icons.auto_awesome,
              margin: EdgeInsetsDirectional.zero,
              child: Text(
                l.fbkDepAutoBody,
                style: TextStyle(fontSize: 11.5, height: 1.5, color: AppTheme.textSecondaryOf(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carrier / route of the booking and the on-schedule or delay indicator.
  Widget _context(BuildContext context, AppLocalizations l, int delayDays) {
    final b = widget.booking;
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.fbkDepCarrier(FbkFormat.orDash(b.shippingLineName)),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimaryOf(context)),
              ),
              const SizedBox(height: 2),
              Text(
                l.fbkDepRoute(FbkFormat.orDash(b.polName), FbkFormat.orDash(b.podName)),
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
              ),
            ],
          ),
          if (delayDays > 0)
            CcStatusChip(
              label: l.fbkDepDelayed(delayDays),
              severity: AppSeverity.warning,
              icon: Icons.warning_amber_rounded,
            )
          else
            CcStatusChip(
              label: l.fbkDepOnSchedule,
              severity: AppSeverity.success,
              icon: Icons.check_circle_outline,
            ),
        ],
      ),
    );
  }
}
