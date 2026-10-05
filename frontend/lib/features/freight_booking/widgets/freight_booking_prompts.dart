import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../models/freight_booking_model.dart';
import 'freight_booking_ui.dart';

/// Small confirmation prompts of the freight-booking screens (all return a
/// value; none of them touches providers).
class FbkPrompts {
  FbkPrompts._();

  /// "Are you sure you want to delete booking X?" -> true when confirmed.
  static Future<bool> confirmDelete(BuildContext context, String bookingCode) async {
    final l = context.l10n;
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => FbkPromptDialog(
        title: l.freightBookingDeleteConfirmTitle,
        icon: Icons.delete_outline,
        severity: AppSeverity.danger,
        content: Text(
          l.freightBookingDeleteConfirmMessage(bookingCode),
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(c)),
        ),
        actions: [
          AppButton(
            label: l.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(c, false),
          ),
          AppButton(
            label: l.delete,
            icon: Icons.delete_outline,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    return res == true;
  }

  /// Container allocation differs from the recommendation: proceed?
  static Future<bool> confirmMismatch(BuildContext context, String assigned, String suggested) async {
    final l = context.l10n;
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FbkPromptDialog(
        title: l.freightBookingMismatchTitle,
        icon: Icons.warning_amber_rounded,
        severity: AppSeverity.warning,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FbkNotice(
              message: l.freightBookingMismatchWarning(assigned, suggested),
              severity: AppSeverity.warning,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
            Text(l.freightBookingMismatchPrompt,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(ctx))),
            const SizedBox(height: 8),
            Text(l.freightBookingMismatchNote,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(ctx))),
          ],
        ),
        actions: [
          AppButton(
            label: l.freightBookingMismatchBtnNo,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: l.freightBookingMismatchBtnYes,
            variant: AppButtonVariant.warning,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return res == true;
  }

  /// Mandatory reason for a container mismatch -> trimmed text or null (cancel).
  static Future<String?> askMismatchReason(BuildContext context) async {
    final l = context.l10n;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FbkPromptDialog(
        title: l.freightBookingMismatchReasonTitle,
        icon: Icons.edit_note_rounded,
        severity: AppSeverity.info,
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            decoration: ccInputDecoration().copyWith(labelText: l.freightBookingMismatchReasonHint),
            validator: (v) => (v == null || v.trim().isEmpty) ? l.freightBookingMismatchReasonValidator : null,
          ),
        ),
        actions: [
          AppButton(label: l.cancel, variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(ctx, false)),
          AppButton(
            label: l.freightBookingMismatchReasonConfirm,
            variant: AppButtonVariant.primary,
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
    // Not disposed here: the route is still animating out when the future completes.
    return ok == true ? controller.text.trim() : null;
  }

  /// An active booking already exists for the chosen import file. Returns true
  /// when the user wants to edit the existing booking instead.
  static Future<bool> duplicateBooking(
    BuildContext context, {
    required ShipmentBookingModel existing,
    required String fileLabel,
  }) async {
    final l = context.l10n;
    Widget row(String label, String value, {bool mono = false}) => Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryOf(context))),
              ),
              Expanded(
                child: mono
                    ? LtrText(value,
                        style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600))
                    : Text(value,
                        style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FbkPromptDialog(
        title: l.freightBookingDuplicateTitle,
        icon: Icons.warning_amber_rounded,
        severity: AppSeverity.warning,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FbkNotice(message: l.freightBookingDuplicateMessage, severity: AppSeverity.warning, icon: Icons.copy_all),
            const SizedBox(height: 10),
            row(l.freightBookingDuplicateRowFile, fileLabel),
            row(l.freightBookingDuplicateRowCode, existing.bookingCode, mono: true),
            row(l.freightBookingDuplicateRowConfirmNo,
                existing.bookingConfirmationNo ?? l.freightBookingDraftPendingLabel,
                mono: existing.bookingConfirmationNo != null),
            row(l.freightBookingDuplicateRowLine, FbkFormat.orDash(existing.shippingLineName)),
            row(l.freightBookingDuplicateRowStatus, FbkUi.status(l, existing.status).label),
            if (existing.owner.isNotEmpty) row(l.fbkDupOwner, existing.owner),
            row(l.fbkDupLastUpdated, existing.updatedAt),
            const Divider(height: 20),
            Text(l.freightBookingDuplicateNotice,
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(ctx))),
          ],
        ),
        actions: [
          AppButton(
            label: l.freightBookingDuplicateBtnCancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: l.freightBookingDuplicateBtnSwitch,
            icon: Icons.edit_note_rounded,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return res == true;
  }
}
