import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Frame of the search-and-clone pickers: charcoal header (icon, title,
/// subtitle, close) over a padded body that scrolls inside its own children.
class ShippingDialogFrame extends StatelessWidget {
  const ShippingDialogFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.maxWidth = 920,
    this.accent = AppTheme.cobalt,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final double maxWidth;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final width = (screen.width - 32).clamp(360.0, maxWidth);
    final onDark = AppTheme.white.withValues(alpha: 0.78);
    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: screen.height * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppTheme.charcoal,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 14),
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.white),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: onDark)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: onDark),
                    tooltip: context.l10n.close,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SelectionArea(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(20),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
