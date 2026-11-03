import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Two-step switcher of the loading form (container assignment / 48h tracking).
class ShippingStepSwitcher extends StatelessWidget {
  const ShippingStepSwitcher({
    super.key,
    required this.selectedIndex,
    required this.titles,
    required this.icons,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<String> titles;
  final List<IconData> icons;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(5),
      decoration: AppTheme.cardDecorationOf(context),
      child: Row(
        children: [
          for (var i = 0; i < titles.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _tile(context, i)),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int i) {
    final selected = selectedIndex == i;
    final fg = selected ? AppTheme.white : AppTheme.textPrimaryOf(context);
    return InkWell(
      onTap: () => onSelected(i),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.cobalt : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons[i], size: 18, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                titles[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
