/// RecalculateButton — Centralized Recalculation Engine Widget (CRE-001)
///
/// This is THE ONLY widget for triggering recalculation/sync across the entire app.
/// No page should implement its own sync button or HTTP sync logic.
///
/// Usage:
/// ```dart
/// RecalculateButton(
///   entityType: 'import_budget',
///   entityId: budget.budgetId,
///   sourcePage: 'BudgetRegistryScreen',
///   onSuccess: (result) {
///     ref.invalidate(importBudgetsProvider);
///     // Show result dialog, refresh, etc.
///   },
/// )
/// ```
///
/// Behavior:
/// 1. On press: calls preview() and shows a variance dialog.
/// 2. If user confirms: calls apply() with optional justification.
/// 3. If Hard Block: shows justification input field before allowing apply.
/// 4. Loading indicator is shown inside the button during async calls.
/// 5. All errors from the API are shown in a clear dialog — never silently ignored.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/recalculation/models/recalculation_model.dart';
import '../../features/recalculation/providers/recalculation_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────

class RecalculateButton extends ConsumerStatefulWidget {
  /// The target entity type, e.g. 'import_budget'.
  final String entityType;

  /// The target entity primary key ID.
  final int entityId;

  /// The page name, used in the audit log (e.g. 'BudgetRegistryScreen').
  final String sourcePage;

  /// Called after a successful apply with the result data.
  /// The parent page should use this to invalidate providers and refresh.
  final void Function(RecalculationApplyResult result)? onSuccess;

  /// Optional custom label (default: 'مزامنة التكاليف').
  final String? label;

  /// Whether to show as an icon-only button (default: false = text + icon).
  final bool iconOnly;

  /// Disables the button externally (e.g. if user does not have permission).
  final bool disabled;

  const RecalculateButton({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.sourcePage,
    this.onSuccess,
    this.label,
    this.iconOnly = false,
    this.disabled = false,
  });

  @override
  ConsumerState<RecalculateButton> createState() => _RecalculateButtonState();
}

class _RecalculateButtonState extends ConsumerState<RecalculateButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = widget.label ?? 'مزامنة التكاليف';

    if (widget.iconOnly) {
      return Tooltip(
        message: buttonLabel,
        child: IconButton(
          onPressed: (widget.disabled || _isLoading) ? null : _onPressed,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded, size: 20),
          color: AppTheme.cobalt,
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: (widget.disabled || _isLoading) ? null : _onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.cobalt,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.sync_rounded, size: 18),
      label: Text(
        _isLoading ? 'جاري التحقق...' : buttonLabel,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _onPressed() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(recalculationProvider);

      // Step 1: Preview — read-only variance check
      final preview = await notifier.preview(
        targetEntityType: widget.entityType,
        targetEntityId: widget.entityId,
        sourcePage: widget.sourcePage,
      );

      if (!mounted) return;

      // Step 2: Show preview dialog
      if (!mounted) return;
      final confirmed = await _showPreviewDialog(context, preview);
      if (!confirmed) return;
      if (!mounted) return;

      // Step 3: If Hard Block, require justification
      String? justification;
      if (preview.hasHardBlock) {
        justification = await _showJustificationDialog(context, preview);
        if (justification == null) return; // User cancelled
      }

      // Step 4: Apply
      setState(() => _isLoading = true); // Re-engage loading
      final result = await notifier.apply(
        targetEntityType: widget.entityType,
        targetEntityId: widget.entityId,
        sourcePage: widget.sourcePage,
        justification: justification,
      );

      if (!mounted) return;

      // Step 5: Notify success
      _showSuccessSnackbar(context, result);
      widget.onSuccess?.call(result);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = (e.response?.data as Map<String, dynamic>?)?['detail'];
      final message = detail?.toString() ?? e.message ?? 'خطأ في الاتصال بالسيرفر';
      _showErrorDialog(context, message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Preview Dialog ──────────────────────────────────────────────────────────

  Future<bool> _showPreviewDialog(
    BuildContext context,
    RecalculationPreviewResponse preview,
  ) async {
    if (!preview.hasAnyVariance) {
      // No variance: nothing to sync, show info
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(preview.messageAr),
          backgroundColor: AppTheme.emerald,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => _PreviewDialog(preview: preview),
        ) ??
        false;
  }

  // ── Justification Dialog (required for Hard Block) ──────────────────────────

  Future<String?> _showJustificationDialog(
    BuildContext context,
    RecalculationPreviewResponse preview,
  ) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _JustificationDialog(maxVariancePct: preview.maxVariancePct),
    );
  }

  // ── Success Snackbar ─────────────────────────────────────────────────────────

  void _showSuccessSnackbar(BuildContext context, RecalculationApplyResult result) {
    Color bgColor;
    switch (result.actionTaken) {
      case 'revision_created':
        bgColor = AppTheme.orange;
        break;
      case 'auto_updated':
        bgColor = AppTheme.emerald;
        break;
      default:
        bgColor = AppTheme.cobalt;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.messageAr),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Error Dialog ─────────────────────────────────────────────────────────────

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.crimson, size: 22),
            SizedBox(width: 8),
            Text('خطأ في المزامنة', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SelectableText(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Preview Dialog Widget
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewDialog extends StatelessWidget {
  final RecalculationPreviewResponse preview;

  const _PreviewDialog({required this.preview});

  @override
  Widget build(BuildContext context) {
    final changedItems = preview.changedItems;
    final hasHardBlock = preview.hasHardBlock;
    final isApproved = preview.blockedByStatus;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            hasHardBlock ? Icons.warning_amber_rounded : Icons.sync_rounded,
            color: hasHardBlock ? AppTheme.orange : AppTheme.cobalt,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'معاينة مزامنة التكاليف',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status message
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasHardBlock
                      ? AppTheme.orange.withValues(alpha: 0.1)
                      : AppTheme.cobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasHardBlock
                        ? AppTheme.orange.withValues(alpha: 0.4)
                        : AppTheme.cobalt.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  preview.messageAr,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasHardBlock ? AppTheme.orange : AppTheme.cobalt,
                    height: 1.4,
                  ),
                ),
              ),

              if (isApproved) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '⚠️ الميزانية في حالة "${preview.currentEntityStatus}".\n'
                    'سيتم إنشاء مراجعة جديدة (Revision) بدلاً من التعديل المباشر على الميزانية الحالية.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.crimson,
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Text(
                'الفوارق المرصودة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              // Variance table
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.2),
                },
                border: TableBorder.all(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                children: [
                  // Header
                  const TableRow(
                    decoration: BoxDecoration(color: AppTheme.charcoal),
                    children: [
                      _HeaderCell('البند'),
                      _HeaderCell('القيمة الحالية'),
                      _HeaderCell('القيمة الحية'),
                      _HeaderCell('الفارق %'),
                    ],
                  ),
                  // Rows
                  for (final item in changedItems)
                    TableRow(
                      decoration: BoxDecoration(
                        color: item.isHardBlock
                            ? AppTheme.crimson.withValues(alpha: 0.05)
                            : (item.variancePercentage > 0
                                ? AppTheme.orange.withValues(alpha: 0.03)
                                : Colors.white),
                      ),
                      children: [
                        _DataCell(item.labelAr),
                        _DataCell(_fmt(item.oldValue), align: TextAlign.end),
                        _DataCell(_fmt(item.newValue), align: TextAlign.end),
                        _DataCell(
                          item.formattedVariancePct,
                          textColor: item.isHardBlock ? AppTheme.crimson : AppTheme.orange,
                          bold: item.isHardBlock,
                          align: TextAlign.center,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        if (preview.canApply)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasHardBlock ? AppTheme.orange : AppTheme.cobalt,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              isApproved ? 'إنشاء مراجعة بالتكاليف الجديدة' : 'تأكيد المزامنة',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.crimson.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'لا يمكن التطبيق — الحالة: ${preview.currentEntityStatus}',
              style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
            ),
          ),
      ],
    );
  }

  String _fmt(double v) {
    if (v == 0) return '-';
    return v >= 1000
        ? '${(v / 1000).toStringAsFixed(1)}k'
        : v.toStringAsFixed(2);
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final Color? textColor;
  final bool bold;
  final TextAlign align;

  const _DataCell(
    this.text, {
    this.textColor,
    this.bold = false,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          color: textColor ?? AppTheme.charcoal,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Justification Dialog (for Hard Block cases)
// ─────────────────────────────────────────────────────────────────────────────

class _JustificationDialog extends StatefulWidget {
  final double maxVariancePct;
  const _JustificationDialog({required this.maxVariancePct});

  @override
  State<_JustificationDialog> createState() => _JustificationDialogState();
}

class _JustificationDialogState extends State<_JustificationDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppTheme.crimson, size: 22),
          SizedBox(width: 8),
          Text('مطلوب مبرر كتابي', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'الفارق (${widget.maxVariancePct.toStringAsFixed(1)}%) يتجاوز الحد المسموح.\n'
                  'يجب تقديم مبرر واضح لإتمام المزامنة. سيُحفظ هذا المبرر في سجل التدقيق.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.crimson, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'المبرر الكتابي *',
                  hintText: 'أدخل سبب تجاوز الحد المسموح بالتفصيل...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 15) {
                    return 'المبرر يجب أن يكون 15 حرفًا على الأقل';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.crimson,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.lock_open, size: 18),
          label: const Text(
            'تأكيد مع المبرر',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
