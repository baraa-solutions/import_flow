import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../external_service_providers/providers/partners_provider.dart';
import '../../../transport_locations/providers/transport_locations_provider.dart';
import '../../models/inland_transport_model.dart';
import 'inland_transport_dialogs.dart';
import 'inland_transport_header.dart';

/// Single row showing a label-value pair in the trucking overview card.
class InlandInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InlandInfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context), fontWeight: FontWeight.w500)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Overview card showing existing booking details and inline status actions.
class InlandTransportTruckingCard extends StatelessWidget {
  final InlandTransportModel booking;
  final bool showBookingForm;
  final VoidCallback onToggleEdit;
  final Widget? actionWidget;

  const InlandTransportTruckingCard({
    super.key,
    required this.booking,
    required this.showBookingForm,
    required this.onToggleEdit,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  l10n.inlandCurrentBookingTitle(booking.transportCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!InlandStatus.isArrivedOrDelivered(booking.status)) ...[
                const SizedBox(width: 8),
                AppButton(
                  key: const Key('inlandEditBookingBtn'),
                  label: showBookingForm ? l10n.inlandHideForm : l10n.inlandEditBookingBtn,
                  icon: showBookingForm ? Icons.expand_less : Icons.edit,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: onToggleEdit,
                ),
              ],
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              InlandInfoRow(l10n.inlandInfoCarrier, booking.carrierName),
              InlandInfoRow(l10n.inlandInfoWaybill, booking.waybillNumber),
              InlandInfoRow(l10n.inlandInfoTruckType, DomainEnums.label(l10n, DomainEnumType.truckType, booking.truckType)),
              InlandInfoRow(l10n.inlandInfoPlate, booking.truckPlateNumber),
              InlandInfoRow(l10n.inlandInfoDriver, '${booking.driverName} (${booking.driverPhone})'),
              if (booking.containerNumbers != null) InlandInfoRow(l10n.inlandInfoContainers, booking.containerNumbers!),
              InlandInfoRow(l10n.inlandInfoPickup, booking.pickupPortLocation),
              InlandInfoRow(l10n.inlandInfoDestination, booking.destinationWarehouse),
              InlandInfoRow(l10n.inlandInfoPlannedDeparture, booking.plannedDepartureAt.split('T').first),
              InlandInfoRow(l10n.inlandInfoExpectedArrival, booking.expectedArrivalAt.split('T').first),
              if (booking.actualDepartureAt != null) InlandInfoRow(l10n.inlandInfoActualDeparture, booking.actualDepartureAt!.split('T').first),
              if (booking.actualArrivalAt != null) InlandInfoRow(l10n.inlandInfoActualArrival, booking.actualArrivalAt!.split('T').first),
            ],
          ),
          if (actionWidget != null) ...[
            const SizedBox(height: 16),
            actionWidget!,
          ],
        ],
      ),
    );
  }
}

/// Booking form for creating or updating inland transport dispatch.
class InlandTransportBookingForm extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final bool isEditing;
  final bool isSubmitting;
  final int? carrierId;
  final ValueChanged<int?> onCarrierChanged;
  final String truckType;
  final ValueChanged<String> onTruckTypeChanged;
  final DateTime plannedDepartureDate;
  final ValueChanged<DateTime> onPlannedDepartureDateChanged;
  final TimeOfDay plannedDepartureTime;
  final ValueChanged<TimeOfDay> onPlannedDepartureTimeChanged;
  final DateTime expectedArrivalDate;
  final ValueChanged<DateTime> onExpectedArrivalDateChanged;
  final TimeOfDay expectedArrivalTime;
  final ValueChanged<TimeOfDay> onExpectedArrivalTimeChanged;
  final InlandBookingControllers controllers;
  final ValueChanged<String> onPickupLocationChanged;
  final VoidCallback onSubmit;

  const InlandTransportBookingForm({
    super.key,
    required this.formKey,
    required this.isEditing,
    required this.isSubmitting,
    required this.carrierId,
    required this.onCarrierChanged,
    required this.truckType,
    required this.onTruckTypeChanged,
    required this.plannedDepartureDate,
    required this.onPlannedDepartureDateChanged,
    required this.plannedDepartureTime,
    required this.onPlannedDepartureTimeChanged,
    required this.expectedArrivalDate,
    required this.onExpectedArrivalDateChanged,
    required this.expectedArrivalTime,
    required this.onExpectedArrivalTimeChanged,
    required this.controllers,
    required this.onPickupLocationChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final carrierList = transportPartners.isNotEmpty ? transportPartners : partners.where((p) => p.isActive).toList();
    final carrierItems = buildCarrierDropdownItems(carrierList: carrierList, carrierId: carrierId, carrierName: controllers.carrierName.text);
    final locations = ref.watch(transportLocationsProvider).valueOrNull ?? [];
    final locationItems = buildLocationDropdownItems(locations: locations, selectedLocation: controllers.pickupLocation.text);
    final truckTypes = [
      ...DomainEnums.codesOf(DomainEnumType.truckType),
      if (!DomainEnums.isCode(DomainEnumType.truckType, truckType)) truckType,
    ];

    return Form(
      key: formKey,
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
                    isEditing ? l10n.inlandEditBookingBtn : l10n.inlandFormTitle,
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
                  child: InlandTextFormField(
                    fieldKey: const Key('inlandWaybillNoField'),
                    controller: controllers.waybill,
                    label: l10n.inlandWaybillLabel,
                    icon: Icons.receipt,
                    ltr: true,
                    validator: (v) => required(v, l10n.inlandWaybillRequired),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SearchableDropdownField<int>(
                    key: const Key('inlandCarrierDropdown'),
                    labelText: l10n.inlandCarrierLabel,
                    hintText: controllers.carrierName.text.isNotEmpty ? controllers.carrierName.text : l10n.inlandSelectCarrierHint,
                    value: carrierId,
                    items: carrierItems,
                    onChanged: (val) {
                      onCarrierChanged(val);
                      if (val != null) {
                        final chosen = carrierList.firstWhere((p) => p.providerId == val, orElse: () => partners.firstWhere((p) => p.providerId == val));
                        controllers.carrierName.text = chosen.partnerName;
                      }
                    },
                    validator: (val) => (val == null && controllers.carrierName.text.trim().isEmpty) ? l10n.inlandCarrierRequired : null,
                  ),
                ),
              ],
            ),
            SizedBox(
              width: 0,
              height: 0,
              child: TextFormField(
                key: const Key('inlandCarrierNameField'),
                controller: controllers.carrierName,
                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InlandTextFormField(
                    fieldKey: const Key('inlandTruckPlateField'),
                    controller: controllers.truckPlate,
                    label: l10n.inlandPlateLabel,
                    icon: Icons.confirmation_number,
                    hint: l10n.inlandPlateHint,
                    validator: (v) => minLen(v, 3, l10n.inlandPlateInvalid),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SearchableDropdownField<String>(
                    key: const Key('inlandTruckTypeDropdown'),
                    labelText: l10n.inlandTruckTypeLabel,
                    hintText: l10n.inlandTruckTypeHint,
                    value: truckType,
                    items: truckTypes.map((t) => SearchableDropdownItem<String>(value: t, label: DomainEnums.label(l10n, DomainEnumType.truckType, t))).toList(),
                    onChanged: (val) {
                      if (val != null) onTruckTypeChanged(val);
                    },
                    validator: (val) => (val == null || val.isEmpty) ? l10n.inlandTruckTypeRequired : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InlandDriverFormSection(
              nameController: controllers.driverName,
              phoneController: controllers.driverPhone,
              nationalIdController: controllers.driverNationalId,
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
                    value: controllers.pickupLocation.text.isEmpty ? null : controllers.pickupLocation.text,
                    items: locationItems,
                    onChanged: (val) {
                      if (val != null) onPickupLocationChanged(val);
                    },
                    validator: (val) => ((val == null || val.trim().isEmpty) && controllers.pickupLocation.text.trim().isEmpty) ? l10n.inlandPickupRequired : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InlandTextFormField(
                    controller: controllers.destinationWarehouse,
                    label: l10n.inlandWarehouseLabel,
                    icon: Icons.warehouse,
                    validator: (v) => required(v, l10n.inlandWarehouseRequired),
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
                  child: InlandTextFormField(
                    controller: controllers.containerNumbers,
                    label: l10n.inlandContainersLabel,
                    icon: Icons.view_in_ar,
                    ltr: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: InlandTextFormField(
                    fieldKey: const Key('inlandFareEgpField'),
                    controller: controllers.fareEgp,
                    label: l10n.inlandFareLabel,
                    icon: Icons.attach_money,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    suffix: l10n.inlandCurrencySuffix,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l10n.inlandFareRequired;
                      final numVal = double.tryParse(val.trim());
                      return (numVal == null || numVal <= 0) ? l10n.inlandFareInvalid : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InlandSchedulePickersSection(
              plannedDepartureDate: plannedDepartureDate,
              onPlannedDepartureDateChanged: onPlannedDepartureDateChanged,
              plannedDepartureTime: plannedDepartureTime,
              onPlannedDepartureTimeChanged: onPlannedDepartureTimeChanged,
              expectedArrivalDate: expectedArrivalDate,
              onExpectedArrivalDateChanged: onExpectedArrivalDateChanged,
              expectedArrivalTime: expectedArrivalTime,
              onExpectedArrivalTimeChanged: onExpectedArrivalTimeChanged,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controllers.trackingNotes,
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
                label: isEditing ? l10n.inlandSaveChangesBtn : l10n.inlandSubmitBtn,
                variant: AppButtonVariant.success,
                icon: Icons.check_circle,
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
