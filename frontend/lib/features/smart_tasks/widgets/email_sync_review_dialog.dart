import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/email_settings_model.dart';
import '../providers/email_settings_provider.dart';

class EmailSyncReviewDialog extends ConsumerStatefulWidget {
  final InboxFetchResultModel result;

  const EmailSyncReviewDialog({
    super.key,
    required this.result,
  });

  static Future<void> show(BuildContext context, {required InboxFetchResultModel result}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmailSyncReviewDialog(result: result),
    );
  }

  @override
  ConsumerState<EmailSyncReviewDialog> createState() => _EmailSyncReviewDialogState();
}

class _ItemReviewState {
  final ArrivalNoticeParseResultModel item;
  bool isSelected;
  String assignedUser;
  String priority;
  String dueDate;

  _ItemReviewState({
    required this.item,
    this.isSelected = true,
    required this.assignedUser,
    required this.priority,
    required this.dueDate,
  });
}

class _EmailSyncReviewDialogState extends ConsumerState<EmailSyncReviewDialog> {
  late List<_ItemReviewState> _items;
  bool _isSubmitting = false;

  List<Map<String, String>> _assigneeOptions(bool isArabic) => [
    {'value': 'Finance Team', 'label': isArabic ? 'فريق الحسابات' : 'Finance Team'},
    {'value': 'Clearance Team', 'label': isArabic ? 'فريق التخليص الجمركي' : 'Clearance Team'},
    {'value': 'Operations Team', 'label': isArabic ? 'إدارة العمليات' : 'Operations Team'},
    {'value': 'Ahmed Sorour', 'label': isArabic ? 'أحمد سرور' : 'Ahmed Sorour'},
    {'value': 'Kamal', 'label': isArabic ? 'كمال' : 'Kamal'},
  ];

  List<Map<String, String>> _priorityOptions(bool isArabic) => [
    {'value': 'Critical', 'label': isArabic ? 'عاجل جداً' : 'Critical'},
    {'value': 'High', 'label': isArabic ? 'مرتفع' : 'High'},
    {'value': 'Medium', 'label': isArabic ? 'متوسط' : 'Medium'},
  ];

  @override
  void initState() {
    super.initState();
    _initItems();
  }

  void _initItems() {
    final matchedItems = widget.result.parsedResults.where((r) => r.isMatchedFile).toList();
    _items = matchedItems.map((item) {
      return _ItemReviewState(
        item: item,
        isSelected: true,
        assignedUser: item.assignedUser.isNotEmpty ? item.assignedUser : 'Finance Team',
        priority: item.priority.isNotEmpty ? item.priority : 'High',
        dueDate: item.dueDate ?? item.extractedEta ?? DateTime.now().toIso8601String().substring(0, 10),
      );
    }).toList();
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      final select = value ?? false;
      for (final item in _items) {
        item.isSelected = select;
      }
    });
  }

  void _bulkAssignTo(String newAssignee) {
    setState(() {
      for (final item in _items) {
        if (item.isSelected) {
          item.assignedUser = newAssignee;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم توجيه كافة المهام المحددة إلى: $newAssignee'),
        backgroundColor: AppTheme.cobalt,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleApproveAndRoute() async {
    final selected = _items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد مهمة واحدة على الأقل للاعتماد والتوجيه.'),
          backgroundColor: AppTheme.crimson,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final approvalList = selected.map((s) {
      final it = s.item;
      final fileCode = it.importFileCode ?? 'IMP';
      return TaskRouteApprovalItemModel(
        importFileId: it.importFileId ?? 0,
        importFileCode: fileCode,
        title: it.taskTitle ?? 'سداد مصاريف إذن التسليم للشحنة ($fileCode)',
        description: it.summaryMessage.isNotEmpty ? it.summaryMessage : 'تم الاعتماد والتوجيه عبر مراجعة البريد الذكي.',
        assignedUser: s.assignedUser,
        priority: s.priority,
        dueDate: s.dueDate,
        reminderType: 'Arrival Notice Payment',
        blNumber: it.extractedBlNumber,
        emailId: it.emailId,
        taskId: it.taskId,
      );
    }).toList();

    final success = await ref.read(emailSettingsProvider.notifier).approveAndRouteTasks(approvalList);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم بنجاح اعتماد وتوجيه ${selected.length} مهمة ذكية وحفظها في النظام!'),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء اعتماد وتوجيه المهام.'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  void _navigateToSmartTasks() {
    ref.read(navigationIndexProvider.notifier).state = 40;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCardColor = isDark ? AppTheme.darkInputBackground : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal;
    final secTextColor = isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700;

    final selectedCount = _items.where((i) => i.isSelected).length;
    final allSelected = _items.isNotEmpty && selectedCount == _items.length;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SelectionArea(
          child: Container(
            width: 880,
            height: 750,
            padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.rule_folder_rounded, color: AppTheme.emerald, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نتائج فحص البريد وتوجيه المهام الذكية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تم فحص ${widget.result.totalFetched} إيميل ومطابقة ${widget.result.matchedFilesCount} شحنة بنجاح. يرجى مراجعة وتحديد توجيه المهام قبل اعتمادها.',
                          style: TextStyle(fontSize: 12.5, color: secTextColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Statistics Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: bgCardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatPill('إجمالي الإيميلات الممسوحة', '${widget.result.totalFetched}', Icons.mark_email_read_outlined, AppTheme.cobalt),
                      const SizedBox(width: 20),
                      _buildStatPill('الشحنات المطابقة', '${widget.result.matchedFilesCount}', Icons.inventory_2_outlined, AppTheme.emerald),
                      const SizedBox(width: 20),
                      _buildStatPill('المهام المقترحة للمراجعة', '${_items.length}', Icons.task_alt_outlined, Colors.amber.shade800),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Master Bulk Control Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Checkbox(
                        value: allSelected,
                        tristate: selectedCount > 0 && !allSelected,
                        onChanged: _toggleSelectAll,
                        activeColor: AppTheme.cobalt,
                      ),
                      Text(
                        'تحديد الكل ($selectedCount من ${_items.length})',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(width: 24),
                      Text('توجيه سريع لكافة المحددة إلى:', style: TextStyle(fontSize: 11.5, color: secTextColor)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkInputBackground : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: 'Finance Team',
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            style: TextStyle(fontSize: 12, color: textColor),
                            dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                            items: _assigneeOptions(isArabic).map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt['value'],
                                child: Text(opt['label']!),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _bulkAssignTo(val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Items List
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد شحنات مطابقة بحاجة للمراجعة.',
                          style: TextStyle(color: secTextColor, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final itemState = _items[index];
                          return _buildTaskReviewCard(itemState, isDark, borderColor, textColor, secTextColor, isArabic);
                        },
                      ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Footer Actions
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Navigate to Smart Tasks button
                    OutlinedButton.icon(
                      onPressed: _navigateToSmartTasks,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('الانتقال إلى شاشة المهام الذكية', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.cobalt,
                        side: const BorderSide(color: AppTheme.cobalt),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Close button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('إغلاق', style: TextStyle(color: secTextColor, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),

                    // Approve and Route Button
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleApproveAndRoute,
                      icon: _isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(
                        _isSubmitting ? 'جارٍ الاعتماد والتوجيه...' : 'اعتماد وتوجيه المهام المختارة ($selectedCount)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildStatPill(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildTaskReviewCard(
    _ItemReviewState itemState,
    bool isDark,
    Color borderColor,
    Color textColor,
    Color secTextColor,
    bool isArabic,
  ) {
    final it = itemState.item;
    final shipmentCode = it.importFileCode ?? 'IMP-UNKNOWN';
    final shipmentTitle = it.shipmentTitle ?? shipmentCode;
    final matchReason = it.matchReason ?? 'مطابقة بريدية';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: itemState.isSelected
            ? (isDark ? AppTheme.cobalt.withOpacity(0.08) : const Color(0xFFF8FAFF))
            : (isDark ? AppTheme.darkInputBackground : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: itemState.isSelected ? AppTheme.cobalt.withOpacity(0.5) : borderColor,
          width: itemState.isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Checkbox + Shipment Badges + Match Reason
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Checkbox(
                value: itemState.isSelected,
                onChanged: (val) {
                  setState(() => itemState.isSelected = val ?? false);
                },
                activeColor: AppTheme.cobalt,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  shipmentTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.cobalt),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shipmentCode,
                  style: TextStyle(fontSize: 11, color: secTextColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 12, color: AppTheme.emerald),
                    const SizedBox(width: 4),
                    Text(
                      'مطابقة: $matchReason',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                    ),
                  ],
                ),
              ),
              if (it.taskCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    it.taskCode!,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Email Details (Subject + Sender)
          if (it.subject != null && it.subject!.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 38, bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${it.subject}  —  [من: ${it.senderEmail ?? 'غير محدد'}]',
                      style: TextStyle(fontSize: 11.5, color: secTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Row 3: Task Title + Routing Controls (Assignee + Priority + Due Date)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 38),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Assigned To Dropdown
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('توجيه إلى:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(width: 6),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkInputBackground : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: itemState.assignedUser,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          style: TextStyle(fontSize: 11.5, color: textColor),
                          dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                          items: _assigneeOptions(isArabic).map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt['value'],
                              child: Text(opt['label']!),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => itemState.assignedUser = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Priority Dropdown
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('الأولوية:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(width: 6),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkInputBackground : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: itemState.priority,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          style: TextStyle(fontSize: 11.5, color: textColor),
                          dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                          items: _priorityOptions(isArabic).map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt['value'],
                              child: Text(opt['label']!),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => itemState.priority = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Due Date field
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('الاستحقاق:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(width: 6),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkInputBackground : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(itemState.dueDate, style: TextStyle(fontSize: 11.5, color: textColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
