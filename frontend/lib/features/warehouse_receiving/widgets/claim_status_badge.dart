import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_status_badge.dart';

/// 🏷️ ClaimStatusBadge — ImportFlow ERP
///
/// Specialized status badge for warehouse receiving and supplier shortage claims.
/// Adheres strictly to CORE_RULES.md, UI_SCREEN_STANDARDS.md, and WCAG AA contrast.
class ClaimStatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;
  final AppStatusBadgeSize size;
  final bool showIcon;

  const ClaimStatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.size = AppStatusBadgeSize.medium,
    this.showIcon = true,
  });

  const ClaimStatusBadge.submitted({
    super.key,
    this.customLabel,
    this.size = AppStatusBadgeSize.medium,
    this.showIcon = true,
  }) : status = 'SUBMITTED';

  const ClaimStatusBadge.underReview({
    super.key,
    this.customLabel,
    this.size = AppStatusBadgeSize.medium,
    this.showIcon = true,
  }) : status = 'UNDER_REVIEW';

  const ClaimStatusBadge.approved({
    super.key,
    this.customLabel,
    this.size = AppStatusBadgeSize.medium,
    this.showIcon = true,
  }) : status = 'APPROVED';

  const ClaimStatusBadge.rejected({
    super.key,
    this.customLabel,
    this.size = AppStatusBadgeSize.medium,
    this.showIcon = true,
  }) : status = 'REJECTED';

  const ClaimStatusBadge.waived({
    super.key,
    this.customLabel,
    this.size = AppStatusBadgeSize.medium,
    this.showIcon = true,
  }) : status = 'WAIVED';

  static String resolveLabel(BuildContext context, String rawStatus) {
    final isArabic = context.l10n.isArabic;
    final normalized = rawStatus.trim().toUpperCase().replaceAll(' ', '_');

    switch (normalized) {
      case 'SUBMITTED':
      case 'FILED':
      case 'CLAIM_SUBMITTED':
        return isArabic ? 'مقدمة للمورد' : 'Submitted to Supplier';
      case 'UNDER_REVIEW':
      case 'UNDER_INSPECTION':
      case 'PENDING':
      case 'REVIEW':
        return isArabic ? 'قيد المراجعة الفنية' : 'Under Technical Review';
      case 'APPROVED':
      case 'ACCEPTED':
        return isArabic ? 'معتمدة للتعويض' : 'Approved for Settlement';
      case 'REIMBURSED':
      case 'SETTLED':
        return isArabic ? 'تمت التسوية المالية' : 'Settled';
      case 'REJECTED':
      case 'DISMISSED':
        return isArabic ? 'مطالبة مرفوضة' : 'Claim Rejected';
      case 'WAIVED':
      case 'IGNORED':
        return isArabic ? 'تم التجاوز والتنازل' : 'Waived & Overlooked';
      case 'DRAFT':
        return isArabic ? 'مسودة مطالبة' : 'Draft Claim';
      default:
        return rawStatus;
    }
  }

  static IconData? resolveIcon(String rawStatus) {
    final normalized = rawStatus.trim().toUpperCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'SUBMITTED':
      case 'FILED':
      case 'CLAIM_SUBMITTED':
        return Icons.send_rounded;
      case 'UNDER_REVIEW':
      case 'UNDER_INSPECTION':
      case 'PENDING':
      case 'REVIEW':
        return Icons.pending_actions_rounded;
      case 'APPROVED':
      case 'ACCEPTED':
      case 'REIMBURSED':
      case 'SETTLED':
        return Icons.verified_rounded;
      case 'REJECTED':
      case 'DISMISSED':
        return Icons.cancel_outlined;
      case 'WAIVED':
      case 'IGNORED':
        return Icons.do_not_disturb_on_outlined;
      case 'DRAFT':
        return Icons.edit_note_rounded;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = customLabel ?? resolveLabel(context, status);
    final icon = showIcon ? resolveIcon(status) : null;

    return AppStatusBadge.fromStatus(
      status: status,
      label: label,
      size: size,
      icon: icon,
    );
  }
}
