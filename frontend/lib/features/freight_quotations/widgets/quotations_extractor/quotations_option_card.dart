import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import 'extracted_quotation_option_model.dart';

/// Card widget representing an individual extracted quotation option.
class QuotationsOptionCard extends StatelessWidget {
  final ExtractedQuotationOption option;
  final VoidCallback onAddSingle;
  final VoidCallback onCopy;

  const QuotationsOptionCard({
    super.key,
    required this.option,
    required this.onAddSingle,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Carrier & Container Type + Direct/Transit Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${option.carrierName} (${option.containerType})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.cobalt,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.cobalt),
                    tooltip: isArabic ? 'نسخ بيانات هذا العرض' : 'Copy Quote Details',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onCopy,
                  ),
                  const SizedBox(width: 6),
                  AppStatusBadge(
                    label: option.isDirect
                        ? (isArabic ? 'مباشر' : 'Direct')
                        : (isArabic ? 'ترانزيت' : 'Transit'),
                    severity: option.isDirect ? AppSeverity.success : AppSeverity.warning,
                    size: AppStatusBadgeSize.small,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 8, thickness: 1),
          const SizedBox(height: 6),

          // Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic
                    ? 'نولون: \$${option.oceanFreight.toStringAsFixed(0)}'
                    : 'Freight: \$${option.oceanFreight.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              if (option.localCharges != null && option.localCharges! > 0)
                Text(
                  isArabic
                      ? 'محلي: \$${option.localCharges!.toStringAsFixed(0)}'
                      : 'Local: \$${option.localCharges!.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              Text(
                isArabic
                    ? 'الإجمالي: \$${option.totalEstimatedCost.toStringAsFixed(0)}'
                    : 'Total: \$${option.totalEstimatedCost.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Transit & Demurrage Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic
                    ? '⏱️ ترانزيت: ${option.transitDays ?? "-"} يوم'
                    : '⏱️ Transit: ${option.transitDays ?? "-"} days',
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
              Text(
                isArabic
                    ? '⏳ سماح: ${option.freeTimeDays ?? 14} يوم'
                    : '⏳ Free Time: ${option.freeTimeDays ?? 14} days',
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ],
          ),

          // Extra Notes / Unmapped Expenses Pill (if any)
          if (option.notes != null && option.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
              ),
              child: Text(
                '★ ${option.notes!}',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Full-width Add Button (Outlined Blue Button with + icon)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cobalt,
                side: const BorderSide(color: AppTheme.cobalt, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                isArabic ? '+ إضافة هذا العرض للسيناريو' : '+ Add This Quote to Scenario',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: onAddSingle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Item row displaying database verification status for an entity (Forwarder or Shipping Line).
class PartyVerificationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String name;
  final bool isVerified;
  final String? code;
  final VoidCallback onRegister;

  const PartyVerificationRow({
    super.key,
    required this.icon,
    required this.title,
    required this.name,
    required this.isVerified,
    this.code,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified
            ? AppTheme.emerald.withValues(alpha: 0.08)
            : AppTheme.crimson.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVerified
              ? AppTheme.emerald.withValues(alpha: 0.3)
              : AppTheme.crimson.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isVerified ? AppTheme.emerald : AppTheme.crimson),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (isVerified)
            AppStatusBadge(
              label: code != null
                  ? (isArabic ? 'مسجل ($code)' : 'Verified ($code)')
                  : (isArabic ? 'مسجل في النظام' : 'Verified in System'),
              severity: AppSeverity.success,
              size: AppStatusBadgeSize.small,
              icon: Icons.check_circle,
            )
          else ...[
            AppStatusBadge(
              label: isArabic ? 'غير مسجل' : 'Unconfirmed',
              severity: AppSeverity.danger,
              size: AppStatusBadgeSize.small,
              icon: Icons.cancel_rounded,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.add, size: 14),
              label: Text(
                isArabic ? 'سجّل +' : 'Register +',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: onRegister,
            ),
          ],
        ],
      ),
    );
  }
}

/// Item row displaying an extracted field with copy, edit, and delete options.
class ExtractedFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCustom;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExtractedFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.isCustom,
    required this.onCopy,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isCustom ? AppTheme.cobalt.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCustom ? AppTheme.cobalt.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.bold : FontWeight.w600,
                color: isCustom ? AppTheme.cobalt : AppTheme.charcoal,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
            tooltip: isArabic ? 'نسخ القيمة' : 'Copy value',
            onPressed: onCopy,
          ),
          if (isCustom) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.cobalt),
              tooltip: isArabic ? 'تعديل هذا البند' : 'Edit item',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.crimson),
              tooltip: isArabic ? 'حذف هذا البند' : 'Delete item',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
