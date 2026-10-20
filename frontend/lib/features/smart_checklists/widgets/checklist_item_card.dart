// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/checklist_item_model.dart';
import '../providers/smart_checklists_provider.dart';

class ChecklistItemCard extends ConsumerWidget {
  final ChecklistItemModel item;
  final int fileId;
  final VoidCallback? onActionRoutePressed;

  const ChecklistItemCard({
    super.key,
    required this.item,
    required this.fileId,
    this.onActionRoutePressed,
  });

  String _getRoleLabel(String role, bool isAr) {
    switch (role.toUpperCase()) {
      case 'COORDINATOR':
        return isAr ? '👤 المنسق' : '👤 Coordinator';
      case 'SUPPLIER':
        return isAr ? '🏭 المورد' : '🏭 Supplier';
      case 'CUSTOMS_BROKER':
        return isAr ? '🛃 المخلص الجمركي' : '🛃 Broker';
      case 'SHIPPING_LINE':
        return isAr ? '🚢 التوكيل الملاحي' : '🚢 Shipping Line';
      default:
        return role;
    }
  }

  void _showOverrideDialog(BuildContext context, WidgetRef ref, bool isAr) {
    final isDark = AppTheme.isDark(context);
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                isAr ? 'طلب تجاوز مشروط' : 'Conditional Override Request',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
            ],
          ),
          content: SelectionArea(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'البند: ${item.getTitle(true)}' : 'Item: ${item.getTitle(false)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'هذا البند إلزامي لحوكمة الشحنة. يرجى إدخال المبرر التشغيلي المعتمد للسماح بتجاوزه:'
                    : 'This item is mandatory for shipment governance. Please enter an approved operational justification:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: isAr
                      ? 'مثال: تعهد المورد بإرسال أصل الشهادة بالبريد السريع DHL خلال 48 ساعة...'
                      : 'E.g., Supplier pledged to send original certificate via DHL within 48 hours...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isAr ? 'إلغاء' : 'Cancel',
                style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isAr ? 'يجب إدخال مبرر التجاوز' : 'Override justification is required')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final success = await ref.read(smartChecklistProvider.notifier).overrideItem(
                      fileId: fileId,
                      itemId: item.itemId,
                      reason: reason,
                    );
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAr
                            ? 'تم منح التجاوز المشروط وتوثيقه في سجل الرقابة بنجاح'
                            : 'Conditional override granted and logged successfully',
                      ),
                    ),
                  );
                }
              },
              child: Text(isAr ? 'اعتماد التجاوز' : 'Approve Override'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isPassed = item.isPassed;
    final isWaived = item.isWaived;
    final isPending = item.isPending;

    Color borderColor = isDark ? Colors.grey.shade700 : Colors.grey.withOpacity(0.2);
    Color statusBg = Colors.grey.withOpacity(isDark ? 0.2 : 0.1);
    Color statusColor = isDark ? Colors.grey.shade400 : Colors.grey;
    IconData statusIcon = Icons.hourglass_empty;

    if (isPassed) {
      borderColor = AppTheme.emerald.withOpacity(isDark ? 0.7 : 0.4);
      statusBg = AppTheme.emerald.withOpacity(isDark ? 0.25 : 0.12);
      statusColor = isDark ? Colors.greenAccent : AppTheme.emerald;
      statusIcon = Icons.check_circle;
    } else if (isWaived) {
      borderColor = Colors.amber.withOpacity(isDark ? 0.7 : 0.5);
      statusBg = Colors.amber.withOpacity(isDark ? 0.25 : 0.12);
      statusColor = isDark ? Colors.amberAccent : Colors.amber.shade800;
      statusIcon = Icons.warning_amber_rounded;
    } else if (item.isMandatory) {
      borderColor = isDark ? Colors.red.shade400 : AppTheme.crimson.withOpacity(0.4);
      statusBg = AppTheme.crimson.withOpacity(isDark ? 0.25 : 0.08);
      statusColor = isDark ? Colors.red.shade300 : AppTheme.crimson;
      statusIcon = Icons.cancel;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: item.isMandatory && isPending ? 1.5 : 1.0),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Action Button (Toggle)
            InkWell(
              onTap: () {
                final nextStatus = isPassed ? 'PENDING' : 'PASSED';
                ref.read(smartChecklistProvider.notifier).toggleItem(
                      fileId: fileId,
                      itemId: item.itemId,
                      newStatus: nextStatus,
                      verifiedBy: 'Coordinator',
                    );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Icon(statusIcon, size: 20, color: statusColor),
              ),
            ),
            const SizedBox(width: 12),

            // Content Area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Mandatory / Optional Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isMandatory
                              ? (isDark ? Colors.red.shade900.withOpacity(0.4) : Colors.red.shade50)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: item.isMandatory
                                ? (isDark ? Colors.red.shade600 : Colors.red.shade300)
                                : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          item.isMandatory
                              ? (isAr ? 'إلزامي [Gatekeeper]' : 'Mandatory [Gatekeeper]')
                              : (isAr ? 'اختياري' : 'Optional'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.isMandatory
                                ? (isDark ? Colors.red.shade200 : Colors.red.shade700)
                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                          ),
                        ),
                      ),

                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cobalt.withOpacity(0.25) : AppTheme.cobalt.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: (isDark ? const Color(0xFF60A5FA) : AppTheme.cobalt).withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _getRoleLabel(item.responsibleRole, isAr),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? const Color(0xFF60A5FA) : AppTheme.cobalt,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Verification Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.verificationType == 'AUTOMATIC'
                              ? (isDark ? Colors.teal.shade900.withOpacity(0.4) : Colors.teal.withOpacity(0.1))
                              : (isDark ? Colors.purple.shade900.withOpacity(0.4) : Colors.purple.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.verificationType == 'AUTOMATIC'
                              ? (isAr ? '🤖 فحص آلي' : '🤖 Auto Check')
                              : (isAr ? '✍️ مراجعة يدوية' : '✍️ Manual Review'),
                          style: TextStyle(
                            fontSize: 10,
                            color: item.verificationType == 'AUTOMATIC'
                                ? (isDark ? Colors.tealAccent : Colors.teal.shade800)
                                : (isDark ? Colors.purple.shade200 : Colors.purple.shade700),
                          ),
                        ),
                      ),

                      // Code
                      Text(
                        item.questionCode,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : Colors.grey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Question Title
                  Text(
                    item.getTitle(isAr),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),

                  // Description
                  if (item.getDescription(isAr) != null && item.getDescription(isAr)!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.getDescription(isAr)!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                      ),
                    ),
                  ],

                  // Auto Source or Audit Sign-off
                  const SizedBox(height: 6),
                  if (isPassed && item.verifiedBy != null) ...[
                    Row(
                      children: [
                        Icon(Icons.verified, size: 12, color: isDark ? Colors.greenAccent : AppTheme.emerald),
                        const SizedBox(width: 4),
                        Text(
                          isAr
                              ? 'مستوفى: ${item.verifiedBy}${item.notes != null ? " (${item.notes})" : ""}'
                              : 'Satisfied: ${item.verifiedBy}${item.notes != null ? " (${item.notes})" : ""}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.greenAccent : AppTheme.emerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ] else if (isWaived && item.overrideReason != null) ...[
                    Row(
                      children: [
                        Icon(Icons.warning, size: 12, color: isDark ? Colors.amberAccent : Colors.amber.shade800),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isAr
                                ? 'تجاوز مشروط: ${item.overrideReason}'
                                : 'Conditional Override: ${item.overrideReason}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ] else if (item.autoCheckSource != null) ...[
                    Text(
                      isAr
                          ? 'مصدر الفحص التلقائي: ${item.autoCheckSource}'
                          : 'Auto-Check Source: ${item.autoCheckSource}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action Buttons Area
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Request Override Button (only if mandatory and pending)
                if (item.isMandatory && isPending) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: isDark ? Colors.red.shade300 : AppTheme.crimson,
                    ),
                    icon: const Icon(Icons.shield_outlined, size: 14),
                    label: Text(isAr ? 'تجاوز مشروط' : 'Override', style: const TextStyle(fontSize: 11)),
                    onPressed: () => _showOverrideDialog(context, ref, isAr),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
