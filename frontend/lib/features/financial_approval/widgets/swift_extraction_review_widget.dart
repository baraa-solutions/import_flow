import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import 'swift_extraction_review/swift_review_header_banner.dart';
import 'swift_extraction_review/swift_raw_source_panel.dart';
import 'swift_extraction_review/swift_field_review_table.dart';
import 'swift_extraction_review/swift_mandatory_blocking_bar.dart';

class SwiftExtractionReviewWidget extends ConsumerStatefulWidget {
  final SwiftBatchModel initialBatch;
  final void Function(SwiftBatchModel confirmedBatch) onBatchConfirmed;
  final VoidCallback onCancel;

  const SwiftExtractionReviewWidget({
    super.key,
    required this.initialBatch,
    required this.onBatchConfirmed,
    required this.onCancel,
  });

  @override
  ConsumerState<SwiftExtractionReviewWidget> createState() =>
      _SwiftExtractionReviewWidgetState();
}

class _SwiftExtractionReviewWidgetState
    extends ConsumerState<SwiftExtractionReviewWidget> {
  late SwiftBatchModel _batch;
  String? _highlightedFieldKey;
  String? _highlightSnippet;
  bool _isConfirming = false;
  String? _loadingFieldKey;
  final Map<String, TextEditingController> _controllers = {};
  String _filterMode = 'ALL'; // ALL, MANDATORY, EDITED, LOW_CONFIDENCE

  @override
  void initState() {
    super.initState();
    _batch = widget.initialBatch;
    _initControllers();
  }

  void _initControllers() {
    for (final field in _batch.fields) {
      final textVal = field.finalValue ?? field.parsedValue ?? '';
      if (_controllers.containsKey(field.fieldKey)) {
        if (_controllers[field.fieldKey]!.text != textVal) {
          _controllers[field.fieldKey]!.text = textVal;
        }
      } else {
        _controllers[field.fieldKey] = TextEditingController(text: textVal);
      }
    }
  }

  @override
  void didUpdateWidget(covariant SwiftExtractionReviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBatch.batchId != oldWidget.initialBatch.batchId) {
      _batch = widget.initialBatch;
      _initControllers();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveField(String fieldKey, String value) async {
    setState(() => _loadingFieldKey = fieldKey);
    try {
      final updatedBatch = await ref
          .read(paymentRequestsProvider.notifier)
          .updateSwiftBatchField(
            batchId: _batch.batchId,
            fieldKey: fieldKey,
            value: value,
          );
      if (mounted) {
        setState(() {
          _batch = updatedBatch;
          _initControllers();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faSwiftFieldUpdated,
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faSwiftFieldSaveFailed(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFieldKey = null);
    }
  }

  Future<void> _reExtractField(String fieldKey) async {
    setState(() => _loadingFieldKey = fieldKey);
    try {
      final updatedBatch = await ref
          .read(paymentRequestsProvider.notifier)
          .reExtractSwiftBatchField(
            batchId: _batch.batchId,
            fieldKey: fieldKey,
          );
      if (mounted) {
        setState(() {
          _batch = updatedBatch;
          _initControllers();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faSwiftFieldReExtracted,
            severity: AppSeverity.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faSwiftReExtractFailed(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFieldKey = null);
    }
  }

  Future<void> _confirmReview() async {
    if (!_batch.allMandatoryValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          'لا يمكن الاعتماد: الحقول الإلزامية غير مكتملة (${_batch.missingMandatoryFields.join("، ")})',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    setState(() => _isConfirming = true);
    try {
      final res = await ref
          .read(paymentRequestsProvider.notifier)
          .confirmSwiftBatchReview(batchId: _batch.batchId);

      if (res['success'] == true) {
        final confirmedBatch = SwiftBatchModel.fromJson(res['batch']);
        if (mounted) {
          setState(() => _batch = confirmedBatch);
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.faSwiftConfirmedOpened,
              severity: AppSeverity.success,
            ),
          );
          widget.onBatchConfirmed(confirmedBatch);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.faSwiftConfirmFailed(ApiError.message(e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  List<SwiftFieldModel> get _filteredFields {
    switch (_filterMode) {
      case 'MANDATORY':
        return _batch.fields.where((f) => f.isMandatory).toList();
      case 'EDITED':
        return _batch.fields.where((f) => f.isEditedByUser).toList();
      case 'LOW_CONFIDENCE':
        return _batch.fields.where((f) => f.confidenceScore < 0.8).toList();
      default:
        return _batch.fields;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed =
        _batch.status == 'REVIEWED_CONFIRMED' || _batch.status == 'RECONCILED';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfirmed ? AppTheme.emerald : AppTheme.cobalt,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwiftReviewHeaderBanner(batch: _batch, isConfirmed: isConfirmed),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterAndBatchInfoRow(isConfirmed),
                const SizedBox(height: 14),
                // Split View: Raw Source on left, Field Review Table on right
                SizedBox(
                  height: 480,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: SwiftRawSourcePanel(
                          rawSourceText: _batch.rawSourceText,
                          highlightedFieldKey: _highlightedFieldKey,
                          highlightSnippet: _highlightSnippet,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 7,
                        child: SwiftFieldReviewTable(
                          fields: _filteredFields,
                          controllers: _controllers,
                          highlightedFieldKey: _highlightedFieldKey,
                          loadingFieldKey: _loadingFieldKey,
                          isConfirmed: isConfirmed,
                          onSelectField: (f) {
                            setState(() {
                              _highlightedFieldKey = f.fieldKey;
                              _highlightSnippet = f.rawOcrText ?? f.finalValue;
                            });
                          },
                          onSaveField: _saveField,
                          onReExtractField: _reExtractField,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SwiftMandatoryBlockingBar(
                  batch: _batch,
                  isConfirmed: isConfirmed,
                  isConfirming: _isConfirming,
                  onCancel: widget.onCancel,
                  onConfirmReview: _confirmReview,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndBatchInfoRow(bool isConfirmed) {
    return Row(
      children: [
        Wrap(
          spacing: 6,
          children: [
            _buildFilterChip('ALL', 'كافة الحقول (${_batch.fields.length})'),
            _buildFilterChip('MANDATORY', context.l10n.faSwiftMandatoryOnly),
            _buildFilterChip(
              'EDITED',
              'المعدلة يدوياً (${_batch.fields.where((f) => f.isEditedByUser).length})',
            ),
            _buildFilterChip(
              'LOW_CONFIDENCE',
              'ثقة منخفضة (${_batch.fields.where((f) => f.confidenceScore < 0.8).length})',
            ),
          ],
        ),
        const Spacer(),
        if (_batch.sourceFilename != null) ...[
          const Icon(Icons.attachment, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            _batch.sourceFilename!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textStrong,
            ),
          ),
          const SizedBox(width: 12),
        ],
        AppButton(
          label: context.l10n.faSwiftCopyRaw,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          icon: Icons.copy,
          onPressed: () => CopyHelper.copy(context, _batch.rawSourceText),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String mode, String label) {
    final isSelected = _filterMode == mode;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.white : AppTheme.charcoal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor: AppTheme.charcoalSurface,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _filterMode = mode),
    );
  }
}
