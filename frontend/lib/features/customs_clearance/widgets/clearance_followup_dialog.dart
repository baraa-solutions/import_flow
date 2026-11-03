import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/customs_clearance_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'followup/clearance_followup_card.dart';
import 'followup/clearance_followup_form.dart';
import 'followup/clearance_followup_header.dart';
import 'followup/clearance_followup_stepper.dart';

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
        child: SelectionArea(
          child: Column(
            children: [
              ClearanceFollowupHeader(
                clearanceRecord: r,
                importFile: f,
                onClose: () => Navigator.of(context).pop(),
              ),
              logsAsync.when(
                loading: () => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppTheme.charcoalSurface,
                  child: const SizedBox(height: 28),
                ),
                error: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppTheme.charcoalSurface,
                  child: const SizedBox(height: 28),
                ),
                data: (logs) => ClearanceFollowupStepper(
                  logs: logs,
                  isArabic: l.isArabic,
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    // Left Side: Follow-up History (50%)
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
                                          Icon(
                                            Icons.assignment_late_outlined,
                                            size: 36,
                                            color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            l.isArabic
                                                ? 'لا توجد متابعات ميدانية مسجلة حتى الآن.'
                                                : 'No field follow-ups recorded yet.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondaryOf(context),
                                            ),
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
                                      return ClearanceFollowupCard(
                                        item: item,
                                        onComplete: (logId) => _completeFollowup(logId),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right Side: Add New Follow-up Form (50%)
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ClearanceFollowupForm(
                          formKey: _formKey,
                          followupSeq: _followupSeq,
                          selectedAuthorityType: _selectedAuthorityType,
                          officialContactController: _officialContactController,
                          statusSummaryController: _statusSummaryController,
                          actionRequiredController: _actionRequiredController,
                          followupDate: _followupDate,
                          nextVisitDate: _nextVisitDate,
                          isSubmitting: _isSubmitting,
                          onSeqChanged: (seq) => setState(() => _followupSeq = seq),
                          onAuthorityChanged: (auth) => setState(() => _selectedAuthorityType = auth),
                          onFollowupDateChanged: (d) => setState(() => _followupDate = d),
                          onNextVisitDateChanged: (d) => setState(() => _nextVisitDate = d),
                          onSubmit: _submitNewFollowup,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusLg)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: l.isArabic ? 'إغلاق' : 'Close',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
