import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import 'projects_helpers.dart';

/// Compact status filter dropdown for Screen 31: Projects & Cost Centers.
class ProjectsFilterBar extends ConsumerWidget {
  final String selectedStatus;
  final List<String> statuses;
  final ValueChanged<String> onStatusChanged;
  final double width;

  const ProjectsFilterBar({
    super.key,
    required this.selectedStatus,
    this.statuses = const ['All', 'Open', 'Closed', 'On Hold'],
    required this.onStatusChanged,
    this.width = 140.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      height: density.buttonHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.black26,
            width: 0.8,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: statuses.contains(selectedStatus) ? selectedStatus : statuses.first,
            isExpanded: true,
            dropdownColor: isDark ? AppTheme.darkElevatedSurface : Colors.white,
            style: TextStyle(
              fontSize: density.buttonFontSize - 1,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              fontFamily: 'Cairo',
            ),
            items: statuses
                .map((st) => DropdownMenuItem(
                      value: st,
                      child: Text(ProjectsHelpers.getStatusLabel(context, st)),
                    ))
                .toList(),
            onChanged: (st) {
              if (st != null) {
                onStatusChanged(st);
              }
            },
          ),
        ),
      ),
    );
  }
}
