import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/rbac_provider.dart';
import '../models/step_config_model.dart';
import '../providers/step_config_provider.dart';

/// Modal dialog for editing a single lifecycle step's skip policy and governance configuration.
class StepConfigEditDialog extends ConsumerStatefulWidget {
  final StepConfigModel config;

  const StepConfigEditDialog({super.key, required this.config});

  @override
  ConsumerState<StepConfigEditDialog> createState() => _StepConfigEditDialogState();
}

class _StepConfigEditDialogState extends ConsumerState<StepConfigEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _skipPolicy;
  late bool _supportsPendingReference;
  late List<String> _approverRoles;
  late List<String> _reasonCategories;
  final TextEditingController _justificationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _skipPolicy = widget.config.skipPolicy;
    _supportsPendingReference = widget.config.supportsPendingReference;
    _approverRoles = widget.config.approverRoles
        .map((r) => r == 'Manager' ? 'GENERAL_MANAGER' : r)
        .where((r) => r != 'ComplianceHead')
        .toList();
    if (_approverRoles.isEmpty) {
      _approverRoles = ['GENERAL_MANAGER'];
    }
    _reasonCategories = List.from(widget.config.reasonCategories);
  }

  @override
  void dispose() {
    _justificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stepConfigProvider);
    final rbacState = ref.watch(rbacProvider);
    final availableRoles = rbacState.roles.isNotEmpty
        ? rbacState.roles.map((r) => r.roleCode).toList()
        : const ['GENERAL_MANAGER', 'ADMIN', 'LOGISTICS_OPERATOR'];
    final l = context.l10n;
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        Directionality.of(context) == TextDirection.rtl;
    final stepName = isAr ? widget.config.stepNameAr : widget.config.stepNameEn;

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.flatCobalt.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.settings_suggest_rounded,
                color: AppTheme.flatCobalt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.stepConfigEditDialogTitle(widget.config.stepCode),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    stepName,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip Policy selector
                  Text(
                    l.stepConfigSkipPolicyLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SearchableDropdownField<String>(
                    value: _skipPolicy,
                    labelText: l.stepConfigSkipPolicyLabel,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    items: [
                      SearchableDropdownItem<String>(
                        value: 'blocked',
                        label: l.stepConfigPolicyItemBlocked,
                      ),
                      SearchableDropdownItem<String>(
                        value: 'single_approval',
                        label: l.stepConfigPolicyItemSingleApproval,
                      ),
                      SearchableDropdownItem<String>(
                        value: 'dual_approval',
                        label: l.stepConfigPolicyItemDualApproval,
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _skipPolicy = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Supports Pending Reference Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l.stepConfigPendingRefToggleTitle,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          l.stepConfigPendingRefToggleSubtitle,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        value: _supportsPendingReference,
                        activeThumbColor: AppTheme.flatCobalt,
                        onChanged: (val) => setState(() => _supportsPendingReference = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Approver Roles
                  Text(
                    l.stepConfigApproverRolesTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.stepConfigApproverRolesSubtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final role in availableRoles)
                        FilterChip(
                          label: Text(role),
                          selected: _approverRoles.contains(role),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _approverRoles.add(role);
                              } else {
                                if (_approverRoles.length > 1) {
                                  _approverRoles.remove(role);
                                }
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mandatory Justification Field
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_document, size: 18, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.stepConfigJustificationTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _justificationController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: l.stepConfigJustificationHint,
                            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().length < 5) {
                              return l.stepConfigJustificationValidator;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.stepConfigCancelBtn),
          ),
          ElevatedButton.icon(
            onPressed: state.isSaving ? null : _handleSave,
            icon: state.isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: AppLoadingState.inline(),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(l.stepConfigSaveBtn),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.flatCobalt,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;

    final success = await ref.read(stepConfigProvider.notifier).updateStepConfig(
          stepCode: widget.config.stepCode,
          skipPolicy: _skipPolicy,
          reasonCategories: _reasonCategories,
          approverRoles: _approverRoles,
          supportsPendingReference: _supportsPendingReference,
          justification: _justificationController.text.trim(),
        );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.stepConfigSaveSuccess(widget.config.stepCode),
          severity: AppSeverity.success,
        ),
      );
    } else if (!success && mounted) {
      final error = ref.read(stepConfigProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, error, severity: AppSeverity.danger),
        );
      }
    }
  }
}
