import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/inland_transport_model.dart';
import '../providers/inland_transport_provider.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';

/// Booking statuses written by the backend (legacy labels until the status enum lands).
class InlandStatus {
  InlandStatus._();
  static const bookingConfirmed = 'Booking Confirmed';
  static const inTransit = 'In Transit (Gate-Out)';
  static const arrived = 'Arrived Warehouse';
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
}) {
  final notes = inlandNotesOrNull(notesText);
  return {
    timeKey: at.toIso8601String(),
    if (notes != null) 'notes': notes,
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
  // FE-06: a failed lookup must never fall through to the empty "create booking" form.
  Object? _loadError;
  InlandTransportModel? _existingBooking;

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
  late TextEditingController _arrivalNotesController;

  String _truckType = 'FLATBED'; // DomainEnumType.truckType code
  DateTime _plannedDepartureDate = DateTime.now();
  final TimeOfDay _plannedDepartureTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _expectedArrivalDate = DateTime.now().add(const Duration(hours: 6));
  final TimeOfDay _expectedArrivalTime = const TimeOfDay(hour: 16, minute: 0);

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
    _arrivalNotesController = TextEditingController();
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
    _arrivalNotesController.dispose();
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
        if (booking != null) {
          _showBookingForm = false;
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

    final payload = {
      'import_file_id': widget.file.importFileId,
      'waybill_number': _waybillController.text.trim(),
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

    setState(() => _isSubmitting = true);
    try {
      final created = await ref.read(inlandTransportProvider.notifier).createBooking(payload);
      _toast(l10n.inlandBookedSnack(created?.transportCode ?? ''), AppTheme.emerald);
      if (mounted) await _loadBookingData();
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
    final payload = inlandEventPayload(
      timeKey: 'actual_arrival_at',
      at: DateTime.now(),
      notesText: _arrivalNotesController.text,
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

  AppSeverity _statusSeverity(String status) {
    switch (status) {
      case InlandStatus.arrived:
        return AppSeverity.success;
      case InlandStatus.inTransit:
        return AppSeverity.info;
      case InlandStatus.bookingConfirmed:
        return AppSeverity.warning;
      default:
        return AppSeverity.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case InlandStatus.arrived:
        return AppTheme.emerald;
      case InlandStatus.inTransit:
        return AppTheme.cobalt;
      case InlandStatus.bookingConfirmed:
        return AppTheme.flatOrange;
      default:
        return AppTheme.charcoal;
    }
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case InlandStatus.arrived:
        return l10n.inlandStatusArrived;
      case InlandStatus.inTransit:
        return l10n.inlandStatusInTransit;
      case InlandStatus.bookingConfirmed:
        return l10n.inlandStatusConfirmed;
      default:
        return l10n.inlandStatusNotBooked;
    }
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
                      : SingleChildScrollView(
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
            icon: Icon(Icons.close, color: AppTheme.white.withOpacity(0.7)),
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
              const SizedBox(width: 8),
              OpsFit(
                child: AppButton(
                  label: _showBookingForm ? l10n.inlandHideForm : l10n.inlandEditOrRebook,
                  icon: _showBookingForm ? Icons.expand_less : Icons.edit,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: () => setState(() => _showBookingForm = !_showBookingForm),
                ),
              ),
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
          if (b.status == InlandStatus.bookingConfirmed)
            _buildActionPanel(
              color: AppTheme.cobalt,
              icon: Icons.departure_board,
              title: l10n.inlandGateOutTitle,
              description: l10n.inlandGateOutDesc,
              notesController: _gateOutNotesController,
              button: AppButton(
                key: const Key('inlandGateOutBtn'),
                label: l10n.inlandGateOutBtn,
                icon: Icons.exit_to_app,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _recordGateOut,
              ),
            )
          else if (b.status == InlandStatus.inTransit)
            _buildActionPanel(
              color: AppTheme.emerald,
              icon: Icons.warehouse_rounded,
              title: l10n.inlandArrivalTitle,
              description: l10n.inlandArrivalDesc,
              notesController: _arrivalNotesController,
              button: AppButton(
                key: const Key('inlandWarehouseArrivalBtn'),
                label: l10n.inlandArrivalBtn,
                variant: AppButtonVariant.success,
                icon: Icons.done_all,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _recordWarehouseArrival,
              ),
            )
          else if (b.status == InlandStatus.arrived)
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
                    l10n.inlandFormTitle,
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
                  child: _text(_carrierNameController, l10n.inlandCarrierLabel, Icons.business,
                      key: const Key('inlandCarrierNameField'), validator: (v) => required(v, l10n.inlandCarrierRequired)),
                ),
              ],
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
                  child: _text(_pickupLocationController, l10n.inlandPickupLabel, Icons.location_on,
                      validator: (v) => required(v, l10n.inlandPickupRequired)),
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
                Expanded(child: _datePicker(l10n.inlandEtaDate, Icons.event_available, _expectedArrivalDate, (d) => _expectedArrivalDate = d)),
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
                label: l10n.inlandSubmitBtn,
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
