import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../../import_documentation/widgets/draft_bl_review_dialog.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/freight_booking_model.dart';
import '../../providers/freight_booking_provider.dart';
import '../air_lcl_details_dialog.dart';
import '../departure_confirmation_dialog.dart';
import '../freight_booking_confirm_dialog.dart';
import '../freight_booking_form_dialog.dart';
import '../freight_booking_print_dialog.dart';
import '../freight_booking_prompts.dart';
import '../freight_booking_ui.dart';
import '../freight_booking_view_dialog.dart';
import '../search_and_clone_freight_booking_dialog.dart';
import '../vessel_eta_tracking_dialog.dart';

class FreightBookingDialogHelper {
  static void showAddEditBookingDialog(
    BuildContext context, [
    ShipmentBookingModel? bookingToEdit,
    bool isClone = false,
  ]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FreightBookingFormDialog(bookingToEdit: bookingToEdit, isClone: isClone),
    );
  }

  static void showViewBookingDialog(BuildContext context, ShipmentBookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => FreightBookingViewDialog(booking: booking),
    );
  }

  static void showPrintBookingDialog(BuildContext context, ShipmentBookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => FreightBookingPrintDialog(booking: booking),
    );
  }

  static void showConfirmBookingDialog(BuildContext context, ShipmentBookingModel booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FreightBookingConfirmDialog(booking: booking),
    );
  }

  static void showAirLclDetailsDialog(BuildContext context, ShipmentBookingModel booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AirLclDetailsDialog(booking: booking),
    );
  }

  static void showDepartureConfirmationDialog(BuildContext context, ShipmentBookingModel booking) {
    DepartureConfirmationDialog.show(context, booking);
  }

  static void showEtaTrackingDialog(BuildContext context, ShipmentBookingModel booking) {
    VesselEtaTrackingDialog.show(context, booking);
  }

  static void showDraftBlReviewDialog(BuildContext context, WidgetRef ref, ShipmentBookingModel booking) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchingFile = files.where((f) => f.importFileId == booking.importFileId).firstOrNull;
    final file = matchingFile ??
        ImportFileModel(
          importFileId: booking.importFileId ?? 0,
          importFileCode: booking.importFileCode ?? 'IMP-${booking.bookingCode}',
          companyName: '',
          supplierName: '',
          currentModule: 'ImportFiles',
          currentStage: 'Phase 5 - Sailing & CargoX',
          nextAction: 'Review Draft BL',
          createdAt: '',
          updatedAt: '',
        );
    DraftBLReviewDialog.show(context, file);
  }

  static void openSearchAndCloneDialog({
    required BuildContext context,
    required List<ShipmentBookingModel> bookings,
    required void Function(ShipmentBookingModel selected) onClone,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => SearchAndCloneFreightBookingDialog(
        bookings: bookings,
        onSelectBooking: onClone,
      ),
    );
  }

  static Future<void> confirmDelete({
    required BuildContext context,
    required WidgetRef ref,
    required ShipmentBookingModel bkg,
  }) async {
    final l = context.l10n;
    final confirmed = await FbkPrompts.confirmDelete(context, bkg.bookingCode);
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(freightBookingProvider.notifier).softDeleteBooking(bkg.bookingId);
    } catch (e) {
      if (context.mounted) {
        FbkUi.snack(context, '${l.error}: ${ApiErrorText.of(l, e)}', severity: AppSeverity.danger);
      }
    }
  }

  static Future<void> confirmCancel({
    required BuildContext context,
    required WidgetRef ref,
    required ShipmentBookingModel bkg,
  }) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => FbkPromptDialog(
        title: l.fbkCancelBookingTitle,
        icon: Icons.cancel_outlined,
        severity: AppSeverity.danger,
        content: Text(
          l.fbkCancelBookingConfirm,
          style: TextStyle(color: AppTheme.textPrimaryOf(ctx)),
        ),
        actions: [
          AppButton(
            label: l.cancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            key: const Key('confirmCancelBookingBtn'),
            label: l.fbkCancelBookingTitle,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(freightBookingProvider.notifier).updateBooking(bkg.bookingId, {'status': 'Cancelled'});
      if (context.mounted) {
        FbkUi.snack(context, l.fbkCancelBookingSuccess, severity: AppSeverity.success);
      }
    } catch (e) {
      if (context.mounted) {
        FbkUi.snack(context, '${l.error}: ${ApiErrorText.of(l, e)}', severity: AppSeverity.danger);
      }
    }
  }

  static void onCloneBooking({
    required BuildContext context,
    required ShipmentBookingModel booking,
  }) {
    final l = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => CloneEntityReviewDialog(
        entityType: l.fbkCloneEntityType,
        sourceCode: booking.bookingCode,
        suggestedNewCode: l.fbkCodeAssignedOnSave,
        sourceTitle: '${booking.shippingLineName ?? "—"} (${booking.polName ?? "—"} ➔ ${booking.podName ?? "—"})',
        copiedFieldsSummary: {
          l.freightBookingColCarrierForwarder: '${booking.shippingLineName ?? "—"} / ${booking.freightForwarderName ?? "—"}',
          l.freightBookingColRoute: '${booking.polName ?? "—"} ➔ ${booking.podName ?? "—"}',
          l.freightBookingColContainers: booking.containersData.map((c) => "${c.quantity}x ${c.containerType}").join(", "),
          l.freightBookingColTotalFreight: booking.totalFreightCostUsd == null ? CcFormat.unknown : '\$${booking.totalFreightCostUsd!.toStringAsFixed(2)} USD',
        },
        mandatorilyResetFields: [
          l.fbkCloneReset1,
          l.fbkCloneReset2,
          l.fbkCloneReset3,
          l.fbkCloneReset4,
          l.fbkCloneResetFile,
          l.fbkCloneResetDates,
        ],
        allowCopyLineItems: true,
        allowCopyAttachments: false,
        onConfirm: ({
          required String newCode,
          required String newTitle,
          required bool copyLineItems,
          required bool copyAttachments,
          String? notes,
        }) async {
          final cloned = ShipmentBookingModel(
            bookingId: 0,
            bookingCode: newCode,
            bookingConfirmationNo: '',
            importFileId: null,
            importFileCode: null,
            shippingLineId: booking.shippingLineId,
            shippingLineName: booking.shippingLineName,
            freightForwarderId: booking.freightForwarderId,
            freightForwarderName: booking.freightForwarderName,
            polLocationId: booking.polLocationId,
            polName: booking.polName,
            podLocationId: booking.podLocationId,
            podName: booking.podName,
            vesselName: booking.vesselName,
            voyageNumber: booking.voyageNumber,
            etd: null,
            eta: null,
            atd: null,
            expectedWarehouseArrivalDate: null,
            containersData: copyLineItems ? booking.containersData : [],
            costChargesData: copyLineItems ? booking.costChargesData : [],
            totalFreightCostUsd: booking.totalFreightCostUsd,
            status: 'Draft',
            departureDelayDays: 0,
            isActive: true,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          );

          if (context.mounted) {
            FbkUi.snack(context, '${l.cloneBookingRowTooltip}: $newCode', severity: AppSeverity.info);
            showAddEditBookingDialog(context, cloned, true);
          }
        },
      ),
    );
  }
}
