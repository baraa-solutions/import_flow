import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Reusable small copy badge with feedback toast used across the Comprehensive Report.
class ReportCopyBadge extends StatelessWidget {
  final String textToCopy;
  final String? label;
  final Color? color;
  final Color? borderColor;
  final Color? textColor;

  const ReportCopyBadge({
    super.key,
    required this.textToCopy,
    this.label,
    this.color,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (textToCopy.trim().isEmpty || textToCopy == '—') {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? (isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100);
    final border = borderColor ?? (isDark ? AppTheme.darkBorder : Colors.grey.shade300);
    final textCol = textColor ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.cobalt);

    return InkWell(
      onTap: () => CopyHelper.copy(context, textToCopy),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, size: 11, color: textCol),
            const SizedBox(width: 4),
            Text(
              label ?? textToCopy,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: textCol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
