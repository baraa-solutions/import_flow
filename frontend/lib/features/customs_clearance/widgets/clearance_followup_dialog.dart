import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/clearance_followup_log_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';

/// Modal dialog for recording and managing the 5 sequential customs inspection and valuation follow-ups (TASK-BE-12).
class ClearanceFollowupDialog extends ConsumerStatefulWidget {
  final CustomsClearanceModel clearanceRecord;
  final ImportFileModel? importFile;

  const ClearanceFollowupDialog({
    super.key,
    required this.clearanceRecord,
    this.importFile,
  });

  static Future<bool?> show(
    BuildContext context, {
    required CustomsClearanceModel clearanceRecord,
    ImportFileModel? importFile,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClearanceFollowupDialog(
        clearanceRecord: clearanceRecord,
        importFile: importFile,
      ),
    );
  }

  @override
  ConsumerState<ClearanceFollowupDialog> createState() => _ClearanceFollowupDialogState();
}

class _ClearanceFollowupDialogState extends ConsumerState<ClearanceFollowupDialog> {
  final _formKey = GlobalKey<FormState>();

  int _followupSeq = 1;
  String _selectedAuthorityType = 'Customs Inspection Yard / ساحة الكشف والمعاينة';
  late TextEditingController _officialContactController;
  late TextEditingController _statusSummaryController;
  late TextEditingController _actionRequiredController;

  DateTime _followupDate = DateTime.now();
  DateTime? _nextVisitDate;
  bool _isSubmitting = false;

  final List<String> _authoritiesList = [
    'Customs Inspection Yard / ساحة الكشف والمعاينة',
    'Customs Valuation Committee / لجنة التثمين الجمركي',
    'GOEIC Inspection / هيئة الصادرات والواردات',
    'Food Safety Authority / هيئة سلامة الغذاء (NFSA)',
    'Quarantine / الحجر الزراعي والبيطري',
    'Chemistry Administration / مصلحة الكيمياء والفحص المعملي',
    'NTRA Telecomm / الجهاز القومي لتنظيم الاتصالات',
    'Customs Tariff & Classification / لجنة التعريفة والتصنيف',
  ];

  @override
  void initState() {
    super.initState();
    _officialContactController = TextEditingController();
    _statusSummaryController = TextEditingController();
    _actionRequiredController = TextEditingController();
  }

  @override
  void dispose() {
    _officialContactController.dispose();
    _statusSummaryController.dispose();
    _actionRequiredController.dispose();
    super.dispose();
  }

  Future<void> _submitNewFollowup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'customs_clearance_id': widget.clearanceRecord.customsClearanceId,
        'import_file_id': widget.clearanceRecord.importFileId,
        'followup_seq': _followupSeq,
        'followup_date': _followupDate.toUtc().toIso8601String(),
        'authority_type': _selectedAuthorityType,
        'official_contact': _officialContactController.text.trim().isNotEmpty
            ? _officialContactController.text.trim()
            : null,
        'status_summary': _statusSummaryController.text.trim(),
        'action_required': _actionRequiredController.text.trim().isNotEmpty
            ? _actionRequiredController.text.trim()
            : null,
        'next_visit_date': _nextVisitDate?.toUtc().toIso8601String(),
        'is_completed': false,
      };

      await ref.read(customsClearanceProvider.notifier).createFollowupLog(payload);
      ref.invalidate(clearanceFollowupLogsProvider(widget.clearanceRecord.customsClearanceId));

      if (mounted) {
        _statusSummaryController.clear();
        _actionRequiredController.clear();
        _officialContactController.clear();
        setState(() {
          _followupSeq = (_followupSeq < 5) ? _followupSeq + 1 : 5;
          _nextVisitDate = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.isArabic
                ? 'تم تسجيل المتابعة الميدانية الجمركية وتحديث المخطط الزمني بنجاح'
                : 'Customs field follow-up recorded successfully',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.isArabic
                ? 'فشل تسجيل المتابعة الميدانية: $e'
                : 'Failed to record follow-up: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completeFollowup(int logId) async {
    try {
      await ref.read(customsClearanceProvider.notifier).completeFollowupLog(logId);
      ref.invalidate(clearanceFollowupLogsProvider(widget.clearanceRecord.customsClearanceId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.isArabic
                ? 'تم تأكيد إنجاز واستيفاء المتابعة الميدانية'
                : 'Follow-up marked as completed successfully',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.isArabic
                ? 'فشل تأكيد إنجاز المتابعة: $e'
                : 'Failed to complete follow-up: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = widget.clearanceRecord;
    final f = widget.importFile;

    final logsAsync = ref.watch(clearanceFollowupLogsProvider(r.customsClearanceId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: AppTheme.surfaceOf(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.checklist_rtl_rounded, color: AppTheme.emerald, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.isArabic
                              ? 'سجل المتابعات الميدانية للتخليص الجمركي (5 لجان فحص وتثمين)'
                              : 'Field Customs Clearance Follow-up Logs (5 Stages)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${r.clearanceCode} | ${f != null ? f.importFileCode : "File #${r.importFileId}"}'
                          '${r.declaration46No != null ? " | شهادة 46: ${r.declaration46No}" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Top Summary Stepper
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.charcoalSurface,
              child: logsAsync.when(
                loading: () => const SizedBox(height: 28),
                error: (_, __) => const SizedBox(height: 28),
                data: (logs) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(5, (idx) {
                      final seq = idx + 1;
                      final matchingLog = logs.where((x) => x.followupSeq == seq).firstOrNull;
                      final isDone = matchingLog?.isCompleted ?? false;
                      final isLogged = matchingLog != null;

                      Color badgeColor = AppTheme.borderOf(context);
                      Color textColor = AppTheme.textSecondaryOf(context);
                      IconData badgeIcon = Icons.hourglass_empty_rounded;

                      if (isDone) {
                        badgeColor = AppTheme.emerald;
                        textColor = Colors.white;
                        badgeIcon = Icons.check_circle_rounded;
                      } else if (isLogged) {
                        badgeColor = AppTheme.orange;
                        textColor = Colors.white;
                        badgeIcon = Icons.schedule_rounded;
                      }

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLogged ? badgeColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: badgeColor),
                            ),
                            child: Row(
                              children: [
                                Icon(badgeIcon, size: 14, color: isLogged ? textColor : badgeColor),
                                const SizedBox(width: 4),
                                Text(
                                  '#$seq ${_stageLabel(seq, l.isArabic)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isLogged ? FontWeight.bold : FontWeight.normal,
                                    color: isLogged ? textColor : AppTheme.textSecondaryOf(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (seq < 5) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.5)),
                            const SizedBox(width: 6),
                          ],
                        ],
                      );
                    }),
                  );
                },
              ),
            ),

            // Main Content: History List + Form
            Expanded(
              child: Row(
                children: [
                  // Left Side: Follow-up History (48%)
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          end: BorderSide(color: AppTheme.borderOf(context)),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history_rounded, size: 18, color: AppTheme.cobalt),
                              const SizedBox(width: 8),
                              Text(
                                l.isArabic ? 'سجل المتابعات المسجلة' : 'Recorded Follow-ups',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: logsAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, _) => Center(
                                child: Text('Error: $err', style: const TextStyle(color: AppTheme.crimson)),
                              ),
                              data: (logs) {
                                if (logs.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.assignment_late_outlined, size: 36, color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.4)),
                                        const SizedBox(height: 8),
                                        Text(
                                          l.isArabic
                                              ? 'لا توجد متابعات ميدانية مسجلة حتى الآن.'
                                              : 'No field follow-ups recorded yet.',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  itemCount: logs.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = logs[index];
                                    return _buildFollowupCard(item, l);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Side: Add New Follow-up Form (52%)
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.add_task_rounded, size: 18, color: AppTheme.emerald),
                                const SizedBox(width: 8),
                                Text(
                                  l.isArabic ? 'تسجيل متابعة ميدانية جديدة' : 'Add New Field Follow-up',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Sequence + Authority Type
                            Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _followupSeq,
                                    decoration: InputDecoration(
                                      labelText: l.isArabic ? 'المتابعة #' : 'Seq #',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [1, 2, 3, 4, 5].map((s) => DropdownMenuItem(value: s, child: Text('#$s'))).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _followupSeq = v);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedAuthorityType,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: l.isArabic ? 'الجهة الجمركية / المعاينة *' : 'Authority / Inspection *',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: _authoritiesList.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _selectedAuthorityType = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Official Contact Name + Followup Date
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _officialContactController,
                                    decoration: InputDecoration(
                                      labelText: l.isArabic ? 'اسم المسؤول / المثمن / المأمور' : 'Official / Officer Contact',
                                      hintText: l.isArabic ? 'مثال: مأمور الكشف م. وليد' : 'Officer Name',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _followupDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setState(() => _followupDate = picked);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: l.isArabic ? 'تاريخ المتابعة *' : 'Followup Date *',
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
                                      ),
                                      child: Text(
                                        _followupDate.toIso8601String().substring(0, 10),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Status Summary
                            TextFormField(
                              controller: _statusSummaryController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: l.isArabic ? 'ملخص المعاينة / الإجراء الميداني *' : 'Status Summary / Inspection Outcome *',
                                hintText: l.isArabic ? 'مثال: تم فتح الحاويات وسحب عينات الكيماويات للمطابقة' : 'Inspection completed, samples taken',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? (l.isArabic ? 'مطلوب إدخال ملخص المتابعة' : 'Summary required')
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Action Required
                            TextFormField(
                              controller: _actionRequiredController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: l.isArabic ? 'الإجراء المطلوب من المستورد / المخلص' : 'Action Required from Importer/Broker',
                                hintText: l.isArabic ? 'مثال: سداد رسوم الفحص المعملي واستيفاء موافقة الهيئة' : 'Pay lab fees, submit certificate',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Next Visit Date
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _nextVisitDate ?? DateTime.now().add(const Duration(days: 1)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setState(() => _nextVisitDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l.isArabic ? 'موعد الزيارة / المتابعة القادمة' : 'Next Visit Date',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: const Icon(Icons.event_repeat_rounded, size: 16),
                                ),
                                child: Text(
                                  _nextVisitDate != null ? _nextVisitDate!.toIso8601String().substring(0, 10) : (l.isArabic ? 'غير محدد' : 'Not Set'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _nextVisitDate != null ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Submit Button
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: AppButton(
                                label: l.isArabic ? 'حفظ المتابعة الميدانية' : 'Save Field Follow-up',
                                icon: Icons.save_rounded,
                                variant: AppButtonVariant.primary,
                                isLoading: _isSubmitting,
                                onPressed: _isSubmitting ? null : _submitNewFollowup,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowupCard(ClearanceFollowupLogModel item, AppLocalizations l) {
    final isDone = item.isCompleted;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.severityBackgroundOf(context, AppSeverity.success).withValues(alpha: 0.3)
            : AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDone
              ? AppTheme.severityForegroundOf(context, AppSeverity.success).withValues(alpha: 0.4)
              : AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone ? AppTheme.emerald : AppTheme.cobalt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${item.followupSeq}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.authorityType,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                item.followupDate.length >= 10 ? item.followupDate.substring(0, 10) : item.followupDate,
                style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryOf(context)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (item.officialContact != null && item.officialContact!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${l.isArabic ? "المسؤول:" : "Officer:"} ${item.officialContact!}',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
              ),
            ),
          Text(
            item.statusSummary,
            style: const TextStyle(fontSize: 11.5),
          ),
          if (item.actionRequired != null && item.actionRequired!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.warning).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${l.isArabic ? "مطلوب:" : "Action:"} ${item.actionRequired!}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (item.nextVisitDate != null)
                Text(
                  '${l.isArabic ? "الموعد القادم:" : "Next:"} ${item.nextVisitDate!.substring(0, 10)}',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryOf(context)),
                ),
              const Spacer(),
              if (isDone)
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.emerald),
                    const SizedBox(width: 4),
                    Text(
                      l.isArabic ? 'مكتملة' : 'Completed',
                      style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                )
              else
                AppButton(
                  label: l.isArabic ? 'تأكيد الإنجاز' : 'Mark Done',
                  icon: Icons.check,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => _completeFollowup(item.logId),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _stageLabel(int seq, bool isArabic) {
    switch (seq) {
      case 1:
        return isArabic ? 'المعاينة' : 'Inspection';
      case 2:
        return isArabic ? 'التثمين' : 'Valuation';
      case 3:
        return isArabic ? 'الرقابة' : 'GOEIC';
      case 4:
        return isArabic ? 'الجهات' : 'Agencies';
      case 5:
        return isArabic ? 'الإفراج' : 'Release';
      default:
        return '';
    }
  }
}
