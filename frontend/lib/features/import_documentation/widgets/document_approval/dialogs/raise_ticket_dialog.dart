import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/api_error_text.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../models/docs_customs_approval_model.dart';
import '../../../providers/docs_customs_approval_provider.dart';
import '../../idoc_ui.dart';

class RaiseTicketDialog extends StatefulWidget {
  final int importFileId;
  final CustomsDocumentApprovalModel? approvalItem;
  final DiscrepancyRectificationTicketModel? initialTicket;

  const RaiseTicketDialog({
    super.key,
    required this.importFileId,
    this.approvalItem,
    this.initialTicket,
  });

  @override
  State<RaiseTicketDialog> createState() => _RaiseTicketDialogState();
}

class _RaiseTicketDialogState extends State<RaiseTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  String _issueCategory = 'HS Code Mismatch';
  String _severity = 'Major';
  final _descCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();
  final _foundCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTicket != null) {
      _issueCategory = widget.initialTicket!.issueCategory;
      _severity = widget.initialTicket!.severity;
      _descCtrl.text = widget.initialTicket!.description;
      _expectedCtrl.text = widget.initialTicket!.expectedValue ?? '';
      _foundCtrl.text = widget.initialTicket!.foundValue ?? '';
      _actionCtrl.text = widget.initialTicket!.supplierActionRequired ?? '';
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _expectedCtrl.dispose();
    _foundCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(builder: (context, ref, _) {
      return AlertDialog(
        backgroundColor: isDark ? AppTheme.darkElevatedSurface : null,
        title: Text(context.l10n.customsApprovalRaiseTicketDialogTitle),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<String>(
                    value: _issueCategory,
                    labelText: context.l10n.customsApprovalIssueCategoryLabel,
                    searchHintText: context.l10n.customsApprovalSelectCategoryHint,
                    items: [
                      SearchableDropdownItem(
                        value: 'HS Code Mismatch',
                        label: context.l10n.customsApprovalCatHsMismatch,
                      ),
                      SearchableDropdownItem(
                        value: 'Weight Discrepancy',
                        label: context.l10n.customsApprovalCatWeightDiscrepancy,
                      ),
                      SearchableDropdownItem(
                        value: 'CBM Discrepancy',
                        label: context.l10n.customsApprovalCatCbmDiscrepancy,
                      ),
                      SearchableDropdownItem(
                        value: 'Value Mismatch',
                        label: context.l10n.customsApprovalCatValueMismatch,
                      ),
                      SearchableDropdownItem(
                        value: 'Missing ACID',
                        label: context.l10n.customsApprovalCatMissingAcid,
                      ),
                      SearchableDropdownItem(
                        value: 'Incoterm Conflict',
                        label: context.l10n.customsApprovalCatIncotermConflict,
                      ),
                      SearchableDropdownItem(
                        value: 'Other',
                        label: context.l10n.customsApprovalCatOther,
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _issueCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SearchableDropdownField<String>(
                    value: _severity,
                    labelText: context.l10n.customsApprovalSeverityLabel,
                    searchHintText: context.l10n.customsApprovalSelectSeverityHint,
                    items: [
                      SearchableDropdownItem(
                        value: 'Critical',
                        label: context.l10n.customsApprovalSevCritical,
                      ),
                      SearchableDropdownItem(
                        value: 'Major',
                        label: context.l10n.customsApprovalSevMajor,
                      ),
                      SearchableDropdownItem(
                        value: 'Minor',
                        label: context.l10n.customsApprovalSevMinor,
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _severity = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: context.l10n.customsApprovalIssueDescLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().length < 5 ? context.l10n.customsApprovalIssueDescMinLength : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expectedCtrl,
                          decoration: InputDecoration(
                            labelText: context.l10n.customsApprovalExpectedValueLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _foundCtrl,
                          decoration: InputDecoration(
                            labelText: context.l10n.customsApprovalFoundValueLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _actionCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.customsApprovalSupplierActionLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
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
            label: context.l10n.customsApprovalCreateTicketSubmitButton,
            variant: AppButtonVariant.warning,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(discrepancyTicketsProvider.notifier).createTicket({
                        'import_file_id': widget.importFileId,
                        'approval_id': widget.approvalItem?.approvalId,
                        'issue_category': _issueCategory,
                        'severity': _severity,
                        'description': _descCtrl.text.trim(),
                        'expected_value': _expectedCtrl.text.trim(),
                        'found_value': _foundCtrl.text.trim(),
                        'supplier_action_required': _actionCtrl.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.customsApprovalError(ApiErrorText.of(context.l10n, e))),
                            backgroundColor: AppTheme.crimson,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  },
          )),
        ],
      );
    });
  }
}
