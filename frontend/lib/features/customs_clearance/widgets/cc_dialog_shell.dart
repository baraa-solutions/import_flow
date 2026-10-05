import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import 'customs_ui.dart';

/// Small translucent chip shown in the dark header of a stage dialog
/// (import file code, declaration number, claim number ...).
class CcHeaderChip {
  const CcHeaderChip(this.icon, this.label, {this.ltr = false});

  final IconData icon;
  final String label;

  /// Codes / numbers keep left-to-right order inside the RTL header.
  final bool ltr;
}

/// Shared frame of the customs-clearance stage dialogs (CS-01..03, CL-01..05):
/// charcoal header (icon, title, chips, close), scrollable body, and the
/// standard footer with a neutral cancel and one primary action that shows an
/// in-button spinner while submitting.
class CcStageDialogShell extends StatelessWidget {
  const CcStageDialogShell({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    required this.isSubmitting,
    this.accent = AppTheme.cobalt,
    this.chips = const [],
    this.confirmKey,
    this.cancelKey,
    this.loadingLabel,
    this.confirmIcon = Icons.check_circle_rounded,
    this.confirmVariant = AppButtonVariant.success,
    this.maxWidth = 880,
    this.headerActions = const [],
    this.footerLeading,
    this.onCancel,
    this.closeKey,
    this.showCancel = true,
  });

  final String title;
  final IconData icon;
  final Widget body;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool isSubmitting;
  final Color accent;
  final List<CcHeaderChip> chips;
  final Key? confirmKey;
  final Key? cancelKey;

  /// Label shown on the confirm button while [isSubmitting].
  final String? loadingLabel;
  final IconData confirmIcon;
  final AppButtonVariant confirmVariant;
  final double maxWidth;
  final List<Widget> headerActions;
  final Widget? footerLeading;

  /// Replaces the plain pop of the cancel / close buttons (e.g. unsaved-changes guard).
  final VoidCallback? onCancel;
  final Key? closeKey;

  /// Hide the neutral cancel button (read-only / close-only dialogs).
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screen = MediaQuery.of(context).size;
    final dialogWidth = screen.width > maxWidth + 40 ? maxWidth : screen.width * 0.95;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screen.height * 0.90),
        child: Column(
          children: [
            _header(context, l),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(24),
                child: body,
              ),
            ),
            _footer(context, l),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l) {
    final onDark = AppTheme.white.withValues(alpha: 0.78);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(AppTheme.radiusXl),
          topEnd: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [for (final c in chips) _chip(c, onDark)],
                  ),
                ],
              ],
            ),
          ),
          ...headerActions,
          IconButton(
            key: closeKey,
            onPressed: isSubmitting ? null : (onCancel ?? () => Navigator.of(context).pop()),
            icon: Icon(Icons.close, color: onDark),
            tooltip: l.close,
          ),
        ],
      ),
    );
  }

  Widget _chip(CcHeaderChip c, Color onDark) {
    final style = TextStyle(fontSize: 11, color: onDark);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(c.icon, size: 12, color: onDark),
          const SizedBox(width: 4),
          Flexible(
            child: c.ltr
                ? LtrText(c.label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)
                : Text(c.label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, AppLocalizations l) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(AppTheme.radiusXl),
          bottomEnd: Radius.circular(AppTheme.radiusXl),
        ),
        border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 760 && footerLeading != null;
          final buttons = Row(
            children: [
              if (showCancel)
              AppButton(
                key: cancelKey,
                label: l.cancel,
                icon: Icons.cancel_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: isSubmitting ? null : (onCancel ?? () => Navigator.of(context).pop()),
              ),
              if (footerLeading != null && !narrow)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                    child: footerLeading!,
                  ),
                )
              else
                const Spacer(),
              AppButton(
                key: confirmKey,
                label: isSubmitting ? (loadingLabel ?? confirmLabel) : confirmLabel,
                icon: confirmIcon,
                variant: confirmVariant,
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : onConfirm,
              ),
            ],
          );
          if (!narrow) return buttons;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [footerLeading!, const SizedBox(height: 8), buttons],
          );
        },
      ),
    );
  }
}

/// A form block: icon + title, divider, then [children] (CcSectionCard with the
/// dialog-form spacing).
class CcFormSection extends StatelessWidget {
  const CcFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accent,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent ?? AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: AppTheme.borderOf(context)),
          // Lets ListTile / Switch tiles paint ink on a transparent material
          // instead of tripping over the decorated container.
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

/// Label above a field (the dialogs keep the label as a separate [Text]).
/// Pass [isRequired] to append the standard asterisk.
class CcField extends StatelessWidget {
  const CcField({super.key, required this.label, required this.child, this.isRequired = false});

  final String label;
  final Widget child;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Two fields side by side (stacked on narrow dialogs).
class CcFieldRow extends StatelessWidget {
  const CcFieldRow({super.key, required this.children, this.gap = 16});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 520 && children.length > 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Outlined input look shared by the stage dialogs.
InputDecoration ccInputDecoration({
  String? hint,
  IconData? prefix,
  Widget? suffix,
  String? suffixText,
}) =>
    InputDecoration(
      hintText: hint,
      prefixIcon: prefix == null ? null : Icon(prefix, size: 18),
      suffixIcon: suffix,
      suffixText: suffixText,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
    );

/// Date-picker tile used inside [CcField] (same look as the text fields).
class CcDateTile extends StatelessWidget {
  const CcDateTile({super.key, required this.date, required this.onTap, this.placeholder});

  final DateTime? date;
  final VoidCallback onTap;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderOf(context)),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          color: AppTheme.surfaceOf(context),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Expanded(
              child: date == null
                  ? Text(
                      placeholder ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppTheme.textMutedOf(context)),
                    )
                  : LtrText(
                      CcFormat.date(date!),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
            ),
            Icon(Icons.arrow_drop_down, color: AppTheme.textSecondaryOf(context)),
          ],
        ),
      ),
    );
  }
}
