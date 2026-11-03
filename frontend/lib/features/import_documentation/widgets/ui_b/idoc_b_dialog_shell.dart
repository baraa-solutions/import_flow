import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/ltr_text.dart';

/// One action of an [IdocBDialogShell] footer.
class IdocBDialogAction {
  const IdocBDialogAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.secondary,
    this.buttonKey,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final Key? buttonKey;
  final bool isLoading;
}

/// Frame of the package-B dialogs: charcoal header (icon, title, optional
/// chip, close), scrollable body and a footer with the standard buttons.
class IdocBDialogShell extends StatelessWidget {
  const IdocBDialogShell({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    required this.actions,
    this.subtitle,
    this.badge,
    this.accent = AppTheme.cobalt,
    this.maxWidth = 760,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget body;
  final List<IdocBDialogAction> actions;

  /// Header chip (declaration / certificate number): rendered LTR.
  final String? badge;
  final Color accent;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screen = MediaQuery.of(context).size;
    final width = screen.width > maxWidth + 40 ? maxWidth : screen.width * 0.95;
    final onDark = AppTheme.white.withValues(alpha: 0.78);
    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SelectionArea(
        child: Container(
          width: width,
          constraints: BoxConstraints(maxHeight: screen.height * 0.9),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 14),
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
                      child: Icon(icon, color: accent, size: 22),
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
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.white,
                            ),
                          ),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(top: 2),
                              child: Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, color: onDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (badge != null && badge!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: LtrText(
                          badge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: onDark),
                        ),
                      ),
                    ],
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: onDark),
                      tooltip: l.close,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.all(20),
                  child: body,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAltOf(context),
                  borderRadius: const BorderRadiusDirectional.only(
                    bottomStart: Radius.circular(AppTheme.radiusXl),
                    bottomEnd: Radius.circular(AppTheme.radiusXl),
                  ),
                  border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final a in actions)
                      AppButton(
                        key: a.buttonKey,
                        label: a.label,
                        icon: a.icon,
                        variant: a.variant,
                        size: AppButtonSize.small,
                        isLoading: a.isLoading,
                        onPressed: a.onPressed,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer bar of a form screen: neutral actions on the start edge, the
/// primary (save) action on the end edge, in the standard card chrome.
class IdocBActionBar extends StatelessWidget {
  const IdocBActionBar({
    super.key,
    required this.primary,
    this.secondary = const [],
  });

  final List<Widget> primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecorationOf(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: secondary),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: primary),
        ],
      ),
    );
  }
}
