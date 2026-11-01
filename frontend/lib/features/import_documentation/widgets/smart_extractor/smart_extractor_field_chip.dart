import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Read-only metadata field chip with copy-on-tap support.
class SmartExtractorFieldChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const SmartExtractorFieldChip({
    super.key,
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppTheme.severityBackgroundOf(context, AppSeverity.warning)
            : AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight ? AppTheme.orange : AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.0, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          CopyableText(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: AppTheme.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
