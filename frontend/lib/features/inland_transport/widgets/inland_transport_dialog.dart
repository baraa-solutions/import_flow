import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';
import '../models/inland_transport_model.dart';
import '../providers/inland_transport_provider.dart';
import 'transport_dialog/inland_transport_actions_bar.dart';
import 'transport_dialog/inland_transport_cost_card.dart';
import 'transport_dialog/inland_transport_dialogs.dart';
import 'transport_dialog/inland_transport_header.dart';
import 'transport_dialog/inland_transport_trucking_card.dart';

export 'transport_dialog/inland_transport_actions_bar.dart';
export 'transport_dialog/inland_transport_cost_card.dart';
export 'transport_dialog/inland_transport_dialogs.dart';
export 'transport_dialog/inland_transport_header.dart';
export 'transport_dialog/inland_transport_trucking_card.dart';

/// TR-01 Modal Dialog: Inland Transport Coordination.
class InlandTransportDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const InlandTransportDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(BuildContext context, ImportFileModel file) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InlandTransportDialog(file: file),
    );
  }

  @override
  ConsumerState<InlandTransportDialog> createState() => _InlandTransportDialogState();
}

class _InlandTransportDialogState extends ConsumerState<InlandTransportDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showBookingForm = false;
  bool _isEditing = false;
  Object? _loadError;
  InlandTransportModel? _existingBooking;

  int? _carrierId;
  late final InlandBookingControllers _controllers;
  late final TextEditingController _gateOutNotesController;
  late final TextEditingController _gatePassNoController;
  late final TextEditingController _arrivalNotesController;
  late final TextEditingController _sealNumberController;
  bool _sealIntact = true;

  String _truckType = 'FLATBED';
  DateTime _plannedDepartureDate = DateTime.now();
  TimeOfDay _plannedDepartureTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _expectedArrivalDate = DateTime.now().add(const Duration(hours: 6));
  TimeOfDay _expectedArrivalTime = const TimeOfDay(hour: 16, minute: 0);

  @override
  void initState() {
    super.initState();
    _controllers = InlandBookingControllers()..initFromFile(widget.file);
    _gateOutNotesController = TextEditingController();
    _gatePassNoController = TextEditingController();
    _arrivalNotesController = TextEditingController();
    _sealNumberController = TextEditingController();
    _loadBookingData();
  }

  @override
  void dispose() {
    _controllers.dispose();
    _gateOutNotesController.dispose();
    _gatePassNoController.dispose();
    _arrivalNotesController.dispose();
    _sealNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final booking = await ref.read(inlandTransportProvider.notifier).fetchBookingByFile(widget.file.importFileId);
      if (!mounted) return;
      setState(() {
        _existingBooking = booking;
        _isEditing = false;
        if (booking != null) {
          _showBookingForm = false;
          _carrierId = booking.carrierId;
          _controllers.initFromBooking(booking);
          _truckType = DomainEnums.initialCode(DomainEnumType.truckType, booking.truckType, booking.truckType);
          if (booking.plannedDepartureAt.isNotEmpty) {
            final dt = DateTime.tryParse(booking.plannedDepartureAt);
            if (dt != null) {
              _plannedDepartureDate = dt;
              _plannedDepartureTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
            }
          }
          if (booking.expectedArrivalAt.isNotEmpty) {
            final dt = DateTime.tryParse(booking.expectedArrivalAt);
            if (dt != null) {
              _expectedArrivalDate = dt;
              _expectedArrivalTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
            }
          }
        } else {
          _showBookingForm = true;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _showBookingForm = false;
        _isLoading = false;
      });
    }
  }

  void _toast(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, text));
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;

    final plannedDepartureDateTime = DateTime(
      _plannedDepartureDate.year,
      _plannedDepartureDate.month,
      _plannedDepartureDate.day,
      _plannedDepartureTime.hour,
      _plannedDepartureTime.minute,
    );
    final expectedArrivalDateTime = DateTime(
      _expectedArrivalDate.year,
      _expectedArrivalDate.month,
      _expectedArrivalDate.day,
      _expectedArrivalTime.hour,
      _expectedArrivalTime.minute,
    );
    if (!expectedArrivalDateTime.isAfter(plannedDepartureDateTime)) {
      _toast(l10n.inlandEtaBeforeDeparture, AppTheme.crimson);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = buildBookingPayload(
        importFileId: _isEditing ? null : widget.file.importFileId,
        carrierId: _carrierId,
        truckType: _truckType,
        plannedDepartureAt: plannedDepartureDateTime.toIso8601String(),
        expectedArrivalAt: expectedArrivalDateTime.toIso8601String(),
        controllers: _controllers,
      );

      if (_isEditing && _existingBooking != null) {
        await ref.read(inlandTransportProvider.notifier).updateBooking(_existingBooking!.transportId, payload);
        _toast(l10n.inlandUpdatedSnack, AppTheme.emerald);
      } else {
        final created = await ref.read(inlandTransportProvider.notifier).createBooking(payload);
        _toast(l10n.inlandBookedSnack(created?.transportCode ?? ''), AppTheme.emerald);
      }
      if (mounted) {
        _isEditing = false;
        await _loadBookingData();
      }
    } catch (e) {
      _toast(ApiErrorText.of(l10n, e), AppTheme.crimson);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _recordGateOut() async {
    if (_existingBooking == null) return;
    final l10n = context.l10n;
    final payload = inlandEventPayload(
      timeKey: 'actual_departure_at',
      at: DateTime.now(),
      notesText: _gateOutNotesController.text,
      gatePassNo: _gatePassNoController.text.trim(),
    );

    setState(() => _isSubmitting = true);
    try {
      final updated = await ref.read(inlandTransportProvider.notifier).recordGateOut(_existingBooking!.transportId, payload);
      _toast(l10n.inlandGateOutSnack(updated?.transportCode ?? ''), AppTheme.cobalt);
      if (mounted) await _loadBookingData();
    } catch (e) {
      _toast(ApiErrorText.of(l10n, e), AppTheme.crimson);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _recordWarehouseArrival() async {
    if (_existingBooking == null) return;
    final l10n = context.l10n;
    if (!_sealIntact && _sealNumberController.text.trim().isEmpty) {
      _toast(l10n.inlandSealNumberRequiredWhenBroken, AppTheme.crimson);
      return;
    }
    final payload = inlandEventPayload(
      timeKey: 'actual_arrival_at',
      at: DateTime.now(),
      notesText: _arrivalNotesController.text,
      sealIntact: _sealIntact,
      sealNumber: inlandNotesOrNull(_sealNumberController.text),
    );

    setState(() => _isSubmitting = true);
    try {
      final updated =
          await ref.read(inlandTransportProvider.notifier).recordWarehouseArrival(_existingBooking!.transportId, payload);
      _toast(l10n.inlandArrivalSnack(updated?.transportCode ?? ''), AppTheme.emerald);
      if (mounted) await _loadBookingData();
    } catch (e) {
      _toast(ApiErrorText.of(l10n, e), AppTheme.crimson);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget? _buildCurrentActionWidget() {
    final b = _existingBooking;
    if (b == null) return null;
    if (InlandStatus.isBookingConfirmedOrDispatched(b.status)) {
      return InlandGateOutAction(
        gatePassNoController: _gatePassNoController,
        notesController: _gateOutNotesController,
        isSubmitting: _isSubmitting,
        onGateOut: _recordGateOut,
      );
    } else if (InlandStatus.isInTransit(b.status)) {
      return InlandWarehouseArrivalAction(
        sealNumberController: _sealNumberController,
        notesController: _arrivalNotesController,
        sealIntact: _sealIntact,
        onSealIntactChanged: (val) => setState(() => _sealIntact = val),
        isSubmitting: _isSubmitting,
        onArrival: _recordWarehouseArrival,
      );
    } else if (InlandStatus.isArrivedOrDelivered(b.status)) {
      return const InlandArrivedBanner();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 960 ? 920.0 : screenWidth * 0.95;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      backgroundColor: AppTheme.surfaceOf(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SelectionArea(
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Column(
            children: [
              InlandTransportHeader(
                file: widget.file,
                status: _existingBooking?.status ?? widget.file.inlandTransportStatus,
                onClose: () => Navigator.of(context).pop(false),
              ),
              Expanded(
                child: _isLoading
                    ? const OpsLoadingView()
                    : _loadError != null
                        ? InlandTransportErrorView(
                            error: _loadError,
                            onRetry: _loadBookingData,
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsetsDirectional.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                InlandTransportCostCard(
                                  file: widget.file,
                                  existingBooking: _existingBooking,
                                ),
                                const SizedBox(height: 16),
                                if (_existingBooking != null) ...[
                                  InlandTransportTruckingCard(
                                    booking: _existingBooking!,
                                    showBookingForm: _showBookingForm,
                                    onToggleEdit: () => setState(() {
                                      _showBookingForm = !_showBookingForm;
                                      _isEditing = _showBookingForm;
                                    }),
                                    actionWidget: _buildCurrentActionWidget(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (_showBookingForm)
                                  InlandTransportBookingForm(
                                    formKey: _formKey,
                                    isEditing: _isEditing,
                                    isSubmitting: _isSubmitting,
                                    carrierId: _carrierId,
                                    onCarrierChanged: (val) => setState(() => _carrierId = val),
                                    truckType: _truckType,
                                    onTruckTypeChanged: (val) => setState(() => _truckType = val),
                                    plannedDepartureDate: _plannedDepartureDate,
                                    onPlannedDepartureDateChanged: (d) => setState(() => _plannedDepartureDate = d),
                                    plannedDepartureTime: _plannedDepartureTime,
                                    onPlannedDepartureTimeChanged: (t) => setState(() => _plannedDepartureTime = t),
                                    expectedArrivalDate: _expectedArrivalDate,
                                    onExpectedArrivalDateChanged: (d) => setState(() => _expectedArrivalDate = d),
                                    expectedArrivalTime: _expectedArrivalTime,
                                    onExpectedArrivalTimeChanged: (t) => setState(() => _expectedArrivalTime = t),
                                    controllers: _controllers,
                                    onPickupLocationChanged: (val) => setState(() => _controllers.pickupLocation.text = val),
                                    onSubmit: _submitBooking,
                                  ),
                              ],
                            ),
                          ),
              ),
              InlandTransportDialogFooter(
                onClose: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
