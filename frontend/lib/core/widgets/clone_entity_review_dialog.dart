import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../localization/app_localizations_ar.dart';
import 'copyable_data_helper.dart';

/// Reusable Mandatory Review Dialog for Universal Entity Cloning (UX-CLONE-011).
/// Differentiates clearly between copied data and mandatorily reset fields.
class CloneEntityReviewDialog extends StatefulWidget {
  final String entityType;
  final String sourceCode;
  final String suggestedNewCode;
  final String sourceTitle;
  final Map<String, String> copiedFieldsSummary;
  final List<String> mandatorilyResetFields;
  final bool allowCopyLineItems;
  final bool allowCopyAttachments;
  final bool initialCopyLineItems;
  final bool initialCopyAttachments;
  final Future<void> Function({
    required String newCode,
    required String newTitle,
    required bool copyLineItems,
    required bool copyAttachments,
    String? notes,
  }) onConfirm;

  const CloneEntityReviewDialog({
    super.key,
    required this.entityType,
    required this.sourceCode,
    required this.suggestedNewCode,
    required this.sourceTitle,
    required this.copiedFieldsSummary,
    required this.mandatorilyResetFields,
    this.allowCopyLineItems = true,
    this.allowCopyAttachments = true,
    this.initialCopyLineItems = true,
    this.initialCopyAttachments = false,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required String entityType,
    required String sourceCode,
    required String suggestedNewCode,
    required String sourceTitle,
    required Map<String, String> copiedFieldsSummary,
    required List<String> mandatorilyResetFields,
    bool allowCopyLineItems = true,
    bool allowCopyAttachments = true,
    bool initialCopyLineItems = true,
    bool initialCopyAttachments = false,
    required Future<void> Function({
      required String newCode,
      required String newTitle,
      required bool copyLineItems,
      required bool copyAttachments,
      String? notes,
    }) onConfirm,
  }) {
    final isArFromApp = AppLocalizations.of(context) is AppLocalizationsAr;
    final textDir = Directionality.maybeOf(context) ?? (isArFromApp ? TextDirection.rtl : TextDirection.ltr);
    final isArabic = isArFromApp || textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final locale = isArabic ? const Locale('ar') : const Locale('en');
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: entityType,
            sourceCode: sourceCode,
            suggestedNewCode: suggestedNewCode,
            sourceTitle: sourceTitle,
            copiedFieldsSummary: copiedFieldsSummary,
            mandatorilyResetFields: mandatorilyResetFields,
            allowCopyLineItems: allowCopyLineItems,
            allowCopyAttachments: allowCopyAttachments,
            initialCopyLineItems: initialCopyLineItems,
            initialCopyAttachments: initialCopyAttachments,
            onConfirm: onConfirm,
          ),
        ),
      ),
    );
  }

  @override
  State<CloneEntityReviewDialog> createState() => _CloneEntityReviewDialogState();
}

class _CloneEntityReviewDialogState extends State<CloneEntityReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  late bool _copyLineItems;
  late bool _copyAttachments;
  bool _isLoading = false;
  String? _backendErrorMessage;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.suggestedNewCode);
    _titleController = TextEditingController(text: widget.sourceTitle);
    _notesController = TextEditingController();
    _copyLineItems = widget.initialCopyLineItems;
    _copyAttachments = widget.initialCopyAttachments;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasUserModifications =>
      _codeController.text.trim() != widget.suggestedNewCode ||
      _notesController.text.trim().isNotEmpty;

  Future<bool> _onWillPop() async {
    if (!_hasUserModifications || _isLoading) return true;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تجاهل التغييرات؟' : 'Discard Changes?'),
        content: Text(
          isAr
              ? 'لديك تعديلات غير محفوظة في شاشة الاستنساخ. هل تريد الإلغاء والخروج؟'
              : 'You have unsaved modifications in the clone dialog. Do you want to cancel and exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isAr ? 'البقاء في الشاشة' : 'Stay Here'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isAr ? 'نعم، إلغاء' : 'Yes, Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _submitClone() async {
    if (_isLoading) return;
    setState(() => _backendErrorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onConfirm(
        newCode: _codeController.text.trim(),
        newTitle: _titleController.text.trim(),
        copyLineItems: _copyLineItems,
        copyAttachments: _copyAttachments,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _backendErrorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar';
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 768;
    final dialogWidth = isMobile
        ? (media.size.width - 24).clamp(300.0, 700.0)
        : (media.size.width * 0.85).clamp(650.0, 920.0);
    final dialogMaxHeight = isMobile
        ? (media.size.height - 32).clamp(400.0, 800.0)
        : (media.size.height * 0.90).clamp(480.0, 750.0);

    return PopScope(
      canPop: !_hasUserModifications && !_isLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16,
          vertical: isMobile ? 12 : 16,
        ),
        child: SelectionArea(
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: dialogMaxHeight),
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.cloneEntityDialogTitle(widget.entityType),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.cloneEntityDialogSubtitle,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      // Source Code Badge with Copy Action
                      InkWell(
                        onTap: () => CopyHelper.copy(context, widget.sourceCode),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l.cloneSourceReferenceLabel(widget.sourceCode),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoal,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded, size: 13, color: AppTheme.cobalt),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isMobile) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => CopyHelper.copy(context, widget.sourceCode),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              l.cloneSourceReferenceLabel(widget.sourceCode),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 13, color: AppTheme.cobalt),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── Scrollable Body ──
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error banner if any
                        if (_backendErrorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.crimson, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _backendErrorMessage!,
                                    style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Target Code & Title Inputs
                        if (isMobile) ...[
                          TextFormField(
                            controller: _codeController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: l.cloneNewCodeLabel,
                              isDense: true,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.tag_rounded, size: 16),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return l.cloneNewCodeRequiredError;
                              }
                              if (val.trim() == widget.sourceCode.trim()) {
                                return isAr
                                    ? 'يجب إدخال كود جديد مختلف عن الكود الأصلي'
                                    : 'Target code must be different from source code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: isAr ? 'المسمى أو العنوان الجديد:' : 'Target Title / Name:',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.title_rounded, size: 16),
                            ),
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _codeController,
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    labelText: l.cloneNewCodeLabel,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.tag_rounded, size: 16),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return l.cloneNewCodeRequiredError;
                                    }
                                    if (val.trim() == widget.sourceCode.trim()) {
                                      return isAr
                                          ? 'يجب إدخال كود جديد مختلف عن الكود الأصلي'
                                          : 'Target code must be different from source code';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    labelText: isAr ? 'المسمى أو العنوان الجديد:' : 'Target Title / Name:',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.title_rounded, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Section: Copied Data vs Mandatorily Reset Fields
                        Builder(
                          builder: (context) {
                            final copiedBox = Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50.withValues(alpha: 0.5),
                                border: Border.all(color: Colors.green.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          l.cloneCopiedFieldsHeader,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppTheme.emerald,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...widget.copiedFieldsSummary.entries.map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 120),
                                            child: Text(
                                              '• ${entry.key}: ',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.charcoal,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              entry.value,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            final resetBox = Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50.withValues(alpha: 0.5),
                                border: Border.all(color: Colors.orange.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.restart_alt_rounded, color: AppTheme.orange, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          l.cloneResetFieldsHeader,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppTheme.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...widget.mandatorilyResetFields.map(
                                    (field) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('• ', style: TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              field,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Traceability indicator
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Text('• ', style: TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                                        Expanded(
                                          child: Text(
                                            isAr
                                                ? 'ربط التتبع: يتم تسجيل (مستنسخ من: ${widget.sourceCode}) تلقائياً'
                                                : 'Traceability: (Cloned from: ${widget.sourceCode}) linked automatically',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.cobalt,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (isMobile) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  copiedBox,
                                  const SizedBox(height: 10),
                                  resetBox,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: copiedBox),
                                const SizedBox(width: 10),
                                Expanded(child: resetBox),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // Checkbox options
                        if (widget.allowCopyLineItems) ...[
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            value: _copyLineItems,
                            activeColor: AppTheme.cobalt,
                            title: Text(
                              l.cloneCopyInvoicesCheckbox,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) => setState(() => _copyLineItems = val ?? true),
                          ),
                        ],
                        if (widget.allowCopyAttachments) ...[
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            value: _copyAttachments,
                            activeColor: AppTheme.cobalt,
                            title: Text(
                              l.cloneCopyAttachmentsCheckbox,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _copyAttachments ? AppTheme.charcoal : Colors.grey.shade700,
                              ),
                            ),
                            subtitle: Text(
                              isAr
                                  ? 'تنبيه: لا يوصى بنسخ المستندات الرقمية إلا إذا كانت مطابقة لنفس الشحنة'
                                  : 'Caution: Copying attachments is generally discouraged unless identical',
                              style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) => setState(() => _copyAttachments = val ?? false),
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Optional Notes Field
                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            labelText: isAr ? 'ملاحظات إضافية على الاستنساخ (اختياري):' : 'Additional Clone Notes (Optional):',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── Footer Actions ──
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final shouldPop = await _onWillPop();
                              if (shouldPop && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                      child: Text(
                        isAr ? 'إلغاء' : 'Cancel',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton.icon(
                      key: const Key('confirmCloneBtn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoading ? null : _submitClone,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.control_point_duplicate_rounded, size: 16),
                      label: Text(
                        l.cloneConfirmAndCreateBtn,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
