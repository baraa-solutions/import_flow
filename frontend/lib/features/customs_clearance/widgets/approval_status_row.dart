import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/ltr_text.dart';

/// Row component displaying a regulatory approval or inspection step's status.
///
/// Follows `AppTheme`, `SelectionArea`, and `ui-screen-standards`.
class ApprovalStatusRow extends StatelessWidget {
  final String title;
  final String status;
  final String? authorityOrBody;
  final String? referenceNumber;
  final bool isRequired;
  final bool? isSatisfied;
  final String? notes;
  final IconData? customIcon;
  final Widget? trailingAction;
  final VoidCallback? onTap;

  const ApprovalStatusRow({
    super.key,
    required this.title,
    required this.status,
    this.authorityOrBody,
    this.referenceNumber,
    this.isRequired = true,
    this.isSatisfied,
    this.notes,
    this.customIcon,
    this.trailingAction,
    this.onTap,
  });

  bool get _satisfied {
    if (isSatisfied != null) return isSatisfied!;
    if (!isRequired) return true;
    final s = status.trim().toLowerCase();
    return s == 'approved' ||
        s == 'completed' ||
        s == 'waived' ||
        s == 'معتمد' ||
        s == 'مكتمل' ||
        s == 'معفى';
  }

  AppSeverity get _severity {
    if (!isRequired) return AppSeverity.info;
    final s = status.trim().toLowerCase();
    if (s == 'approved' ||
        s == 'completed' ||
        s == 'waived' ||
        s == 'معتمد' ||
        s == 'مكتمل' ||
        s == 'معفى') {
      return AppSeverity.success;
    }
    if (s == 'rejected' || s == 'مرفوض' || s == 'failed') {
      return AppSeverity.danger;
    }
    return AppSeverity.warning;
  }

  IconData get _icon {
    if (customIcon != null) return customIcon!;
    if (!isRequired) return Icons.remove_circle_outline_rounded;
    if (_satisfied) return Icons.check_circle_rounded;
    if (_severity == AppSeverity.danger) return Icons.cancel_rounded;
    return Icons.hourglass_top_rounded;
  }

  Color _statusColor(BuildContext context) {
    if (!isRequired) return AppTheme.textSecondaryOf(context);
    switch (_severity) {
      case AppSeverity.success:
        return AppTheme.emerald;
      case AppSeverity.danger:
        return AppTheme.crimson;
      case AppSeverity.warning:
        return AppTheme.orange;
      case AppSeverity.info:
        return AppTheme.cobalt;
    }
  }

  String _formatStatusLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'approved':
        return 'معتمد (Approved)';
      case 'completed':
        return 'مكتمل (Completed)';
      case 'waived':
        return 'معفى (Waived)';
      case 'pending':
      case 'pending approval':
        return 'قيد الاعتماد (Pending)';
      case 'scheduled':
        return 'مجدول (Scheduled)';
      case 'applied':
        return 'مقدم للجهة (Applied)';
      case 'rejected':
        return 'مرفوض (Rejected)';
      case 'not required':
        return 'غير مطلوب (Not Required)';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isRequired
        ? (_satisfied
            ? AppTheme.emerald.withValues(alpha: 0.35)
            : statusColor.withValues(alpha: 0.45))
        : AppTheme.borderOf(context);

    final bgColor = isRequired && !_satisfied
        ? AppTheme.severityBackgroundOf(context, _severity)
        : (isDark ? const Color(0xFF1E232D) : const Color(0xFFF9FAFB));

    final rowContent = Container(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: borderColor,
          width: isRequired && !_satisfied ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status Icon Indicator
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Main Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _satisfied
                              ? AppTheme.emerald.withValues(alpha: 0.12)
                              : AppTheme.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          _satisfied ? 'مستوفى' : 'شرط إلزامي',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _satisfied ? AppTheme.emerald : AppTheme.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (authorityOrBody != null && authorityOrBody!.trim().isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_outlined,
                              size: 13, color: AppTheme.textSecondaryOf(context)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              authorityOrBody!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (referenceNumber != null && referenceNumber!.trim().isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag_rounded,
                              size: 13, color: AppTheme.textSecondaryOf(context)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: LtrText(
                              referenceNumber!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (notes != null && notes!.trim().isNotEmpty)
                      Text(
                        notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Status Badge
          AppStatusBadge(
            label: _formatStatusLabel(status),
            severity: _severity,
            size: AppStatusBadgeSize.small,
            icon: _icon,
          ),

          if (trailingAction != null) ...[
            const SizedBox(width: 8),
            trailingAction!,
          ],
        ],
      ),
    );

    final interactive = onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: rowContent,
          )
        : rowContent;

    return SelectionArea(child: interactive);
  }
}
