import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../models/freight_booking_model.dart';
import '../providers/freight_booking_provider.dart';
import 'freight_booking_ui.dart';

/// BK-01: confirm a booking with the carrier's real booking number, vessel
/// and sailing schedule.
class FreightBookingConfirmDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel booking;
  const FreightBookingConfirmDialog({super.key, required this.booking});

  @override
  ConsumerState<FreightBookingConfirmDialog> createState() => _FreightBookingConfirmDialogState();
}

class _FreightBookingConfirmDialogState extends ConsumerState<FreightBookingConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bookingNoController;
  late final TextEditingController _vesselNameController;
  late final TextEditingController _voyageNumberController;
  late final TextEditingController _freeDaysController;
  late final TextEditingController _notesController;

  DateTime? _selectedEtd;
  DateTime? _selectedEta;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bookingNoController = TextEditingController(text: widget.booking.bookingConfirmationNo ?? '');
    _vesselNameController = TextEditingController(text: widget.booking.vesselName ?? '');
    _voyageNumberController = TextEditingController(text: widget.booking.voyageNumber ?? '');
    _freeDaysController = TextEditingController(text: widget.booking.freeDemurrageDays.toString());
    _notesController = TextEditingController(text: widget.booking.notes ?? '');

    if (widget.booking.etd != null) {
      _selectedEtd = DateTime.tryParse(widget.booking.etd!);
    }
    if (widget.booking.eta != null) {
      _selectedEta = DateTime.tryParse(widget.booking.eta!);
    }
  }

  @override
  void dispose() {
    _bookingNoController.dispose();
    _vesselNameController.dispose();
    _voyageNumberController.dispose();
    _freeDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isEtd) async {
    final initial = isEtd ? (_selectedEtd ?? DateTime.now()) : (_selectedEta ?? DateTime.now().add(const Duration(days: 20)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isEtd) {
          _selectedEtd = picked;
        } else {
          _selectedEta = picked;
        }
      });
    }
  }

  Future<void> _submitConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);

    try {
      final payload = <String, dynamic>{
        'booking_confirmation_no': _bookingNoController.text.trim(),
        'vessel_name': _vesselNameController.text.trim().isNotEmpty ? _vesselNameController.text.trim() : null,
        'voyage_number': _voyageNumberController.text.trim().isNotEmpty ? _voyageNumberController.text.trim() : null,
        if (_selectedEtd != null) 'etd': _selectedEtd!.toIso8601String(),
        if (_selectedEta != null) 'eta': _selectedEta!.toIso8601String(),
        'free_demurrage_days': int.tryParse(_freeDaysController.text.trim()) ?? 14,
        'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      };

      await ref.read(freightBookingProvider.notifier).confirmBooking(widget.booking.bookingId, payload);

      if (mounted) {
        Navigator.pop(context);
        FbkUi.snack(context, l.fbkConfirmSuccess, severity: AppSeverity.success);
      }
    } catch (e) {
      if (mounted) {
        FbkUi.snack(context, l.fbkConfirmError(ApiErrorText.of(l, e)), severity: AppSeverity.danger);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.booking;

    return CcStageDialogShell(
      title: l.fbkConfirmTitle,
      icon: Icons.verified,
      accent: AppTheme.emerald,
      maxWidth: 680,
      chips: [
        CcHeaderChip(Icons.tag, b.bookingCode, ltr: true),
        CcHeaderChip(Icons.directions_boat_outlined, FbkFormat.orDash(b.shippingLineName ?? b.freightForwarderName)),
      ],
      isSubmitting: _isSubmitting,
      confirmKey: const Key('confirmBookingSubmitBtn'),
      confirmLabel: l.fbkConfirmBtn,
      confirmIcon: Icons.verified,
      onConfirm: _submitConfirm,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FbkNotice(message: l.fbkConfirmInfo, severity: AppSeverity.info, icon: Icons.info_outline),
            const SizedBox(height: 16),
            CcFormSection(
              title: l.fbkSectionFile,
              icon: Icons.confirmation_number_outlined,
              child: Column(
                children: [
                  CcField(
                    label: l.fbkConfirmNoLabel,
                    child: TextFormField(
                      key: const Key('bookingConfirmNoInput'),
                      controller: _bookingNoController,
                      textDirection: TextDirection.ltr,
                      decoration: ccInputDecoration(prefix: Icons.confirmation_number_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty) ? l.fbkConfirmNoValidator : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CcFieldRow(
                    children: [
                      CcField(
                        label: l.freightBookingVesselNameInput,
                        child: TextFormField(
                          key: const Key('bookingVesselNameInput'),
                          controller: _vesselNameController,
                          decoration: ccInputDecoration(prefix: Icons.directions_boat_filled_outlined),
                        ),
                      ),
                      CcField(
                        label: l.freightBookingVoyageNoInput,
                        child: TextFormField(
                          key: const Key('bookingVoyageNoInput'),
                          controller: _voyageNumberController,
                          textDirection: TextDirection.ltr,
                          decoration: ccInputDecoration(prefix: Icons.tag),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CcFormSection(
              title: l.fbkSectionSchedule,
              icon: Icons.event_note,
              child: Column(
                children: [
                  CcFieldRow(
                    children: [
                      CcField(
                        label: l.freightBookingEtdLabel,
                        child: CcDateTile(
                          date: _selectedEtd,
                          placeholder: l.fbkSelectDate,
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      CcField(
                        label: l.freightBookingEtaLabel,
                        child: CcDateTile(
                          date: _selectedEta,
                          placeholder: l.fbkSelectDate,
                          onTap: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CcField(
                    label: l.fbkConfirmFreeDaysLabel,
                    child: TextFormField(
                      key: const Key('bookingFreeDaysInput'),
                      controller: _freeDaysController,
                      keyboardType: TextInputType.number,
                      decoration: ccInputDecoration(prefix: Icons.timelapse_outlined, suffixText: l.fbkDaysSuffix),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return l.fbkConfirmFreeDaysRequired;
                        final parsed = int.tryParse(v.trim());
                        if (parsed == null || parsed < 0) return l.fbkValidatorFreeDays;
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CcField(
              label: l.fbkNotesOptional,
              child: TextFormField(
                key: const Key('bookingNotesInput'),
                controller: _notesController,
                maxLines: 2,
                decoration: ccInputDecoration(prefix: Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
