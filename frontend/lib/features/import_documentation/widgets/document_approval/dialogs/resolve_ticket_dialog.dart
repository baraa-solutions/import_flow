import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/api_error_text.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/localization/stored_text.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../models/docs_customs_approval_model.dart';
import '../../../providers/docs_customs_approval_provider.dart';
import '../../idoc_feedback.dart';
import '../../idoc_ui.dart';

class ResolveTicketDialog extends StatefulWidget {
  final DiscrepancyRectificationTicketModel ticket;
  final int? importFileId;

  const ResolveTicketDialog({
    super.key,
    required this.ticket,
    this.importFileId,
  });

  @override
  State<ResolveTicketDialog> createState() => _ResolveTicketDialogState();
}

class _ResolveTicketDialogState extends State<ResolveTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _responseCtrl = TextEditingController();
  final _resolverCtrl = TextEditingController();
  String _newStatus = 'Resolved';
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final me = idocCurrentUserNameOf(context);
      _resolverCtrl.text = me.isNotEmpty ? me : storedText.customsApprovalDefaultComplianceOfficer;
    }
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    _resolverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(builder: (context, ref, _) {
      return AlertDialog(
        backgroundColor: isDark ? AppTheme.darkElevatedSurface : null,
        title: Text(context.l10n.customsApprovalResolveTicketDialogTitle(widget.ticket.ticketCode)),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _responseCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.l10n.customsApprovalSupplierResponseLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? context.l10n.customsApprovalRequiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _resolverCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.customsApprovalResolverNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? context.l10n.customsApprovalRequiredField : null,
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<String>(
                  value: _newStatus,
                  labelText: context.l10n.customsApprovalFinalStatusLabel,
                  searchHintText: context.l10n.customsApprovalSelectStatusHint,
                  items: [
                    SearchableDropdownItem(
                      value: 'Resolved',
                      label: context.l10n.customsApprovalStatusResolved,
                    ),
                    SearchableDropdownItem(
                      value: 'Waived',
                      label: context.l10n.customsApprovalStatusWaived,
                    ),
                    SearchableDropdownItem(
                      value: 'Closed',
                      label: context.l10n.customsApprovalStatusClosed,
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _newStatus = val);
                  },
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
            label: context.l10n.customsApprovalConfirmResolveTicketButton,
            variant: AppButtonVariant.success,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _isSubmitting = true);
                    try {
                      await ref.read(discrepancyTicketsProvider.notifier).resolveTicket(
                            widget.ticket.ticketId,
                            {
                              'supplier_response': _responseCtrl.text.trim(),
                              'resolved_by': _resolverCtrl.text.trim(),
                              'new_status': _newStatus,
                            },
                            importFileId: widget.importFileId,
                          );
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
