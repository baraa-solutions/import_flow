import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/freight_booking_model.dart';

/// Display helpers shared by the freight-booking widgets (presentation only).
class FbkFormat {
  FbkFormat._();

  /// `yyyy-MM-dd` of an ISO string, or an em dash when missing.
  static String isoDate(String? raw) =>
      raw != null && raw.length >= 10 ? raw.substring(0, 10) : '—';

  /// `yyyy-MM-dd` of a picked date (empty when not picked).
  static String pickedDate(DateTime? d) => d == null ? '' : CcFormat.date(d);

  /// `2x 40HC, 1x 20GP` (em dash when nothing is allocated).
  static String containers(ShipmentBookingModel b) => b.containersData.isEmpty
      ? '—'
      : b.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', ');

  static String orDash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  /// Resolves the import file code for an id from the given list of files.
  static String? fileCodeFor(int? id, List<ImportFileModel> files) {
    if (id == null) return null;
    for (final f in files) {
      if (f.importFileId == id) return f.importFileCode;
    }
    return null;
  }
}

/// Status style of a booking (chip colour / label / icon).
class FbkUi {
  FbkUi._();

  static ({AppSeverity severity, String label, IconData icon}) status(
      AppLocalizations l, String status) {
    switch (status) {
      case 'Confirmed':
        return (
          severity: AppSeverity.success,
          label: l.freightBookingStatusConfirmed,
          icon: Icons.verified_outlined
        );
      case 'Sailed':
        return (
          severity: AppSeverity.info,
          label: l.freightBookingStatusSailed,
          icon: Icons.sailing_rounded
        );
      case 'Booking Requested':
        return (
          severity: AppSeverity.warning,
          label: l.freightBookingStatusRequested,
          icon: Icons.schedule_send_outlined
        );
      case 'Draft':
        return (
          severity: AppSeverity.warning,
          label: l.freightBookingStatusDraft,
          icon: Icons.edit_note_rounded
        );
      case 'Amended':
        return (
          severity: AppSeverity.info,
          label: l.fbkStatusAmended,
          icon: Icons.published_with_changes_outlined
        );
      case 'Cancelled':
        return (
          severity: AppSeverity.danger,
          label: l.fbkStatusCancelled,
          icon: Icons.cancel_outlined
        );
      default:
        return (severity: AppSeverity.info, label: status, icon: Icons.info_outline);
    }
  }

  static bool canConfirm(String? status) =>
      status == 'Draft' || status == 'Booking Requested' || status == 'Amended';

  static bool canDepart(String? status) =>
      status == 'Confirmed' || status == 'Amended';

  static bool canDelete(String? status) =>
      status == 'Draft' || status == 'Booking Requested' || status == 'Cancelled';

  static bool canCancel(String? status) =>
      status != null && status != 'Cancelled' && status != 'Sailed';

  /// Floating severity SnackBar (single entry point for the whole feature).
  static void snack(BuildContext context, String message,
      {AppSeverity severity = AppSeverity.info}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(AppTheme.snackBar(context, message, severity: severity));
  }

  /// Lets a (non-flexible) AppButton shrink instead of overflowing.
  static Widget fit(Widget button) => CcUi.fit(button);
}

/// Coloured inline notice (info / success / warning / danger) with an icon.
class FbkNotice extends StatelessWidget {
  const FbkNotice({
    super.key,
    required this.message,
    this.severity = AppSeverity.info,
    this.icon,
    this.trailing,
  });

  final String message;
  final AppSeverity severity;
  final IconData? icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Icon(icon ?? Icons.info_outline, size: 18, color: fg),
          Text(
            message,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
            ),
        ],
      ),
    );
  }
}

/// Small prompt dialog (icon + title, body, action buttons) used for the
/// duplicate / mismatch / delete confirmations of the booking screens.
class FbkPromptDialog extends StatelessWidget {
  const FbkPromptDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    required this.actions,
    this.severity = AppSeverity.warning,
    this.maxWidth = 520,
  });

  final String title;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;
  final AppSeverity severity;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    final width = (MediaQuery.of(context).size.width - 32).clamp(280.0, maxWidth);
    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SelectionArea(
        child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.all(8),
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Icon(icon, color: fg, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(child: SingleChildScrollView(child: content)),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Date picker field (a [FormField] so required dates show a red error).
class FbkDateField extends FormField<DateTime> {
  FbkDateField({
    super.key,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required String placeholder,
    VoidCallback? onClear,
    bool isRequired = false,
    super.validator,
  }) : super(
          initialValue: value,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (state) {
            final tile = Row(
              children: [
                Expanded(child: CcDateTile(date: value, onTap: onTap, placeholder: placeholder)),
                if (onClear != null && value != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: onClear,
                  ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CcField(label: label, isRequired: isRequired, child: tile),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4, start: 12),
                    child: Text(
                      state.errorText!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.crimson),
                    ),
                  ),
              ],
            );
          },
        );
}

/// Cost comparison: quoted price vs executed price vs difference, with an
/// optional per-charge savings breakdown. Used by the form (compact) and the
/// read-only view dialog.
class FbkSavingsSummary extends StatelessWidget {
  const FbkSavingsSummary({
    super.key,
    required this.original,
    required this.executed,
    required this.hasSavings,
    required this.hasIncrease,
    this.providerName,
    this.breakdownLines = const [],
    this.notes,
  });

  final double original;
  final double executed;
  final bool hasSavings;
  final bool hasIncrease;
  final String? providerName;
  final List<String> breakdownLines;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final diff = (original - executed).abs();
    final pct = original > 0 ? (diff / original * 100) : 0.0;
    final severity = hasSavings
        ? AppSeverity.success
        : (hasIncrease ? AppSeverity.danger : AppSeverity.info);
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    final title = hasSavings
        ? l.freightBookingCostSavingsTitle
        : (hasIncrease ? l.freightBookingCostIncreaseTitle : l.freightBookingNoPriceVariance);
    final badge = hasSavings
        ? l.freightBookingCostSavingsBadgeAmount(diff.toStringAsFixed(2), pct.toStringAsFixed(1))
        : (hasIncrease
            ? l.freightBookingCostIncreaseBadgeAmount(diff.toStringAsFixed(2))
            : l.freightBookingCostMatchBadge);

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Icon(
                hasSavings
                    ? Icons.savings_outlined
                    : (hasIncrease ? Icons.trending_up : Icons.compare_arrows),
                color: fg,
                size: 22,
              ),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: fg)),
              AppStatusBadge(label: badge, severity: severity, size: AppStatusBadgeSize.small),
            ],
          ),
          if (providerName != null && providerName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l.freightBookingBasedOnQuote(providerName!),
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
            ),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 420;
            final cells = [
              _cell(context, l.freightBookingOriginalQuotedPrice, original,
                  AppTheme.textSecondaryOf(context),
                  strike: true),
              _cell(context, l.freightBookingExecutedPrice, executed, AppTheme.cobalt),
              _cell(
                context,
                hasSavings
                    ? l.freightBookingCostSavingsBadge
                    : (hasIncrease ? l.freightBookingCostIncreaseBadge : l.freightBookingNetDifference),
                diff,
                fg,
                prefix: hasSavings ? '-' : '+',
              ),
            ];
            if (narrow) {
              return Column(
                children: [for (final c in cells) Padding(padding: const EdgeInsetsDirectional.only(bottom: 6), child: c)],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: cells[i]),
                ],
              ],
            );
          }),
          if (breakdownLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.freightBookingBreakdownHeader,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                  const SizedBox(height: 4),
                  for (final line in breakdownLines)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.severityForegroundOf(context, AppSeverity.success),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (notes != null && notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes!,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String label, double value, Color color,
      {bool strike = false, String prefix = ''}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          LtrText(
            '$prefix\$ ${CcFormat.money(value)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: strike ? AppTheme.textPrimaryOf(context) : color,
              decoration: strike ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact AppButton row that never overflows (wraps + shrinks).
class FbkButtonWrap extends StatelessWidget {
  const FbkButtonWrap({super.key, required this.buttons, this.alignment = WrapAlignment.start});

  final List<AppButton> buttons;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final b in buttons) FbkUi.fit(b)],
    );
  }
}
