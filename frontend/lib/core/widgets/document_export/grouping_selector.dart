import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Single option definition for [GroupingSelector].
class GroupingOption<T> {
  final T value;
  final String label;
  final String description;
  final IconData? icon;

  const GroupingOption({
    required this.value,
    required this.label,
    required this.description,
    this.icon,
  });
}

/// Reusable UI component for Dimension 3 of the Document Export Engine (Task K).
///
/// Used for:
/// - Commercial Invoice Dimension 3: Invoice Line Grouping (3 options)
/// - Customs Packing List Dimension 3: Package & Carton Structure (4 options)
///
/// Provides high contrast, dark mode support, and clear descriptions for each strategy.
class GroupingSelector<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<GroupingOption<T>> options;
  final ValueChanged<T> onChanged;
  final Color activeColor;

  const GroupingSelector({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        ...options.map((opt) {
          final isSelected = opt.value == value;
          final selectedBorderColor = activeColor;
          final unselectedBorderColor = isDark ? AppTheme.darkBorder : Colors.grey.shade300;
          final selectedBgColor = activeColor.withValues(alpha: isDark ? 0.22 : 0.08);
          final unselectedBgColor = isDark ? AppTheme.darkCardBackground : Colors.white;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onChanged(opt.value),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBgColor : unselectedBgColor,
                  border: Border.all(
                    color: isSelected ? selectedBorderColor : unselectedBorderColor,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? activeColor : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    if (opt.icon != null) ...[
                      Icon(
                        opt.icon,
                        size: 16,
                        color: isSelected ? activeColor : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? activeColor
                                  : (isDark ? AppTheme.darkTextPrimary : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt.description,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
