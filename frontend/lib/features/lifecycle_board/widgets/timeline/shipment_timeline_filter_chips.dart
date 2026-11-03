import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ShipmentTimelineFilterChips extends StatelessWidget {
  final int? selectedPhaseNumber;
  final ValueChanged<int?> onPhaseSelected;
  final bool onlyBottlenecks;
  final ValueChanged<bool> onBottlenecksChanged;
  final bool onlyDelayed;
  final ValueChanged<bool> onDelayedChanged;
  final bool isAr;

  const ShipmentTimelineFilterChips({
    super.key,
    required this.selectedPhaseNumber,
    required this.onPhaseSelected,
    required this.onlyBottlenecks,
    required this.onBottlenecksChanged,
    required this.onlyDelayed,
    required this.onDelayedChanged,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: Text(isAr ? 'جميع المراحل' : 'All Phases'),
          selected: selectedPhaseNumber == null,
          onSelected: (_) => onPhaseSelected(null),
          selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
          checkmarkColor: AppTheme.cobalt,
        ),
        for (int p = 1; p <= 6; p++)
          FilterChip(
            label: Text('${isAr ? "المرحلة" : "Phase"} $p'),
            selected: selectedPhaseNumber == p,
            onSelected: (_) => onPhaseSelected(p),
            selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.cobalt,
          ),
        const SizedBox(width: 8),
        FilterChip(
          avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.crimson),
          label: Text(
            isAr ? 'نقاط الاختناق فقط' : 'Bottlenecks Only',
            style: TextStyle(color: onlyBottlenecks ? AppTheme.crimson : null),
          ),
          selected: onlyBottlenecks,
          onSelected: onBottlenecksChanged,
          selectedColor: AppTheme.crimson.withValues(alpha: 0.15),
          checkmarkColor: AppTheme.crimson,
        ),
        FilterChip(
          avatar: const Icon(Icons.timer_off_outlined, size: 16, color: AppTheme.orange),
          label: Text(
            isAr ? 'المتأخرة عن الـ SLA' : 'Delayed Only',
            style: TextStyle(color: onlyDelayed ? AppTheme.orange : null),
          ),
          selected: onlyDelayed,
          onSelected: onDelayedChanged,
          selectedColor: AppTheme.orange.withValues(alpha: 0.15),
          checkmarkColor: AppTheme.orange,
        ),
      ],
    );
  }
}
