import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/smart_tasks_provider.dart';
import '../models/smart_task_model.dart';

class SmartTaskDialog extends ConsumerStatefulWidget {
  final SmartTaskModel? taskToEdit;

  const SmartTaskDialog({super.key, this.taskToEdit});

  static Future<void> show(BuildContext context, {SmartTaskModel? taskToEdit}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SmartTaskDialog(taskToEdit: taskToEdit),
    );
  }

  @override
  ConsumerState<SmartTaskDialog> createState() => _SmartTaskDialogState();
}

class _SmartTaskDialogState extends ConsumerState<SmartTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _notesController;
  late TextEditingController _dueDateController;
  late TextEditingController _reminderDateController;

  String _taskType = 'Manual To-Do';
  String _priority = 'Medium';
  String _reminderType = 'General Reminder';
  String _assignedUser = 'Kamal';
  int? _selectedFileId;
  String? _selectedFileCode;
  bool _isSubmitting = false;

  static const List<String> _priorities = ['Low', 'Medium', 'High', 'Critical'];
  static const List<String> _reminderTypes = [
    'General Reminder',
    'Supplier Follow-up',
    'Bank Form 4',
    'Shipping Line',
    'Customs Broker',
    'Document Review',
    'ETA Arrival',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
    _dueDateController = TextEditingController(text: t?.dueDate ?? DateTime.now().add(const Duration(days: 2)).toString().split(' ')[0]);
    _reminderDateController = TextEditingController(text: t?.reminderDate ?? DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0]);

    if (t != null) {
      _taskType = t.taskType;
      _priority = t.priority;
      _reminderType = t.reminderType;
      _assignedUser = t.assignedUser;
      _selectedFileId = t.importFileId;
      _selectedFileCode = t.importFileCode;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    _dueDateController.dispose();
    _reminderDateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'task_type': _taskType,
        'import_file_id': _selectedFileId,
        'import_file_code': _selectedFileCode,
        'assigned_user': _assignedUser,
        'priority': _priority,
        'reminder_type': _reminderType,
        'due_date': _dueDateController.text,
        'reminder_date': _reminderDateController.text,
        'notes': _notesController.text.trim(),
      };

      if (widget.taskToEdit != null) {
        await ref.read(smartTasksProvider.notifier).updateTask(widget.taskToEdit!.taskId, payload);
      } else {
        await ref.read(smartTasksProvider.notifier).createTask(payload);
      }

      if (mounted) {
        final l = context.l10n;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, widget.taskToEdit != null ? l.smartTaskSuccessUpdated : l.smartTaskSuccessCreated, severity: AppSeverity.success),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.smartTaskSubmitError(e.toString()), severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final importFilesState = ref.watch(importFilesProvider);
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SelectionArea(
        child: Container(
          width: 650,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_task, color: AppTheme.cobalt, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.taskToEdit != null ? l.smartTaskDialogEditTitle : l.smartTaskDialogNewTitle,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: l.smartTaskFieldTitle,
                            prefixIcon: const Icon(Icons.title),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                              tooltip: l.smartTaskCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(context, _titleController.text),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? l.smartTaskFieldTitleRequired : null,
                        ),
                        const SizedBox(height: 14),

                        // Related Import File Searchable Dropdown
                        importFilesState.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (files) {
                            return SearchableDropdownField<int>(
                              value: _selectedFileId,
                              labelText: l.smartTaskFieldLinkShipment,
                              items: files.map((f) => SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '${f.primaryNameWithCode} - ${f.supplierName}',
                              )).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedFileId = val;
                                  if (val != null) {
                                     final selectedFile = files.firstWhere((f) => f.importFileId == val);
                                     _selectedFileCode = selectedFile.importFileCode;
                                  } else {
                                     _selectedFileCode = null;
                                  }
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Priority & Reminder Type Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _priority,
                                isExpanded: true,
                                decoration: InputDecoration(labelText: l.smartTaskFieldPriority, border: const OutlineInputBorder()),
                                items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(l.smartTaskPriorityLabel(p)))).toList(),
                                onChanged: (v) => setState(() => _priority = v!),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _reminderType,
                                isExpanded: true,
                                decoration: InputDecoration(labelText: l.smartTaskFieldReminderType, border: const OutlineInputBorder()),
                                items: _reminderTypes.map((t) => DropdownMenuItem(value: t, child: Text(l.smartTaskReminderTypeLabel(t)))).toList(),
                                onChanged: (v) => setState(() => _reminderType = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Due Date & Reminder Date Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dueDateController,
                                decoration: InputDecoration(
                                  labelText: l.smartTaskFieldDueDate,
                                  prefixIcon: const Icon(Icons.event),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                                    tooltip: l.smartTaskCopyFieldTooltip,
                                    onPressed: () => CopyHelper.copy(context, _dueDateController.text),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _reminderDateController,
                                decoration: InputDecoration(
                                  labelText: l.smartTaskFieldReminderDate,
                                  prefixIcon: const Icon(Icons.notifications_active),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                                    tooltip: l.smartTaskCopyFieldTooltip,
                                    onPressed: () => CopyHelper.copy(context, _reminderDateController.text),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Description
                        TextFormField(
                          controller: _descController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: l.smartTaskFieldDescription,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                              tooltip: l.smartTaskCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(context, _descController.text),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: l.smartTaskFieldNotes,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                              tooltip: l.smartTaskCopyFieldTooltip,
                              onPressed: () => CopyHelper.copy(context, _notesController.text),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.smartTaskBtnCancel)),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check, color: Colors.white),
                    label: Text(widget.taskToEdit != null ? l.smartTaskBtnUpdate : l.smartTaskBtnSave, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
