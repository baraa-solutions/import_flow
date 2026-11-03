import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/api_error_text.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/localization/stored_text.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../../../core/widgets/concurrency_conflict_dialog.dart';
import '../../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../models/docs_customs_approval_model.dart';
import '../../../providers/docs_customs_approval_provider.dart';
import '../../idoc_feedback.dart';
import '../../idoc_ui.dart';
import '../doc_approval_helpers.dart';

class CommercialReviewDialog extends StatefulWidget {
  final CustomsDocumentApprovalModel item;
  final int? importFileId;

  const CommercialReviewDialog({super.key, required this.item, this.importFileId});

  @override
  State<CommercialReviewDialog> createState() => _CommercialReviewDialogState();
}

class _CommercialReviewDialogState extends State<CommercialReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedStatus = 'Approved';
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final me = idocCurrentUserNameOf(context);
      _nameCtrl.text = me.isNotEmpty ? me : storedText.customsApprovalDefaultCommercialReviewer;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(builder: (context, ref, _) {
      return AlertDialog(
        backgroundColor: isDark ? AppTheme.darkElevatedSurface : null,
        title: Text(context.l10n.customsApprovalCommercialDialogTitle(
          DocApprovalHelpers.getLocalizedDocType(widget.item.documentType, context.l10n),
        )),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.customsApprovalCommercialReviewerLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? context.l10n.customsApprovalRequiredField : null,
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<String>(
                  value: _selectedStatus,
                  labelText: context.l10n.customsApprovalCommercialDecisionLabel,
                  searchHintText: context.l10n.customsApprovalSelectDecisionHint,
                  items: [
                    SearchableDropdownItem(
                      value: 'Approved',
                      label: context.l10n.customsApprovalDecisionCommercialApproved,
                    ),
                    SearchableDropdownItem(
                      value: 'Under Review',
                      label: context.l10n.customsApprovalDecisionCommercialUnderReview,
                    ),
                    SearchableDropdownItem(
                      value: 'Rejected',
                      label: context.l10n.customsApprovalDecisionCommercialRejected,
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.l10n.customsApprovalCommercialNotesLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IdocUi.fit(AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
          )),
          IdocUi.fit(AppButton(
            label: context.l10n.customsApprovalSaveApprovalButton,
            variant: AppButtonVariant.primary,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(docsCustomsApprovalProvider.notifier).submitCommercialReview(
                            approvalId: widget.item.approvalId,
                            reviewerName: _nameCtrl.text.trim(),
                            status: _selectedStatus,
                            notes: _notesCtrl.text.trim(),
                            importFileId: widget.importFileId,
                            version: widget.item.version,
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (e is DioException && isIdocVersionConflict(e)) {
                        final data = e.response?.data;
                        final conflict = (data is Map<String, dynamic> && data['detail'] is Map)
                            ? Map<String, dynamic>.from(data['detail'] as Map)
                            : (data is Map<String, dynamic> ? data : <String, dynamic>{});
                        if (context.mounted) {
                          final resolution = await ConcurrencyConflictDialog.show(
                            context,
                            entityName: conflict['entity'] as String? ?? 'CustomsDocumentApproval',
                            recordId: conflict['record_id'] ?? widget.item.approvalId,
                            currentVersion:
                                (conflict['current_version'] as num?)?.toInt() ?? (widget.item.version + 1),
                            submittedVersion: (conflict['submitted_version'] as num?)?.toInt() ?? widget.item.version,
                            updatedAt: conflict['updated_at'] as String?,
                            updatedBy: conflict['updated_by'] as String?,
                            serverMessage: conflict['message'] as String?,
                            currentDraftData: {
                              'reviewer_name': _nameCtrl.text.trim(),
                              'status': _selectedStatus,
                              'notes': _notesCtrl.text.trim(),
                            },
                          );
                          if (context.mounted && resolution == ConcurrencyResolution.discardAndReload) {
                            Navigator.pop(context);
                            if (widget.importFileId != null) {
                              await ref
                                  .read(docsCustomsApprovalProvider.notifier)
                                  .fetchApprovals(importFileId: widget.importFileId);
                            }
                          }
                        }
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.customsApprovalError(ApiErrorText.of(context.l10n, e))),
                            backgroundColor: AppTheme.crimson,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isSubmitting = false);
                      }
                    }
                  },
          )),
        ],
      );
    });
  }
}
