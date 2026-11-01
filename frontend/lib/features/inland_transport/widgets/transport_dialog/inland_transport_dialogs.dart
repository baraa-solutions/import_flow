import 'package:flutter/material.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../external_service_providers/models/partner_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../transport_locations/models/transport_location_model.dart';
import '../../models/inland_transport_model.dart';

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

/// Encapsulates all text editing controllers for the inland transport booking form.
class InlandBookingControllers {
  final waybill = TextEditingController();
  final carrierName = TextEditingController();
  final truckPlate = TextEditingController();
  final driverName = TextEditingController();
  final driverPhone = TextEditingController();
  final driverNationalId = TextEditingController();
  final containerNumbers = TextEditingController();
  final pickupLocation = TextEditingController();
  final destinationWarehouse = TextEditingController();
  final fareEgp = TextEditingController();
  final trackingNotes = TextEditingController();

  void initFromFile(ImportFileModel f) {
    carrierName.text = f.inlandCarrierName ?? '';
    truckPlate.text = f.inlandTruckPlateNo ?? '';
    driverName.text = f.inlandDriverName ?? '';
    driverPhone.text = f.inlandDriverPhone ?? '';
    pickupLocation.text = f.portOfDischarge ?? '';
    fareEgp.text = f.inlandTransportCostEgp > 0 ? f.inlandTransportCostEgp.toStringAsFixed(2) : '';
  }

  void initFromBooking(InlandTransportModel b) {
    carrierName.text = b.carrierName;
    truckPlate.text = b.truckPlateNumber;
    driverName.text = b.driverName;
    driverPhone.text = b.driverPhone;
    driverNationalId.text = b.driverNationalId ?? '';
    containerNumbers.text = b.containerNumbers ?? '';
    pickupLocation.text = b.pickupPortLocation;
    destinationWarehouse.text = b.destinationWarehouse;
    fareEgp.text = b.transportFareEgp.toStringAsFixed(2);
    trackingNotes.text = b.trackingNotes ?? '';
    waybill.text = b.waybillNumber;
  }

  void dispose() {
    for (final c in [
      waybill, carrierName, truckPlate, driverName, driverPhone,
      driverNationalId, containerNumbers, pickupLocation, destinationWarehouse,
      fareEgp, trackingNotes,
    ]) {
      c.dispose();
    }
  }
}

/// Builds the json payload for inland booking creation or update.
Map<String, dynamic> buildBookingPayload({
  int? importFileId,
  required int? carrierId,
  required String truckType,
  required String plannedDepartureAt,
  required String expectedArrivalAt,
  required InlandBookingControllers controllers,
}) => {
  if (importFileId != null) 'import_file_id': importFileId,
  'waybill_number': controllers.waybill.text.trim(),
  if (carrierId != null) 'carrier_id': carrierId,
  'carrier_name': controllers.carrierName.text.trim(),
  'truck_plate_number': controllers.truckPlate.text.trim(),
  'truck_type': truckType,
  'driver_name': controllers.driverName.text.trim(),
  'driver_phone': controllers.driverPhone.text.trim(),
  'driver_national_id': inlandNotesOrNull(controllers.driverNationalId.text),
  'container_numbers': inlandNotesOrNull(controllers.containerNumbers.text),
  'pickup_port_location': controllers.pickupLocation.text.trim(),
  'destination_warehouse': controllers.destinationWarehouse.text.trim(),
  'planned_departure_at': plannedDepartureAt,
  'expected_arrival_at': expectedArrivalAt,
  'transport_fare_egp': double.parse(controllers.fareEgp.text.trim()),
  'tracking_notes': inlandNotesOrNull(controllers.trackingNotes.text),
};

/// Builds items list for carrier dropdown.
List<SearchableDropdownItem<int>> buildCarrierDropdownItems({
  required List<PartnerModel> carrierList,
  int? carrierId,
  required String carrierName,
}) {
  final items = carrierList
      .where((p) => p.providerId != null)
      .map((p) => SearchableDropdownItem<int>(
            value: p.providerId!,
            label: p.partnerName,
            subtitle: p.partnerType.isNotEmpty ? p.partnerType : null,
          ))
      .toList();
  if (carrierId != null && !items.any((item) => item.value == carrierId)) {
    items.insert(0, SearchableDropdownItem<int>(value: carrierId, label: carrierName.isNotEmpty ? carrierName : 'Carrier #$carrierId'));
  }
  return items;
}

/// Builds items list for location dropdown.
List<SearchableDropdownItem<String>> buildLocationDropdownItems({
  required List<TransportLocationModel> locations,
  required String selectedLocation,
}) {
  final items = locations.map((loc) {
    final code = loc.unLocode.isNotEmpty ? ' (${loc.unLocode})' : '';
    return SearchableDropdownItem<String>(value: loc.locationName, label: '${loc.locationName}$code', subtitle: loc.city.isNotEmpty ? '${loc.city}, ${loc.country}' : loc.country);
  }).toList();
  if (selectedLocation.isNotEmpty && !items.any((item) => item.value == selectedLocation)) {
    items.insert(0, SearchableDropdownItem<String>(value: selectedLocation, label: selectedLocation));
  }
  return items;
}

/// Error view displayed when inland transport booking lookup fails.
class InlandTransportErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const InlandTransportErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(color: AppTheme.severityBackgroundOf(context, AppSeverity.danger), shape: BoxShape.circle),
              child: Icon(Icons.error_outline, color: AppTheme.severityForegroundOf(context, AppSeverity.danger), size: 30),
            ),
            const SizedBox(height: 12),
            Text(l10n.inlandLoadErrorTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text(ApiErrorText.of(l10n, error), key: const Key('inlandLoadErrorText'), textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.crimson, fontSize: 12)),
            const SizedBox(height: 16),
            AppButton(key: const Key('inlandRetryBtn'), label: l10n.inlandRetryBtn, icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _InlandPickerTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _InlandPickerTile({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 12)),
        subtitle: Text(subtitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Icon(icon, size: 18),
        onTap: onTap,
      ),
    );
  }
}

/// Date picker tile with consistent styling and standard format.
class InlandDatePickerTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const InlandDatePickerTile({super.key, required this.title, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    return _InlandPickerTile(
      title: title,
      subtitle: '${value.year}-${two(value.month)}-${two(value.day)}',
      icon: icon,
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Time picker tile with consistent styling.
class InlandTimePickerTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  const InlandTimePickerTile({super.key, required this.title, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hourStr = value.hour.toString().padLeft(2, '0');
    final minuteStr = value.minute.toString().padLeft(2, '0');
    return _InlandPickerTile(
      title: title,
      subtitle: '$hourStr:$minuteStr',
      icon: icon,
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: value);
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Departure & ETA schedule pickers section.
class InlandSchedulePickersSection extends StatelessWidget {
  final DateTime plannedDepartureDate;
  final ValueChanged<DateTime> onPlannedDepartureDateChanged;
  final TimeOfDay plannedDepartureTime;
  final ValueChanged<TimeOfDay> onPlannedDepartureTimeChanged;
  final DateTime expectedArrivalDate;
  final ValueChanged<DateTime> onExpectedArrivalDateChanged;
  final TimeOfDay expectedArrivalTime;
  final ValueChanged<TimeOfDay> onExpectedArrivalTimeChanged;

  const InlandSchedulePickersSection({
    super.key,
    required this.plannedDepartureDate,
    required this.onPlannedDepartureDateChanged,
    required this.plannedDepartureTime,
    required this.onPlannedDepartureTimeChanged,
    required this.expectedArrivalDate,
    required this.onExpectedArrivalDateChanged,
    required this.expectedArrivalTime,
    required this.onExpectedArrivalTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(children: [
          Expanded(child: InlandDatePickerTile(title: l10n.inlandDepartureDate, icon: Icons.calendar_today, value: plannedDepartureDate, onChanged: onPlannedDepartureDateChanged)),
          const SizedBox(width: 14),
          Expanded(child: InlandTimePickerTile(title: l10n.inlandDepartureTime, icon: Icons.access_time, value: plannedDepartureTime, onChanged: onPlannedDepartureTimeChanged)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: InlandDatePickerTile(title: l10n.inlandEtaDate, icon: Icons.event_available, value: expectedArrivalDate, onChanged: onExpectedArrivalDateChanged)),
          const SizedBox(width: 14),
          Expanded(child: InlandTimePickerTile(title: l10n.inlandEtaTime, icon: Icons.access_time_filled, value: expectedArrivalTime, onChanged: onExpectedArrivalTimeChanged)),
        ]),
      ],
    );
  }
}

/// Form row section for Driver name, phone, and national ID.
class InlandDriverFormSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController nationalIdController;

  const InlandDriverFormSection({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.nationalIdController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? minLen(String? v, int n, String msg) => (v == null || v.trim().length < n) ? msg : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: InlandTextFormField(
            fieldKey: const Key('inlandDriverNameField'),
            controller: nameController,
            label: l10n.inlandDriverLabel,
            icon: Icons.person,
            validator: (v) => minLen(v, 3, l10n.inlandDriverInvalid),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: InlandTextFormField(
            fieldKey: const Key('inlandDriverPhoneField'),
            controller: phoneController,
            label: l10n.inlandPhoneLabel,
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            ltr: true,
            validator: (v) => minLen(v, 8, l10n.inlandPhoneInvalid),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: InlandTextFormField(
            controller: nationalIdController,
            label: l10n.inlandNationalIdLabel,
            icon: Icons.badge,
            hint: l10n.inlandNationalIdHint,
            ltr: true,
          ),
        ),
      ],
    );
  }
}

/// Unified text form field helper for inland transport forms.
class InlandTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Key? fieldKey;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool ltr;
  final String? suffix;
  final int maxLines;

  const InlandTextFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.fieldKey,
    this.hint,
    this.validator,
    this.keyboardType,
    this.ltr = false,
    this.suffix,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      textDirection: ltr ? TextDirection.ltr : null,
      maxLines: maxLines,
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
}
