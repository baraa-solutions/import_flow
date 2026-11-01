import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../freight_booking_ui.dart';

/// Routing, schedule, shipping line, and vessel details for the freight booking form.
class BookingFormRoutingTab extends StatelessWidget {
  final String? shippingLineName;
  final List<dynamic> shippingLines;
  final void Function(String name, int? id) onShippingLineChanged;

  final String? freightForwarderName;
  final List<dynamic> freightForwarders;
  final void Function(String name, int? id) onFreightForwarderChanged;

  final TextEditingController polController;
  final TextEditingController podController;
  final List<dynamic> ports;
  final void Function(String name, int? id) onPolChanged;
  final void Function(String name, int? id) onPodChanged;

  final DateTime? etd;
  final DateTime? eta;
  final DateTime? atd;
  final ValueChanged<DateTime> onEtdChanged;
  final ValueChanged<DateTime> onEtaChanged;
  final ValueChanged<DateTime> onAtdChanged;
  final VoidCallback onClearAtd;

  final TextEditingController freeDemurrageController;
  final TextEditingController expectedWhDaysController;
  final ValueChanged<String>? onExpectedWhDaysChanged;
  final String status;
  final ValueChanged<String> onStatusChanged;

  final TextEditingController vesselNameController;
  final TextEditingController voyageNoController;
  final TextEditingController releaseOrderNoController;

  const BookingFormRoutingTab({
    super.key,
    required this.shippingLineName,
    required this.shippingLines,
    required this.onShippingLineChanged,
    required this.freightForwarderName,
    required this.freightForwarders,
    required this.onFreightForwarderChanged,
    required this.polController,
    required this.podController,
    required this.ports,
    required this.onPolChanged,
    required this.onPodChanged,
    required this.etd,
    required this.eta,
    required this.atd,
    required this.onEtdChanged,
    required this.onEtaChanged,
    required this.onAtdChanged,
    required this.onClearAtd,
    required this.freeDemurrageController,
    required this.expectedWhDaysController,
    this.onExpectedWhDaysChanged,
    required this.status,
    required this.onStatusChanged,
    required this.vesselNameController,
    required this.voyageNoController,
    required this.releaseOrderNoController,
  });

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime? current,
    required DateTime fallback,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? fallback,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) onPicked(d);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final int delayDays = (atd != null && etd != null) ? atd!.difference(etd!).inDays : 0;
    final int whDays = int.tryParse(expectedWhDaysController.text.trim()) ?? 7;
    final DateTime? computedWhArrival =
        eta?.add(Duration(days: (delayDays > 0 ? delayDays : 0) + whDays));

    final portItems = [
      for (final p in ports)
        SearchableDropdownItem<String>(value: p.locationName, label: p.locationName, subtitle: p.locationType),
    ];
    final polValue = polController.text.trim().isEmpty ? null : polController.text;
    final podValue = podController.text.trim().isEmpty ? null : podController.text;

    String? reqText(String? v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CcFormSection(
          title: l.fbkSectionCarrierRoute,
          icon: Icons.alt_route,
          child: Column(
            children: [
              CcFieldRow(
                children: [
                  CcField(
                    label: l.freightBookingShippingLineLabel,
                    child: SearchableDropdownField<String>(
                      value: shippingLineName,
                      labelText: l.freightBookingShippingLineLabel,
                      searchHintText: l.freightBookingShippingLineHint,
                      hintText: l.fbkSelectHint,
                      decoration: ccInputDecoration(hint: l.fbkSelectHint),
                      validator: (_) => reqText(shippingLineName) == null ? null : l.fbkValidatorShippingLine,
                      items: [
                        for (final s in shippingLines)
                          SearchableDropdownItem<String>(value: s.partnerName, label: s.partnerName, subtitle: s.partnerType),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          final match = shippingLines.where((s) => s.partnerName == val).firstOrNull;
                          onShippingLineChanged(val, match?.providerId);
                        }
                      },
                    ),
                  ),
                  CcField(
                    label: l.freightBookingForwarderLabel,
                    child: SearchableDropdownField<String>(
                      value: freightForwarderName,
                      labelText: l.freightBookingForwarderLabel,
                      searchHintText: l.freightBookingForwarderHint,
                      hintText: l.fbkSelectHint,
                      decoration: ccInputDecoration(hint: l.fbkSelectHint),
                      items: [
                        for (final f in freightForwarders)
                          SearchableDropdownItem<String>(value: f.partnerName, label: f.partnerName, subtitle: f.partnerType),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          final match = freightForwarders.where((f) => f.partnerName == val).firstOrNull;
                          onFreightForwarderChanged(val, match?.providerId);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CcFieldRow(
                children: [
                  CcField(
                    label: l.freightBookingPolLabel,
                    child: SearchableDropdownField<String>(
                      value: polValue,
                      labelText: l.freightBookingPolLabel,
                      searchHintText: l.freightBookingPolHint,
                      hintText: l.fbkSelectHint,
                      decoration: ccInputDecoration(hint: l.fbkSelectHint),
                      validator: (_) => reqText(polController.text) == null ? null : l.fbkValidatorPol,
                      items: portItems,
                      onChanged: (val) {
                        if (val != null) {
                          final match = ports.where((p) => p.locationName == val).firstOrNull;
                          onPolChanged(val, match?.locationId);
                        }
                      },
                    ),
                  ),
                  CcField(
                    label: l.freightBookingPodLabel,
                    child: SearchableDropdownField<String>(
                      value: podValue,
                      labelText: l.freightBookingPodLabel,
                      searchHintText: l.freightBookingPodHint,
                      hintText: l.fbkSelectHint,
                      decoration: ccInputDecoration(hint: l.fbkSelectHint),
                      validator: (_) => reqText(podController.text) == null ? null : l.fbkValidatorPod,
                      items: portItems,
                      onChanged: (val) {
                        if (val != null) {
                          final match = ports.where((p) => p.locationName == val).firstOrNull;
                          onPodChanged(val, match?.locationId);
                        }
                      },
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CcFieldRow(
                children: [
                  FbkDateField(
                    label: l.freightBookingEtdLabel,
                    value: etd,
                    placeholder: l.fbkSelectDate,
                    validator: (_) => etd == null ? l.fbkValidatorEtd : null,
                    onTap: () => _pickDate(
                      context: context,
                      current: etd,
                      fallback: DateTime.now(),
                      onPicked: onEtdChanged,
                    ),
                  ),
                  FbkDateField(
                    label: l.freightBookingEtaLabel,
                    value: eta,
                    placeholder: l.fbkSelectDate,
                    validator: (_) => eta == null ? l.fbkValidatorEta : null,
                    onTap: () => _pickDate(
                      context: context,
                      current: eta,
                      fallback: etd ?? DateTime.now(),
                      onPicked: onEtaChanged,
                    ),
                  ),
                  FbkDateField(
                    label: l.freightBookingAtdLabel,
                    value: atd,
                    placeholder: l.freightBookingPendingDate,
                    onTap: () => _pickDate(
                      context: context,
                      current: atd,
                      fallback: etd ?? DateTime.now(),
                      onPicked: onAtdChanged,
                    ),
                    onClear: onClearAtd,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FbkNotice(
                message: delayDays > 0 ? l.freightBookingDelayBannerDelayed(delayDays) : l.freightBookingDelayBannerOnTime,
                severity: delayDays > 0 ? AppSeverity.danger : AppSeverity.success,
                icon: delayDays > 0 ? Icons.alarm_off : Icons.check_circle,
                trailing: computedWhArrival == null
                    ? null
                    : l.freightBookingExpectedWhArrival(FbkFormat.pickedDate(computedWhArrival)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CcFormSection(
          title: l.fbkSectionTerms,
          icon: Icons.rule,
          child: CcFieldRow(
            children: [
              CcField(
                label: l.freightBookingFreeDaysInput,
                child: TextFormField(
                  controller: freeDemurrageController,
                  keyboardType: TextInputType.number,
                  decoration: ccInputDecoration(prefix: Icons.timelapse_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    return (n == null || n < 0) ? l.fbkValidatorFreeDays : null;
                  },
                ),
              ),
              CcField(
                label: l.freightBookingWarehouseDaysInput,
                child: TextFormField(
                  controller: expectedWhDaysController,
                  keyboardType: TextInputType.number,
                  decoration: ccInputDecoration(prefix: Icons.warehouse_outlined),
                  onChanged: onExpectedWhDaysChanged,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l.fbkWarehouseExpectedDaysRequired;
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return l.fbkWarehouseExpectedDaysInvalid;
                    return null;
                  },
                ),
              ),
              CcField(
                label: l.freightBookingStatusInputLabel,
                child: SearchableDropdownField<String>(
                  value: status,
                  labelText: l.freightBookingStatusInputLabel,
                  searchHintText: l.freightBookingFilterStatusHint,
                  hintText: l.fbkSelectHint,
                  decoration: ccInputDecoration(hint: l.fbkSelectHint),
                  items: [
                    SearchableDropdownItem(value: 'Draft', label: l.freightBookingStatusDraft),
                    SearchableDropdownItem(value: 'Booking Requested', label: l.freightBookingStatusRequested),
                    SearchableDropdownItem(value: 'Cancelled', label: l.fbkStatusCancelled),
                    if (!const {'Draft', 'Booking Requested', 'Cancelled'}.contains(status))
                      SearchableDropdownItem(value: status, label: FbkUi.status(l, status).label),
                  ],
                  onChanged: (v) {
                    if (v != null) onStatusChanged(v);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CcFormSection(
          title: l.fbkSectionVessel,
          icon: Icons.directions_boat_filled_outlined,
          child: CcFieldRow(
            children: [
              CcField(
                label: l.freightBookingVesselNameInput,
                child: TextFormField(
                  controller: vesselNameController,
                  decoration: ccInputDecoration(prefix: Icons.directions_boat_filled_outlined),
                ),
              ),
              CcField(
                label: l.freightBookingVoyageNoInput,
                child: TextFormField(
                  controller: voyageNoController,
                  textDirection: TextDirection.ltr,
                  decoration: ccInputDecoration(prefix: Icons.tag),
                ),
              ),
              CcField(
                label: l.freightBookingReleaseOrderInput,
                child: TextFormField(
                  controller: releaseOrderNoController,
                  textDirection: TextDirection.ltr,
                  decoration: ccInputDecoration(prefix: Icons.assignment_turned_in_outlined),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
