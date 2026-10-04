import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';

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
          const SnackBar(
            content: Text('تم تحديث الحقل بنجاح وتسجيله في سجل التدقيق'),
            backgroundColor: AppTheme.emerald,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ الحقل: $e'),
            backgroundColor: AppTheme.crimson,
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
          const SnackBar(
            content: Text('تمت إعادة استخلاص الحقل من النص الأصلي بنجاح'),
            backgroundColor: AppTheme.cobalt,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إعادة الاستخلاص: $e'),
            backgroundColor: AppTheme.crimson,
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
        SnackBar(
          content: Text(
            'لا يمكن الاعتماد: الحقول الإلزامية غير مكتملة (${_batch.missingMandatoryFields.join("، ")})',
          ),
          backgroundColor: AppTheme.crimson,
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
            const SnackBar(
              content: Text('✅ تم تأكيد صحة بيانات السويفت بنجاح وفتح المطابقة المالية!'),
              backgroundColor: AppTheme.emerald,
            ),
          );
          widget.onBatchConfirmed(confirmedBatch);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تأكيد المراجعة: $e'),
            backgroundColor: AppTheme.crimson,
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
    final isConfirmed = _batch.status == 'REVIEWED_CONFIRMED' || _batch.status == 'RECONCILED';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfirmed ? AppTheme.emerald : AppTheme.cobalt,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBanner(isConfirmed),
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
                      // Raw Source Monospace Viewer with Interactive Highlighting
                      Expanded(
                        flex: 5,
                        child: _buildRawSourcePanel(),
                      ),
                      const SizedBox(width: 16),
                      // Editable Field Review Table
                      Expanded(
                        flex: 7,
                        child: _buildFieldReviewTable(isConfirmed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildMandatoryBlockingBar(isConfirmed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(bool isConfirmed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConfirmed
              ? [const Color(0xFF1B5E20), AppTheme.emerald]
              : [AppTheme.charcoal, AppTheme.cobalt],
          begin: AlignmentDirectional.centerEnd,
          end: AlignmentDirectional.centerStart,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Icon(
            isConfirmed ? Icons.verified_user : Icons.fact_check,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'شاشة مراجعة وتدقيق نتائج استخلاص SWIFT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _batch.batchCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isConfirmed
                      ? 'تم اعتماد وتدقيق البيانات المستخرجة بنجاح - مصفوفة المطابقة المالية مفتوحة'
                      : 'تدقيق بشري إلزامي: لا تنتقل أي قيمة إلى مرحلة المطابقة دون تأكيد المستخدم الصريح',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isConfirmed
                  ? Colors.green.shade900.withOpacity(0.4)
                  : Colors.amber.shade900.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isConfirmed ? Colors.green.shade300 : Colors.amber.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConfirmed ? Icons.check_circle : Icons.hourglass_top,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  isConfirmed ? 'معتمد بشرياً' : 'بانتظار المراجعة والاعتماد',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
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
        // Filter Chips
        Wrap(
          spacing: 6,
          children: [
            _buildFilterChip('ALL', 'كافة الحقول (${_batch.fields.length})'),
            _buildFilterChip('MANDATORY', 'الإلزامية فقط (5)'),
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
          Icon(Icons.attachment, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            _batch.sourceFilename!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: Colors.grey.shade300),
          ),
          icon: const Icon(Icons.copy, size: 13),
          label: const Text('نسخ المصدر الخام', style: TextStyle(fontSize: 11)),
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
          color: isSelected ? Colors.white : AppTheme.charcoal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.cobalt,
      backgroundColor: Colors.grey.shade100,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _filterMode = mode),
    );
  }

  Widget _buildRawSourcePanel() {
    final text = _batch.rawSourceText;
    final snippet = _highlightSnippet?.trim();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'المصدر الخام للسويفت (Raw Source OCR)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_highlightedFieldKey != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber, width: 0.8),
                    ),
                    child: Text(
                      'تظليل الحقل: $_highlightedFieldKey',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _buildHighlightedRawText(text, snippet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedRawText(String fullText, String? snippet) {
    if (snippet == null || snippet.isEmpty || !fullText.contains(snippet)) {
      return SelectableText(
        fullText,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          color: Color(0xFFE0E0E0),
          height: 1.45,
        ),
      );
    }

    // Build highlighted text spans
    final spans = <TextSpan>[];
    final parts = fullText.split(snippet);
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            color: Color(0xFFE0E0E0),
            height: 1.45,
          ),
        ));
      }
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: snippet,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            backgroundColor: Colors.amber,
            height: 1.45,
          ),
        ));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _buildFieldReviewTable(bool isConfirmed) {
    final fields = _filteredFields;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Table Column Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('الحقل والرمز البنكي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 5, child: Text('القيمة المستخرجة / التدقيق اليدوي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                SizedBox(width: 80, child: Text('نسبة الثقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                SizedBox(width: 70, child: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                SizedBox(width: 45, child: Text('إجراء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable List of Fields
          Expanded(
            child: ListView.separated(
              itemCount: fields.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final f = fields[index];
                final isSelected = _highlightedFieldKey == f.fieldKey;
                final isLoading = _loadingFieldKey == f.fieldKey;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _highlightedFieldKey = f.fieldKey;
                      _highlightSnippet = f.rawOcrText ?? f.finalValue;
                    });
                  },
                  child: Container(
                    color: isSelected
                        ? Colors.amber.shade50.withOpacity(0.7)
                        : (index.isEven ? Colors.white : Colors.grey.shade50.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        // Column 1: Field Name & Code
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (f.swiftFieldCode != null && f.swiftFieldCode!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      margin: const EdgeInsetsDirectional.only(start: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        f.swiftFieldCode!,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.cobalt,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      f.fieldLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (f.isMandatory)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      margin: const EdgeInsetsDirectional.only(start: 4),
                                      decoration: BoxDecoration(
                                        color: f.isEmpty ? Colors.red.shade100 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        '* إلزامي',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: f.isEmpty ? Colors.red.shade800 : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  if (f.isEditedByUser)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        'معدل يدويًا',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Column 2: Editable Value Field
                        Expanded(
                          flex: 5,
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 34,
                                  child: TextFormField(
                                    controller: _controllers[f.fieldKey],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: (f.fieldKey.contains('amount') ||
                                              f.fieldKey.contains('date') ||
                                              f.fieldKey.contains('reference') ||
                                              f.fieldKey.contains('swift') ||
                                              f.fieldKey.contains('iban'))
                                          ? 'monospace'
                                          : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: f.isEmpty && f.isMandatory
                                              ? Colors.red
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
                                      ),
                                      suffixIcon: isLoading
                                          ? const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.check, size: 14, color: AppTheme.emerald),
                                              tooltip: 'حفظ التعديل',
                                              onPressed: () {
                                                final curText = _controllers[f.fieldKey]?.text ?? '';
                                                _saveField(f.fieldKey, curText);
                                              },
                                            ),
                                    ),
                                    onFieldSubmitted: (v) => _saveField(f.fieldKey, v),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                                tooltip: 'نسخ القيمة',
                                onPressed: () {
                                  final val = _controllers[f.fieldKey]?.text ?? '';
                                  CopyHelper.copy(context, val);
                                },
                              ),
                            ],
                          ),
                        ),

                        // Column 3: Confidence Score Progress
                        SizedBox(
                          width: 80,
                          child: Builder(
                            builder: (context) {
                              final scoreVal = (f.confidenceScore > 1.0 ? f.confidenceScore / 100.0 : f.confidenceScore).clamp(0.0, 1.0);
                              final pct = (scoreVal * 100).round();
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$pct%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: scoreVal >= 0.8
                                          ? Colors.green.shade800
                                          : (scoreVal >= 0.5
                                              ? Colors.orange.shade800
                                              : Colors.red.shade800),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: scoreVal,
                                      minHeight: 4,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        scoreVal >= 0.8
                                            ? Colors.green
                                            : (scoreVal >= 0.5 ? Colors.orange : Colors.red),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        // Column 4: Status Icon & Badge
                        SizedBox(
                          width: 70,
                          child: Center(
                            child: _buildFieldStatusBadge(f),
                          ),
                        ),

                        // Column 5: Re-extract single field
                        SizedBox(
                          width: 45,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.refresh, size: 16, color: AppTheme.cobalt),
                              tooltip: 'إعادة استخلاص الحقل من الأصل',
                              onPressed: isLoading ? null : () => _reExtractField(f.fieldKey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldStatusBadge(SwiftFieldModel f) {
    if (f.isMandatory && f.isEmpty) {
      return Tooltip(
        message: 'حقل إلزامي فارغ - يمنع التأكيد',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
          child: const Text('❌ فارغ', style: TextStyle(fontSize: 9.5, color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      );
    } else if (f.confidenceScore >= 0.8 && !f.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
        child: const Text('✅ موثوق', style: TextStyle(fontSize: 9.5, color: Colors.green, fontWeight: FontWeight.bold)),
      );
    } else if (!f.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
        child: const Text('⚠️ مدقق', style: TextStyle(fontSize: 9.5, color: Colors.orange, fontWeight: FontWeight.bold)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
        child: const Text('اختياري', style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w600)),
      );
    }
  }

  Widget _buildMandatoryBlockingBar(bool isConfirmed) {
    final canConfirm = _batch.allMandatoryValid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canConfirm ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canConfirm ? Colors.green.shade400 : Colors.red.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            canConfirm ? Icons.check_circle : Icons.warning_amber_rounded,
            color: canConfirm ? Colors.green.shade800 : Colors.red.shade800,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canConfirm
                      ? 'جميع الحقول الإلزامية الخمسة مكتملة ومحققة لقواعد التحقق المالي.'
                      : 'حظر المطابقة: الحقول الإلزامية التالية غير مكتملة أو فارغة، يُرجى تصحيحها أولاً:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: canConfirm ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
                if (!canConfirm) ...[
                  const SizedBox(height: 4),
                  Text(
                    _batch.missingMandatoryFields.join(' • '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: widget.onCancel,
            child: const Text('إلغاء المراجعة', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: canConfirm ? AppTheme.emerald : Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isConfirming
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(
                    isConfirmed ? Icons.check_circle : Icons.verified,
                    color: Colors.white,
                    size: 18,
                  ),
            label: Text(
              isConfirmed
                  ? 'تم الاعتماد • الانتقال إلى المطابقة'
                  : '✅ تأكيد صحة البيانات والانتقال إلى المطابقة',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            onPressed: (!canConfirm || _isConfirming) ? null : _confirmReview,
          ),
        ],
      ),
    );
  }
}