import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
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
              ? [AppTheme.wcagEmerald, AppTheme.emerald]
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
            color: AppTheme.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.faSwiftReviewTitle,
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _batch.batchCode,
                        style: const TextStyle(
                          color: AppTheme.white,
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
                      ? context.l10n.faSwiftReviewApprovedBanner
                      : context.l10n.faSwiftHumanReviewRequired,
                  style: TextStyle(
                    color: AppTheme.white.withValues(alpha: 0.9),
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
                  ? AppTheme.wcagEmerald.withValues(alpha: 0.4)
                  : AppTheme.wcagOrange.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isConfirmed ? AppTheme.emeraldBorder : AppTheme.orange,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConfirmed ? Icons.check_circle : Icons.hourglass_top,
                  size: 13,
                  color: AppTheme.white,
                ),
                const SizedBox(width: 5),
                Text(
                  isConfirmed
                      ? context.l10n.faSwiftHumanApproved
                      : context.l10n.faSwiftPendingReview,
                  style: const TextStyle(
                    color: AppTheme.white,
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

  Widget _buildRawSourcePanel() {
    final text = _batch.rawSourceText;
    final snippet = _highlightSnippet?.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkScaffoldBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.textStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.darkInputBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, color: AppTheme.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  context.l10n.faSwiftRawSource,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_highlightedFieldKey != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.orange, width: 0.8),
                    ),
                    child: Text(
                      context.l10n
                          .faSwiftHighlightedField('$_highlightedFieldKey'),
                      style: const TextStyle(
                        color: AppTheme.orange,
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
          color: AppTheme.cloudWhite,
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
            color: AppTheme.cloudWhite,
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
            color: AppTheme.black,
            backgroundColor: AppTheme.orange,
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
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cloudWhite),
      ),
      child: Column(
        children: [
          // Table Column Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.charcoalSurface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text(context.l10n.faSwiftColField,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(
                    flex: 5,
                    child: Text(context.l10n.faSwiftColValue,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                SizedBox(
                    width: 80,
                    child: Text(context.l10n.faSwiftColConfidence,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 70,
                    child: Text(context.l10n.status,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 45,
                    child: Text(context.l10n.faSwiftColAction,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                        textAlign: TextAlign.center)),
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
                        ? AppTheme.orangeLight.withValues(alpha: 0.7)
                        : (index.isEven
                            ? AppTheme.white
                            : AppTheme.charcoalSurface.withValues(alpha: 0.5)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  if (f.swiftFieldCode != null &&
                                      f.swiftFieldCode!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      margin: const EdgeInsetsDirectional.only(
                                          start: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.cobalt.withValues(alpha: 0.12),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      margin: const EdgeInsetsDirectional.only(
                                          start: 4),
                                      decoration: BoxDecoration(
                                        color: f.isEmpty
                                            ? AppTheme.crimsonLight
                                            : AppTheme.emeraldLight,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        context.l10n.faSwiftMandatoryMark,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: f.isEmpty
                                              ? AppTheme.crimson
                                              : AppTheme.wcagEmerald,
                                        ),
                                      ),
                                    ),
                                  if (f.isEditedByUser)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.orangeLight,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        context.l10n.faSwiftManuallyEdited,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.wcagOrange,
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
                                      fontFamily: (f.fieldKey
                                                  .contains('amount') ||
                                              f.fieldKey.contains('date') ||
                                              f.fieldKey
                                                  .contains('reference') ||
                                              f.fieldKey.contains('swift') ||
                                              f.fieldKey.contains('iban'))
                                          ? 'monospace'
                                          : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: BorderSide(
                                          color: f.isEmpty && f.isMandatory
                                              ? AppTheme.crimson
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(
                                            color: AppTheme.cobalt, width: 1.5),
                                      ),
                                      suffixIcon: isLoading
                                          ? const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: AppLoadingState.inline(),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.check,
                                                  size: 14,
                                                  color: AppTheme.emerald),
                                              tooltip:
                                                  context.l10n.faSwiftSaveEdit,
                                              onPressed: () {
                                                final curText =
                                                    _controllers[f.fieldKey]
                                                            ?.text ??
                                                        '';
                                                _saveField(f.fieldKey, curText);
                                              },
                                            ),
                                    ),
                                    onFieldSubmitted: (v) =>
                                        _saveField(f.fieldKey, v),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy,
                                    size: 14, color: AppTheme.textMuted),
                                tooltip: context.l10n.faSwiftCopyValue,
                                onPressed: () {
                                  final val =
                                      _controllers[f.fieldKey]?.text ?? '';
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
                              final scoreVal = (f.confidenceScore > 1.0
                                      ? f.confidenceScore / 100.0
                                      : f.confidenceScore)
                                  .clamp(0.0, 1.0);
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
                                          ? AppTheme.wcagEmerald
                                          : (scoreVal >= 0.5
                                              ? AppTheme.wcagOrange
                                              : AppTheme.crimson),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: scoreVal,
                                      minHeight: 4,
                                      backgroundColor: AppTheme.cloudWhite,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        scoreVal >= 0.8
                                            ? AppTheme.emerald
                                            : (scoreVal >= 0.5
                                                ? AppTheme.orange
                                                : AppTheme.crimson),
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
                              icon: const Icon(Icons.refresh,
                                  size: 16, color: AppTheme.cobalt),
                              tooltip: context.l10n.faSwiftReExtractField,
                              onPressed: isLoading
                                  ? null
                                  : () => _reExtractField(f.fieldKey),
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
        message: context.l10n.faSwiftEmptyMandatoryBlocks,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
              color: AppTheme.crimsonLight,
              borderRadius: BorderRadius.circular(4)),
          child: Text(context.l10n.faSwiftStatusEmpty,
              style: const TextStyle(
                  fontSize: 9.5,
                  color: AppTheme.crimson,
                  fontWeight: FontWeight.bold)),
        ),
      );
    } else if (f.confidenceScore >= 0.8 && !f.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
            color: AppTheme.emeraldLight,
            borderRadius: BorderRadius.circular(4)),
        child: Text(context.l10n.faSwiftStatusTrusted,
            style: const TextStyle(
                fontSize: 9.5,
                color: AppTheme.emerald,
                fontWeight: FontWeight.bold)),
      );
    } else if (!f.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
            color: AppTheme.orangeLight,
            borderRadius: BorderRadius.circular(4)),
        child: Text(context.l10n.faSwiftStatusReviewed,
            style: const TextStyle(
                fontSize: 9.5,
                color: AppTheme.orange,
                fontWeight: FontWeight.bold)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
            color: AppTheme.cloudWhite, borderRadius: BorderRadius.circular(4)),
        child: Text(context.l10n.faSwiftOptional,
            style: const TextStyle(
                fontSize: 9.5,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600)),
      );
    }
  }

  Widget _buildMandatoryBlockingBar(bool isConfirmed) {
    final canConfirm = _batch.allMandatoryValid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canConfirm ? AppTheme.emeraldLight : AppTheme.crimsonLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canConfirm ? AppTheme.emerald : AppTheme.crimsonBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            canConfirm ? Icons.check_circle : Icons.warning_amber_rounded,
            color: canConfirm ? AppTheme.wcagEmerald : AppTheme.crimson,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canConfirm
                      ? context.l10n.faSwiftAllMandatoryOk
                      : context.l10n.faSwiftMatchingBlocked,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: canConfirm ? AppTheme.wcagEmerald : AppTheme.crimson,
                  ),
                ),
                if (!canConfirm) ...[
                  const SizedBox(height: 4),
                  Text(
                    _batch.missingMandatoryFields.join(' • '),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.crimson,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          AppButton(
            label: context.l10n.faSwiftCancelReview,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: widget.onCancel,
          ),
          const SizedBox(width: 10),
          AppButton(
            label: isConfirmed
                ? context.l10n.faSwiftApprovedGoMatch
                : context.l10n.faSwiftConfirmAndMatch,
            variant: AppButtonVariant.primary,
            icon: isConfirmed ? Icons.check_circle : Icons.verified,
            isLoading: _isConfirming,
            onPressed: (!canConfirm || _isConfirming) ? null : _confirmReview,
          ),
        ],
      ),
    );
  }
}
