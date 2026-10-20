import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/inland_transport_model.dart';
import '../providers/inland_transport_provider.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';

/// Booking statuses written by the backend and domain enums.
class InlandStatus {
  InlandStatus._();
  static const bookingConfirmed = 'BOOKING_CONFIRMED';
  static const dispatched = 'DISPATCHED';
  static const inTransit = 'IN_TRANSIT';
  static const arrived = 'ARRIVED_AT_WAREHOUSE';
  static const delivered = 'DELIVERED';
  static const cancelled = 'CANCELLED';

  static String codeOf(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return DomainEnums.legacyToCode(DomainEnumType.inlandTransportStatus, raw.trim()) ?? raw.trim();
  }

  static bool isArrivedOrDelivered(String? raw) {
    final code = codeOf(raw);
    return code == arrived || code == delivered;
  }

  static bool isInTransit(String? raw) {
    final code = codeOf(raw);
    return code == inTransit;
  }

  static bool isBookingConfirmedOrDispatched(String? raw) {
    final code = codeOf(raw);
    return code == bookingConfirmed || code == dispatched;
  }
}

/// A note is sent only when the user typed one: the server never receives an invented text.
String? inlandNotesOrNull(String text) {
  final t = text.trim();
  return t.isEmpty ? null : t;
}

/// Payload of gate-out / warehouse-arrival: the schema field is `notes` (plan FE-04).
Map<String, dynamic> inlandEventPayload({
  required String timeKey,
  required DateTime at,
  required String notesText,
  String? gatePassNo,
  bool? sealIntact,
  String? sealNumber,
}) {
  final notes = inlandNotesOrNull(notesText);
  return {
    timeKey: at.toIso8601String(),
    if (notes != null) 'notes': notes,
    if (gatePassNo != null && gatePassNo.trim().isNotEmpty) 'gate_pass_no': gatePassNo.trim(),
    if (sealIntact != null) 'seal_intact': sealIntact,
    if (sealNumber != null && sealNumber.trim().isNotEmpty) 'seal_number': sealNumber.trim(),
  };
}

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
  // FE-06: a failed lookup must never fall through to the empty "create booking" form.
  Object? _loadError;
  InlandTransportModel? _existingBooking;

  int? _carrierId;
  late TextEditingController _waybillController;
  late TextEditingController _carrierNameController;
  late TextEditingController _truckPlateController;
  late TextEditingController _driverNameController;
  late TextEditingController _driverPhoneController;
  late TextEditingController _driverNationalIdController;
  late TextEditingController _containerNumbersController;
  late TextEditingController _pickupLocationController;
  late TextEditingController _destinationWarehouseController;
  late TextEditingController _fareEgpController;
  late TextEditingController _trackingNotesController;

  late TextEditingController _gateOutNotesController;
  late TextEditingController _gatePassNoController;
  late TextEditingController _arrivalNotesController;
  late TextEditingController _sealNumberController;
  bool _sealIntact = true;

  String _truckType = 'FLATBED'; // DomainEnumType.truckType code
  DateTime _plannedDepartureDate = DateTime.now();
  TimeOfDay _plannedDepartureTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _expectedArrivalDate = DateTime.now().add(const Duration(hours: 6));
  TimeOfDay _expectedArrivalTime = const TimeOfDay(hour: 16, minute: 0);

  List<String> get _truckTypes => [
        ...DomainEnums.codesOf(DomainEnumType.truckType),
        // A legacy free value that is not a known code stays selectable.
        if (!DomainEnums.isCode(DomainEnumType.truckType, _truckType)) _truckType,
      ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadBookingData();
  }

  void _initControllers() {
    final f = widget.file;
    _carrierId = null;
    _waybillController = TextEditingController();
    _carrierNameController = TextEditingController(text: f.inlandCarrierName ?? '');
    _truckPlateController = TextEditingController(text: f.inlandTruckPlateNo ?? '');
    _driverNameController = TextEditingController(text: f.inlandDriverName ?? '');
    _driverPhoneController = TextEditingController(text: f.inlandDriverPhone ?? '');
    _driverNationalIdController = TextEditingController();
    _containerNumbersController = TextEditingController();
    _pickupLocationController = TextEditingController(text: f.portOfDischarge ?? '');
    _destinationWarehouseController = TextEditingController();
    _fareEgpController = TextEditingController(
      text: f.inlandTransportCostEgp > 0 ? f.inlandTransportCostEgp.toStringAsFixed(2) : '',
    );
    _trackingNotesController = TextEditingController();
    _gateOutNotesController = TextEditingController();
    _gatePassNoController = TextEditingController();
    _arrivalNotesController = TextEditingController();
    _sealNumberController = TextEditingController();
    _sealIntact = true;
  }

  @override
  void dispose() {
    _waybillController.dispose();
    _carrierNameController.dispose();
    _truckPlateController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _driverNationalIdController.dispose();
    _containerNumbersController.dispose();
    _pickupLocationController.dispose();
    _destinationWarehouseController.dispose();
    _fareEgpController.dispose();
    _trackingNotesController.dispose();
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
          _carrierNameController.text = booking.carrierName;
          _truckPlateController.text = booking.truckPlateNumber;
          _driverNameController.text = booking.driverName;
          _driverPhoneController.text = booking.driverPhone;
          _driverNationalIdController.text = booking.driverNationalId ?? '';
          _containerNumbersController.text = booking.containerNumbers ?? '';
          _pickupLocationController.text = booking.pickupPortLocation;
          _destinationWarehouseController.text = booking.destinationWarehouse;
          _fareEgpController.text = booking.transportFareEgp.toStringAsFixed(2);
          _trackingNotesController.text = booking.trackingNotes ?? '';
          _truckType = DomainEnums.initialCode(DomainEnumType.truckType, booking.truckType, booking.truckType);
          _waybillController.text = booking.waybillNumber;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
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
      if (_isEditing && _existingBooking != null) {
        final updatePayload = <String, dynamic>{
          'waybill_number': _waybillController.text.trim(),
          if (_carrierId != null) 'carrier_id': _carrierId,
          'carrier_name': _carrierNameController.text.trim(),
          'truck_plate_number': _truckPlateController.text.trim(),
          'truck_type': _truckType,
          'driver_name': _driverNameController.text.trim(),
          'driver_phone': _driverPhoneController.text.trim(),
          'driver_national_id': inlandNotesOrNull(_driverNationalIdController.text),
          'container_numbers': inlandNotesOrNull(_containerNumbersController.text),
          'pickup_port_location': _pickupLocationController.text.trim(),
          'destination_warehouse': _destinationWarehouseController.text.trim(),
          'planned_departure_at': plannedDepartureDateTime.toIso8601String(),
          'expected_arrival_at': expectedArrivalDateTime.toIso8601String(),
          'transport_fare_egp': double.parse(_fareEgpController.text.trim()),
          'tracking_notes': inlandNotesOrNull(_trackingNotesController.text),
        };
        await ref.read(inlandTransportProvider.notifier).updateBooking(_existingBooking!.transportId, updatePayload);
        _toast(l10n.inlandUpdatedSnack, AppTheme.emerald);
      } else {
        final payload = {
          'import_file_id': widget.file.importFileId,
          'waybill_number': _waybillController.text.trim(),
          if (_carrierId != null) 'carrier_id': _carrierId,
          'carrier_name': _carrierNameController.text.trim(),
          'truck_plate_number': _truckPlateController.text.trim(),
          'truck_type': _truckType,
          'driver_name': _driverNameController.text.trim(),
          'driver_phone': _driverPhoneController.text.trim(),
          'driver_national_id': inlandNotesOrNull(_driverNationalIdController.text),
          'container_numbers': inlandNotesOrNull(_containerNumbersController.text),
          'pickup_port_location': _pickupLocationController.text.trim(),
          'destination_warehouse': _destinationWarehouseController.text.trim(),
          'planned_departure_at': plannedDepartureDateTime.toIso8601String(),
          'expected_arrival_at': expectedArrivalDateTime.toIso8601String(),
          'transport_fare_egp': double.parse(_fareEgpController.text.trim()),
          'tracking_notes': inlandNotesOrNull(_trackingNotesController.text),
        };
        final created = await ref.read(inlandTransportProvider.notifier).createBooking(payload);
        _toast(l10n.inlandBookedSnack(created?.transportCode ?? ''), AppTheme.emerald);
      }
      if (mounted) {
        _isEditing = false;
        await _loadBookingData();
      }
    } catch (e) {
      // A 409 IT_BOOKING_EXISTS carries `message` (rendered by ApiErrorText).
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

  AppSeverity _statusSeverity(String? status) {
    final code = InlandStatus.codeOf(status);
    switch (code) {
      case InlandStatus.arrived:
      case InlandStatus.delivered:
        return AppSeverity.success;
      case InlandStatus.inTransit:
        return AppSeverity.info;
      case InlandStatus.bookingConfirmed:
      case InlandStatus.dispatched:
        return AppSeverity.warning;
      case InlandStatus.cancelled:
        return AppSeverity.danger;
      default:
        return AppSeverity.info;
    }
  }

  Color _getStatusColor(String? status) {
    final code = InlandStatus.codeOf(status);
    switch (code) {
      case InlandStatus.arrived:
      case InlandStatus.delivered:
        return AppTheme.emerald;
      case InlandStatus.inTransit:
        return AppTheme.cobalt;
      case InlandStatus.bookingConfirmed:
      case InlandStatus.dispatched:
        return AppTheme.flatOrange;
      case InlandStatus.cancelled:
        return AppTheme.crimson;
      default:
        return AppTheme.charcoal;
    }
  }

  String _statusLabel(AppLocalizations l10n, String? status) {
    if (status == null || status.trim().isEmpty) return l10n.inlandStatusNotBooked;
    final code = InlandStatus.codeOf(status);
    if (DomainEnums.isCode(DomainEnumType.inlandTransportStatus, code)) {
      return DomainEnums.label(l10n, DomainEnumType.inlandTransportStatus, code);
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 960 ? 920.0 : screenWidth * 0.95;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      backgroundColor: AppTheme.surfaceOf(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            _buildDialogHeader(),
            Expanded(
              child: _isLoading
                  ? const OpsLoadingView()
                  : _loadError != null
                      ? _buildLoadError()
                      : SelectionArea(
                          child: SingleChildScrollView(
                            padding: const EdgeInsetsDirectional.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildKpiSummaryCards(),
                                const SizedBox(height: 16),
                                if (_existingBooking != null) ...[
                                  _buildExistingBookingCard(),
                                  const SizedBox(height: 16),
                                ],
                                if (_showBookingForm) _buildBookingForm(),
                              ],
                            ),
                          ),
                        ),
            ),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: AppTheme.severityForegroundOf(context, AppSeverity.danger), size: 30),
            ),
            const SizedBox(height: 12),
            Text(l10n.inlandLoadErrorTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              ApiErrorText.of(l10n, _loadError),
              key: const Key('inlandLoadErrorText'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
            ),
            const SizedBox(height: 16),
            AppButton(
              key: const Key('inlandRetryBtn'),
              label: l10n.inlandRetryBtn,
              icon: Icons.refresh,
              onPressed: _loadBookingData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    final l10n = context.l10n;
    final status = _existingBooking?.status ?? widget.file.inlandTransportStatus;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: AppTheme.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inlandDialogTitle,
                  style: const TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.inlandDialogFileLine(widget.file.primaryNameWithCode, widget.file.companyName),
                        style: TextStyle(color: AppTheme.white.withAlpha(180), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OpsStatusChip(
                      label: _statusLabel(l10n, status),
                      severity: _statusSeverity(status),
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color.fromRGBO(255, 255, 255, 0.7)),
            onPressed: () => Navigator.of(context).pop(false),
            tooltip: l10n.inlandCloseTooltip,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryCards() {
    final l10n = context.l10n;
    final status = _existingBooking?.status ?? widget.file.inlandTransportStatus;
    final fare = _existingBooking?.transportFareEgp ?? widget.file.inlandTransportCostEgp;
    final driver = _existingBooking?.driverName ?? widget.file.inlandDriverName ?? l10n.inlandNotSet;
    final truck = _existingBooking?.truckPlateNumber ?? widget.file.inlandTruckPlateNo ?? l10n.inlandNotSet;
    final waybill = _existingBooking?.waybillNumber ?? widget.file.inlandTransportBookingNo ?? l10n.inlandWaybillPending;

    final tiles = <Widget>[
        _buildKpiTile(
            title: l10n.inlandKpiStatus,
            value: _statusLabel(l10n, status),
            icon: Icons.alt_route_rounded,
            color: _getStatusColor(status),
          ),
        _buildKpiTile(
            title: l10n.inlandKpiWaybill,
            value: waybill,
            icon: Icons.receipt_rounded,
            color: AppTheme.cobalt,
          ),
        _buildKpiTile(
            title: l10n.inlandKpiTruckDriver,
            value: '$truck / $driver',
            icon: Icons.person_pin_rounded,
            color: AppTheme.charcoal,
          ),
        _buildKpiTile(
            title: l10n.inlandKpiFare,
            value: '${fare.toStringAsFixed(2)} ${l10n.inlandCurrencySuffix}',
            icon: Icons.monetization_on_outlined,
            color: AppTheme.emerald,
          ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final cols = c.maxWidth >= 760 ? 4 : 2;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: AppTheme.cardDecorationOf(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
    required TextEditingController notesController,
    Widget? extraContent,
    required Widget button,
  }) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(description, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
              ),
              button,
            ],
          ),
          if (extraContent != null) ...[
            const SizedBox(height: 10),
            extraContent,
          ],
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: l10n.inlandNotesOptionalLabel,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingBookingCard() {
    final l10n = context.l10n;
    final b = _existingBooking!;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.cobalt.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.inlandCurrentBookingTitle(b.transportCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!InlandStatus.isArrivedOrDelivered(b.status)) ...[
                const SizedBox(width: 8),
                OpsFit(
                  child: AppButton(
                    key: const Key('inlandEditBookingBtn'),
                    label: _showBookingForm ? l10n.inlandHideForm : l10n.inlandEditBookingBtn,
                    icon: _showBookingForm ? Icons.expand_less : Icons.edit,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                    onPressed: () => setState(() {
                      if (_showBookingForm) {
                        _showBookingForm = false;
                        _isEditing = false;
                      } else {
                        _showBookingForm = true;
                        _isEditing = true;
                      }
                    }),
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildInfoRow(l10n.inlandInfoCarrier, b.carrierName),
              _buildInfoRow(l10n.inlandInfoWaybill, b.waybillNumber),
              _buildInfoRow(l10n.inlandInfoTruckType, DomainEnums.label(l10n, DomainEnumType.truckType, b.truckType)),
              _buildInfoRow(l10n.inlandInfoPlate, b.truckPlateNumber),
              _buildInfoRow(l10n.inlandInfoDriver, '${b.driverName} (${b.driverPhone})'),
              if (b.containerNumbers != null) _buildInfoRow(l10n.inlandInfoContainers, b.containerNumbers!),
              _buildInfoRow(l10n.inlandInfoPickup, b.pickupPortLocation),
              _buildInfoRow(l10n.inlandInfoDestination, b.destinationWarehouse),
              _buildInfoRow(l10n.inlandInfoPlannedDeparture, b.plannedDepartureAt.split('T').first),
              _buildInfoRow(l10n.inlandInfoExpectedArrival, b.expectedArrivalAt.split('T').first),
              if (b.actualDepartureAt != null) _buildInfoRow(l10n.inlandInfoActualDeparture, b.actualDepartureAt!.split('T').first),
              if (b.actualArrivalAt != null) _buildInfoRow(l10n.inlandInfoActualArrival, b.actualArrivalAt!.split('T').first),
            ],
          ),
          const SizedBox(height: 16),
          if (InlandStatus.isBookingConfirmedOrDispatched(b.status))
            _buildActionPanel(
              color: AppTheme.cobalt,
              icon: Icons.departure_board,
              title: l10n.inlandGateOutTitle,
              description: l10n.inlandGateOutDesc,
              notesController: _gateOutNotesController,
              extraContent: TextField(
                key: const Key('inlandGatePassNoField'),
                controller: _gatePassNoController,
                decoration: InputDecoration(
                  labelText: l10n.inlandGatePassNoLabel,
                  hintText: l10n.inlandGatePassNoHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.confirmation_num_outlined),
                ),
              ),
              button: AppButton(
                key: const Key('inlandGateOutBtn'),
                label: l10n.inlandGateOutBtn,
                icon: Icons.exit_to_app,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _recordGateOut,
              ),
            )
          else if (InlandStatus.isInTransit(b.status))
            _buildActionPanel(
              color: AppTheme.emerald,
              icon: Icons.warehouse_rounded,
              title: l10n.inlandArrivalTitle,
              description: l10n.inlandArrivalDesc,
              notesController: _arrivalNotesController,
              extraContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      key: const Key('inlandSealIntactSwitch'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.inlandSealIntactSwitch, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      value: _sealIntact,
                      onChanged: (val) => setState(() => _sealIntact = val),
                      activeThumbColor: AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('inlandSealNumberField'),
                    controller: _sealNumberController,
                    decoration: InputDecoration(
                      labelText: _sealIntact
                          ? '${l10n.inlandSealNumberLabel.replaceAll(' *', '')} (${l10n.inlandNotesOptionalLabel})'
                          : l10n.inlandSealNumberLabel,
                      hintText: l10n.inlandSealNumberHint,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.security),
                    ),
                  ),
                ],
              ),
              button: AppButton(
                key: const Key('inlandWarehouseArrivalBtn'),
                label: l10n.inlandArrivalBtn,
                variant: AppButtonVariant.success,
                icon: Icons.done_all,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _recordWarehouseArrival,
              ),
            )
          else if (InlandStatus.isArrivedOrDelivered(b.status))
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.emerald),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.emerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.inlandArrivedMsg,
                      style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context), fontWeight: FontWeight.w500)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _text(
    TextEditingController c,
    String label,
    IconData icon, {
    Key? key,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool ltr = false,
    String? suffix,
  }) {
    return TextFormField(
      key: key,
      controller: c,
      keyboardType: keyboardType,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixText: suffix,
      ),
      validator: validator,
    );
  }

  Widget _buildBookingForm() {
    final l10n = context.l10n;
    String? required(String? v, String msg) => (v == null || v.trim().isEmpty) ? msg : null;
    String? minLen(String? v, int n, String msg) => (v == null || v.trim().length < n) ? msg : null;

    final partners = ref.watch(partnersProvider).valueOrNull ?? [];
    final transportPartners = partners
        .where((p) =>
            p.isActive &&
            (p.partnerType == 'Inland Transport' ||
                p.partnerType.toLowerCase().contains('transport') ||
                p.partnerType.toLowerCase().contains('trucking') ||
                p.partnerType.toLowerCase().contains('carrier')))
        .toList();

    final carrierList = transportPartners.isNotEmpty
        ? transportPartners
        : partners.where((p) => p.isActive).toList();

    final carrierItems = <SearchableDropdownItem<int>>[];
    for (final p in carrierList) {
      if (p.providerId != null) {
        carrierItems.add(SearchableDropdownItem<int>(
          value: p.providerId!,
          label: p.partnerName,
          subtitle: p.partnerType.isNotEmpty ? p.partnerType : null,
        ));
      }
    }
    if (_carrierId != null && !carrierItems.any((item) => item.value == _carrierId)) {
      carrierItems.insert(
        0,
        SearchableDropdownItem<int>(
          value: _carrierId!,
          label: _carrierNameController.text.isNotEmpty ? _carrierNameController.text : 'Carrier #$_carrierId',
        ),
      );
    }

    final locations = ref.watch(transportLocationsProvider).valueOrNull ?? [];
    final locationItems = <SearchableDropdownItem<String>>[
      ...locations.map((loc) {
        final code = loc.unLocode.isNotEmpty ? ' (${loc.unLocode})' : '';
        return SearchableDropdownItem<String>(
          value: loc.locationName,
          label: '${loc.locationName}$code',
          subtitle: loc.city.isNotEmpty ? '${loc.city}, ${loc.country}' : loc.country,
        );
      }),
    ];
    if (_pickupLocationController.text.isNotEmpty &&
        !locationItems.any((item) => item.value == _pickupLocationController.text)) {
      locationItems.insert(
        0,
        SearchableDropdownItem<String>(
          value: _pickupLocationController.text,
          label: _pickupLocationController.text,
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsetsDirectional.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_calendar_rounded, color: AppTheme.charcoal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEditing ? l10n.inlandEditBookingBtn : l10n.inlandFormTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _text(_waybillController, l10n.inlandWaybillLabel, Icons.receipt,
                      key: const Key('inlandWaybillNoField'), ltr: true, validator: (v) => required(v, l10n.inlandWaybillRequired)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SearchableDropdownField<int>(
                    key: const Key('inlandCarrierDropdown'),
                    labelText: l10n.inlandCarrierLabel,
                    hintText: _carrierNameController.text.isNotEmpty
                        ? _carrierNameController.text
                        : l10n.inlandSelectCarrierHint,
                    value: _carrierId,
                    items: carrierItems,
                    onChanged: (val) {
                      setState(() {
                        _carrierId = val;
                        if (val != null) {
                          final chosen = carrierList.firstWhere(
                            (p) => p.providerId == val,
                            orElse: () => partners.firstWhere((p) => p.providerId == val),
                          );
                          _carrierNameController.text = chosen.partnerName;
                        }
                      });
                    },
                    validator: (val) {
                      if (val == null && _carrierNameController.text.trim().isEmpty) {
                        return l10n.inlandCarrierRequired;
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(
              width: 0,
              height: 0,
              child: TextFormField(
                key: const Key('inlandCarrierNameField'),
                controller: _carrierNameController,
                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _text(_truckPlateController, l10n.inlandPlateLabel, Icons.confirmation_number,
                      key: const Key('inlandTruckPlateField'),
                      hint: l10n.inlandPlateHint,
                      validator: (v) => minLen(v, 3, l10n.inlandPlateInvalid)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SearchableDropdownField<String>(
                    key: const Key('inlandTruckTypeDropdown'),
                    labelText: l10n.inlandTruckTypeLabel,
                    hintText: l10n.inlandTruckTypeHint,
                    value: _truckType,
                    items: _truckTypes
                        .map((t) => SearchableDropdownItem<String>(
                            value: t, label: DomainEnums.label(l10n, DomainEnumType.truckType, t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _truckType = val);
                    },
                    validator: (val) => (val == null || val.isEmpty) ? l10n.inlandTruckTypeRequired : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _text(_driverNameController, l10n.inlandDriverLabel, Icons.person,
                      key: const Key('inlandDriverNameField'), validator: (v) => minLen(v, 3, l10n.inlandDriverInvalid)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: _text(_driverPhoneController, l10n.inlandPhoneLabel, Icons.phone,
                      key: const Key('inlandDriverPhoneField'),
                      keyboardType: TextInputType.phone,
                      ltr: true,
                      validator: (v) => minLen(v, 8, l10n.inlandPhoneInvalid)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: _text(_driverNationalIdController, l10n.inlandNationalIdLabel, Icons.badge,
                      hint: l10n.inlandNationalIdHint, ltr: true),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SearchableDropdownField<String>(
                    key: const Key('inlandPickupLocationDropdown'),
                    labelText: l10n.inlandPickupLabel,
                    hintText: l10n.inlandSelectPickupLocationHint,
                    value: _pickupLocationController.text.isEmpty ? null : _pickupLocationController.text,
                    items: locationItems,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _pickupLocationController.text = val);
                      }
                    },
                    validator: (val) {
                      if ((val == null || val.trim().isEmpty) && _pickupLocationController.text.trim().isEmpty) {
                        return l10n.inlandPickupRequired;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _text(_destinationWarehouseController, l10n.inlandWarehouseLabel, Icons.warehouse,
                      validator: (v) => required(v, l10n.inlandWarehouseRequired)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _text(_containerNumbersController, l10n.inlandContainersLabel, Icons.view_in_ar, ltr: true),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: _text(_fareEgpController, l10n.inlandFareLabel, Icons.attach_money,
                      key: const Key('inlandFareEgpField'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      suffix: l10n.inlandCurrencySuffix,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return l10n.inlandFareRequired;
                        final numVal = double.tryParse(val.trim());
                        if (numVal == null || numVal <= 0) return l10n.inlandFareInvalid;
                        return null;
                      }),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _datePicker(l10n.inlandDepartureDate, Icons.calendar_today, _plannedDepartureDate, (d) => _plannedDepartureDate = d)),
                const SizedBox(width: 14),
                Expanded(child: _timePicker(l10n.inlandDepartureTime, Icons.access_time, _plannedDepartureTime, (t) => _plannedDepartureTime = t)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _datePicker(l10n.inlandEtaDate, Icons.event_available, _expectedArrivalDate, (d) => _expectedArrivalDate = d)),
                const SizedBox(width: 14),
                Expanded(child: _timePicker(l10n.inlandEtaTime, Icons.access_time_filled, _expectedArrivalTime, (t) => _expectedArrivalTime = t)),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _trackingNotesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.inlandNotesLabel,
                hintText: l10n.inlandNotesHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                key: const Key('inlandSubmitBookingBtn'),
                label: _isEditing ? l10n.inlandSaveChangesBtn : l10n.inlandSubmitBtn,
                variant: AppButtonVariant.success,
                icon: Icons.check_circle,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submitBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePicker(String title, IconData icon, TimeOfDay value, void Function(TimeOfDay) assign) {
    final hourStr = value.hour.toString().padLeft(2, '0');
    final minuteStr = value.minute.toString().padLeft(2, '0');
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 12)),
        subtitle: Text('$hourStr:$minuteStr', style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Icon(icon, size: 18),
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: value,
          );
          if (picked != null) setState(() => assign(picked));
        },
      ),
    );
  }

  Widget _datePicker(String title, IconData icon, DateTime value, void Function(DateTime) assign) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 12)),
        subtitle: Text('${value.year}-${two(value.month)}-${two(value.day)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Icon(icon, size: 18),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) setState(() => assign(picked));
        },
      ),
    );
  }

  Widget _buildDialogFooter() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusXl)),
        border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_alt, size: 16, color: AppTheme.cobalt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.inlandFooterNote,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: l10n.inlandCloseBtn,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
