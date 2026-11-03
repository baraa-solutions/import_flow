import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../freight_booking/models/freight_booking_model.dart';
import '../../models/cargo_shipping_model.dart';

/// Shows a date picker followed by a time picker with validation that date is not before minDate.
Future<String?> pickShippingDateTime(
  BuildContext context, {
  String? initialIso,
  DateTime? minDate,
  String? title,
}) async {
  final now = DateTime.now();
  final initDt = (initialIso != null && initialIso.isNotEmpty)
      ? (DateTime.tryParse(initialIso) ?? now)
      : now;
  final effectiveInit =
      (minDate != null && initDt.isBefore(minDate)) ? minDate : initDt;

  final pickedDate = await showDatePicker(
    context: context,
    initialDate: effectiveInit,
    firstDate: minDate ?? DateTime(2020),
    lastDate: DateTime(2035),
    helpText: title ?? context.l10n.cargoShippingPickMilestone1,
    cancelText: context.l10n.cancel,
    confirmText: context.l10n.confirm,
  );
  if (pickedDate == null) return null;

  if (!context.mounted) return null;

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(effectiveInit),
    helpText: title ?? context.l10n.cargoShippingPickMilestone1,
    cancelText: context.l10n.cancel,
    confirmText: context.l10n.confirm,
  );
  if (pickedTime == null) return null;

  final finalDt = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );

  if (minDate != null && finalDt.isBefore(minDate)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cargoShippingDateSequenceError,
          severity: AppSeverity.danger,
        ),
      );
    }
    return null;
  }

  return finalDt.toIso8601String();
}

/// Confirmation dialog for removing a container allocation.
Future<bool> confirmDeleteContainer(BuildContext context) async {
  return await AppConfirmDialog.show(
    context,
    title: context.l10n.delete,
    message: context.l10n.cargoShippingDeleteConfirmTitle,
    confirmVariant: AppButtonVariant.danger,
  );
}

/// Warning dialog displayed when attempting to save a duplicate cargo shipping record.
Future<bool> showDuplicateShippingRecordDialog(
  BuildContext context,
  String errorMsg,
) async {
  return await AppConfirmDialog.show(
    context,
    title: context.l10n.cargoShippingDuplicateWarningTitle,
    message: errorMsg,
    icon: Icons.warning_amber_rounded,
    confirmLabel: context.l10n.cargoShippingGoToSavedRegistry,
    cancelLabel: context.l10n.close,
    confirmVariant: AppButtonVariant.warning,
  );
}

/// Extracts a clean error message from an exception or Dio response.
String formatCargoShippingError(dynamic e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['detail'] != null) return d['detail'].toString();
    return e.message ?? 'Server error';
  }
  return e.toString().replaceAll('Exception:', '').trim();
}

/// Helper building default container loading models from a freight booking model.
List<ContainerLoadingModel> buildContainersFromBooking(
  ShipmentBookingModel booking,
  String nowIso,
) {
  final List<ContainerLoadingModel> loaded = [];
  for (final alloc in booking.containersData) {
    final count = alloc.quantity > 0
        ? alloc.quantity
        : (alloc.individualContainers.isNotEmpty ? alloc.individualContainers.length : 1);
    for (int uIdx = 0; uIdx < count; uIdx++) {
      final indiv = uIdx < alloc.individualContainers.length
          ? alloc.individualContainers[uIdx]
          : null;
      final cNo = indiv?.containerNumber ?? '';
      final sNo = indiv?.sealNumber ?? '';
      final vgm = (indiv != null && indiv.vgmWeightKg > 0) ? indiv.vgmWeightKg : 0.0;
      loaded.add(
        ContainerLoadingModel(
          containerType: alloc.containerType.isNotEmpty ? alloc.containerType : '40HC',
          quantity: 1,
          containerNo: cNo,
          sealNo: sNo,
          grossWeightKg: vgm,
          vgmStatus: 'Pending',
          containerAssignmentDate: nowIso,
          trackingStatus: 'ASSIGNED',
          individualUnits: [
            {'container_no': cNo, 'seal_no': sNo}
          ],
        ),
      );
    }
  }
  return loaded;
}
