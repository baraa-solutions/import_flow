import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/extraction_progress_dialog.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_consultation/widgets/price_list_form_dialog.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import 'quotation_sample_texts.dart';
import 'quotation_validation_banner.dart';

/// Fills missing top-level rate fields from the preferred (40HQ) rate option.
void normalizeExtractedRateData(Map<String, dynamic> extracted) {
  if (extracted['rate_options'] is List && (extracted['rate_options'] as List).isNotEmpty) {
    final opts = extracted['rate_options'] as List;
    final primaryOpt = opts.firstWhere(
      (o) => (o as Map)['container_type'] == '40HQ',
      orElse: () => opts.first,
    ) as Map<String, dynamic>;

    final currentTotal = (extracted['total_estimated_clearance_cost'] as num?)?.toDouble() ?? 0.0;
    final currentType = extracted['container_type'] as String?;

    if (currentType == null || currentType.isEmpty || currentTotal < 2000.0) {
      extracted['container_type'] = primaryOpt['container_type'];
      extracted['clearance_fee'] = primaryOpt['clearance_fee'];
      extracted['inland_transport_fee'] = primaryOpt['inland_transport_fee'];
      extracted['inspection_fee'] = primaryOpt['inspection_fee'];
      extracted['port_expenses'] = primaryOpt['port_expenses'];
      extracted['total_estimated_clearance_cost'] = primaryOpt['total_estimated_clearance_cost'];
      if (primaryOpt['notes'] != null) {
        extracted['notes'] = primaryOpt['notes'];
      }
    }
  }
}

/// Shows the unified Smart AI Clearance Quotation & Estimate Extractor dialog
/// from any screen / tab.
Future<void> showSmartClearanceExtractorDialog(
  BuildContext context,
  WidgetRef ref, {
  int? targetRfqId,
  Function(Map<String, dynamic> extracted)? onExtracted,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => _SmartClearanceExtractorDialog(
      hostContext: context,
      hostRef: ref,
      onExtracted: onExtracted,
    ),
  );
}

class _SmartClearanceExtractorDialog extends StatefulWidget {
  const _SmartClearanceExtractorDialog({
    required this.hostContext,
    required this.hostRef,
    this.onExtracted,
  });

  final BuildContext hostContext;
  final WidgetRef hostRef;
  final Function(Map<String, dynamic> extracted)? onExtracted;

  @override
  State<_SmartClearanceExtractorDialog> createState() => _SmartClearanceExtractorDialogState();
}

class _SmartClearanceExtractorDialogState extends State<_SmartClearanceExtractorDialog> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _isExtracting = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _showError(AppLocalizations l10n, Object e) {
    final host = widget.hostContext;
    if (!host.mounted) return;
    ScaffoldMessenger.of(host).showSnackBar(
      AppTheme.snackBar(host, '${l10n.errorPrefix}: ${ApiErrorText.of(l10n, e)}', severity: AppSeverity.danger),
    );
  }

  Future<void> _extractFromText(AppLocalizations l10n) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isExtracting = true);
    try {
      final dio = widget.hostRef.read(uploadDioProvider);
      final formData = FormData.fromMap({'raw_text': text});
      final resp = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/parse-text/clearance-quotation',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final fields = resp.data['extracted_fields'] as Map<String, dynamic>?;
        if (fields != null) normalizeExtractedRateData(fields);
        if (mounted) setState(() => _result = fields);
      }
    } catch (e) {
      _showError(l10n, e);
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _uploadDocument(AppLocalizations l10n) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'xls', 'docx', 'doc', 'png', 'jpg', 'jpeg', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;

    final progressCtrl = ExtractionProgressController();
    progressCtrl.update(
      percent: 0.15,
      status: l10n.clearanceQuotesOcrUploadingState,
      stepLabel: l10n.clearanceQuotesOcrStep1,
      currentStep: 1,
    );

    final host = widget.hostContext;
    if (host.mounted) {
      ExtractionProgressDialog.show(
        context: host,
        title: l10n.clearanceQuotesOcrDialogTitle,
        fileName: file.name,
        controller: progressCtrl,
      );
    }

    if (mounted) setState(() => _isExtracting = true);
    try {
      final dio = widget.hostRef.read(uploadDioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        'module_name': 'clearance-quotation',
      });
      final resp = await dio.post(
        '${ApiConstants.baseUrl}/smart-upload/upload',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 120)),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final ratio = sent / total;
            progressCtrl.update(
              percent: 0.15 + (ratio * 0.35),
              status: l10n.clearanceQuotesOcrProgressState((ratio * 100).round()),
              stepLabel: l10n.clearanceQuotesOcrStep2,
              currentStep: 2,
            );
            if (ratio >= 0.99) {
              progressCtrl.startAutoAdvance(
                targetPercent: 0.92,
                duration: const Duration(seconds: 5),
                step4Status: l10n.clearanceQuotesOcrStep4State,
              );
            }
          }
        },
      );

      progressCtrl.complete();
      await Future.delayed(const Duration(milliseconds: 300));
      if (host.mounted) Navigator.of(host, rootNavigator: true).pop();

      if (resp.statusCode == 200 && resp.data != null) {
        final fields = resp.data['extracted_fields'] as Map<String, dynamic>?;
        if (fields != null) normalizeExtractedRateData(fields);
        if (mounted) setState(() => _result = fields);
      }
    } catch (e) {
      if (host.mounted) Navigator.of(host, rootNavigator: true).pop();
      _showError(l10n, e);
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  /// When the backend flags a large gap it asks for an explicit confirmation.
  Future<bool> _confirmGapIfRequired(AppLocalizations l10n) async {
    final valReport = _result?['validation_report'] as Map<String, dynamic>?;
    if (valReport?['requires_modal_confirmation'] != true) return true;
    final expCount = valReport?['expected_item_count'] ?? valReport?['expected_count'] ?? 0;
    final extCount = valReport?['extracted_item_count'] ?? valReport?['extracted_count'] ?? 0;
    final gap = (valReport?['gap_percentage'] as num?)?.toDouble() ?? 0.0;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (modalCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.quotationValidationConfirmTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.crimson),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.quotationValidationConfirmMessage(expCount, extCount, gap.toStringAsFixed(1)),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          AppButton(
            label: l10n.quotationValidationReviewBtn,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(modalCtx, false),
          ),
          AppButton(
            label: l10n.quotationValidationProceedBtn,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(modalCtx, true),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  void _openPriceListForm() {
    final host = widget.hostContext;
    final partners = widget.hostRef.read(partnersProvider).value ?? [];
    final brokersList = partners
        .where((p) =>
            p.partnerType == 'Customs Broker' ||
            p.partnerType == 'مستخلص جمركي' ||
            p.partnerType == 'Customs Clearance')
        .toList();
    showPriceListFormDialog(
      host,
      widget.hostRef,
      brokersList: brokersList.isNotEmpty ? brokersList : partners,
      initialExtractedData: _result,
    );
  }

  Future<void> _saveAsPriceList(AppLocalizations l10n) async {
    if (!await _confirmGapIfRequired(l10n)) return;
    if (!mounted) return;
    Navigator.pop(context);
    if (!widget.hostContext.mounted) return;
    _openPriceListForm();
  }

  Future<void> _applyQuote(AppLocalizations l10n) async {
    if (!await _confirmGapIfRequired(l10n)) return;
    if (!mounted) return;
    final result = _result!;
    Navigator.pop(context);
    if (!widget.hostContext.mounted) return;
    if (widget.onExtracted != null) {
      widget.onExtracted!(result);
    } else {
      _openPriceListForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.emerald),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.clearanceQuotesSmartExtractorDialogTitle)),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 48).clamp(320.0, 820.0),
          height: 660,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.clearanceQuotesSmartExtractorPrompt,
                    style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.clearanceQuotesSmartExtractorInputHint,
                      filled: true,
                      fillColor: AppTheme.surfaceAltOf(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppButton(
                      label: l10n.clearanceQuotesPasteClipboardBtn,
                      icon: Icons.paste_rounded,
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small,
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null && data!.text!.isNotEmpty) {
                          _textCtrl.text = data.text!;
                          if (mounted) setState(() {});
                        }
                      },
                    ),
                    AppButton(
                      label: l10n.clearanceQuotesSampleAccBtn,
                      icon: Icons.bolt_rounded,
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small,
                      onPressed: () => setState(() => _textCtrl.text = kAccClearanceQuoteText),
                    ),
                    AppButton(
                      label: l10n.clearanceQuotesSampleStandardBtn,
                      icon: Icons.description_outlined,
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small,
                      onPressed: () => setState(() => _textCtrl.text = kSampleClearanceQuoteText),
                    ),
                    if (_textCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        tooltip: l10n.clearanceQuotesClearInputTooltip,
                        onPressed: () => setState(() => _textCtrl.clear()),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    AppButton(
                      label: _isExtracting
                          ? l10n.clearanceQuotesExtractingState
                          : l10n.clearanceQuotesExtractFromTextBtn,
                      icon: Icons.bolt_rounded,
                      variant: AppButtonVariant.success,
                      isLoading: _isExtracting,
                      onPressed: _isExtracting ? null : () => _extractFromText(l10n),
                    ),
                    AppButton(
                      label: l10n.clearanceQuotesUploadDocBtn,
                      icon: Icons.upload_file_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _isExtracting ? null : () => _uploadDocument(l10n),
                    ),
                  ],
                ),
                if (result != null) ...[
                  const SizedBox(height: 14),
                  QuotationValidationBanner(
                    valReport: result['validation_report'] as Map<String, dynamic>?,
                    expensesCatalog: result['expenses_catalog'] as List<dynamic>?,
                  ),
                  _resultPanel(context, l10n, result),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.close,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _resultPanel(BuildContext context, AppLocalizations l10n, Map<String, dynamic> result) {
    final egp = l10n.egpCurrency;
    final hasOptions = result['rate_options'] is List && (result['rate_options'] as List).isNotEmpty;
    final hasCatalog = result['expenses_catalog'] is List && (result['expenses_catalog'] as List).isNotEmpty;

    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.emerald),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.clearanceQuotesExtractedBrokerPrefix} ${result['broker_name'] ?? l10n.clearanceQuotesColBroker}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${l10n.clearanceQuotesExtractedPortPrefix} ${result['port_name'] ?? '-'} | ${l10n.clearanceQuotesSelectedContainerLabel}: ${result['container_type'] ?? '-'}',
                  ),
                  LtrText(
                    '${l10n.clearanceQuotesExtractedTotalPrefix} ${result['total_estimated_clearance_cost']} $egp',
                    style: const TextStyle(
                        color: AppTheme.successForeground, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                    tooltip: l10n.copy,
                    onPressed: () {
                      final summary =
                          '${result['broker_name'] ?? l10n.clearanceQuotesColBroker} - ${result['port_name'] ?? '-'} - ${result['total_estimated_clearance_cost']} $egp';
                      CopyHelper.copy(context, summary);
                    },
                  ),
                  AppButton(
                    label: l10n.clearanceQuotesSaveAsPriceListBtn,
                    icon: Icons.price_change_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => _saveAsPriceList(l10n),
                  ),
                  AppButton(
                    label: l10n.clearanceQuotesApplyExtractedQuoteBtn,
                    icon: Icons.check,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: () => _applyQuote(l10n),
                  ),
                ],
              ),
            ],
          ),
          if (hasOptions) ...[
            Divider(height: 16, color: AppTheme.borderOf(context)),
            Text(l10n.clearanceQuotesRateOptionsTitle,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: (result['rate_options'] as List).map<Widget>((opt) {
                final optMap = opt as Map<String, dynamic>;
                final cType = optMap['container_type']?.toString() ?? 'Option';
                final optTotal = optMap['total_estimated_clearance_cost'] ?? 0;
                final isSelected = result['container_type'] == cType;
                return ChoiceChip(
                  avatar: Icon(
                    isSelected ? Icons.check_circle : Icons.inventory_2_outlined,
                    size: 14,
                    color: isSelected ? AppTheme.white : AppTheme.cobalt,
                  ),
                  label: Text(
                    '$cType : $optTotal $egp',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.white : AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.cobalt,
                  backgroundColor: AppTheme.surfaceOf(context),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        result['container_type'] = cType;
                        result['clearance_fee'] = optMap['clearance_fee'];
                        result['inland_transport_fee'] = optMap['inland_transport_fee'];
                        result['inspection_fee'] = optMap['inspection_fee'];
                        result['port_expenses'] = optMap['port_expenses'];
                        result['total_estimated_clearance_cost'] = optTotal;
                        result['notes'] = optMap['notes'];
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsetsDirectional.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 16,
              runSpacing: 8,
              children: [
                _FeeColumn(l10n.clearanceQuotesBreakdownClearanceFee, '${result['clearance_fee'] ?? 0} $egp'),
                _FeeColumn(l10n.clearanceQuotesBreakdownInlandFee, '${result['inland_transport_fee'] ?? 0} $egp'),
                _FeeColumn(l10n.clearanceQuotesBreakdownInspectionFee, '${result['inspection_fee'] ?? 0} $egp'),
                _FeeColumn(l10n.clearanceQuotesBreakdownPortExpenses, '${result['port_expenses'] ?? 0} $egp'),
                _FeeColumn(l10n.clearanceQuotesBreakdownEstimatedTotal,
                    '${result['total_estimated_clearance_cost'] ?? 0} $egp',
                    isTotal: true),
              ],
            ),
          ),
          if (hasCatalog) ...[
            const SizedBox(height: 8),
            _ExpensesCatalog(items: result['expenses_catalog'] as List, egp: egp),
          ],
        ],
      ),
    );
  }
}

class _FeeColumn extends StatelessWidget {
  const _FeeColumn(this.label, this.value, {this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
        const SizedBox(height: 2),
        LtrText(
          value,
          style: TextStyle(
            fontSize: isTotal ? 12.5 : 11.5,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppTheme.successForeground : AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _ExpensesCatalog extends StatelessWidget {
  const _ExpensesCatalog({required this.items, required this.egp});

  final List items;
  final String egp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.receipt_long, size: 18, color: AppTheme.cobalt),
        title: Text(
          l10n.clearanceQuotesExpensesCatalogCount(items.length),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
        ),
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderOf(context)),
              itemBuilder: (ctx, i) => _row(ctx, l10n, items[i] as Map<String, dynamic>),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String text, AppSeverity severity, String tooltip, {IconData? icon}) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: AppTheme.severityBackgroundOf(context, severity),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: fg, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: fg),
              const SizedBox(width: 1),
            ],
            Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, Map<String, dynamic> itm) {
    final isMulti = itm['is_multi_value_split'] == true;
    final isRange = itm['price_type'] == 'range';
    final isOutside = itm['source_location'] == 'outside_table';

    Color itemBg = Colors.transparent;
    if (isMulti) {
      itemBg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
    } else if (isRange) {
      itemBg = AppTheme.severityBackgroundOf(context, AppSeverity.info);
    }

    final priceStr = isRange
        ? '${itm['price_min'] ?? 0} - ${itm['price_max'] ?? 0} $egp'
        : '${itm['price']} $egp';

    return Container(
      color: itemBg,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    itm['item_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (isMulti)
                  _tag(context, l10n.quotationValidationMultiValueBadge, AppSeverity.warning,
                      l10n.quotationValidationMultiValueTooltip),
                if (isRange)
                  _tag(context, l10n.quotationValidationRangeBadge, AppSeverity.info,
                      l10n.quotationValidationRangeTooltip(itm['price_min'] ?? '', itm['price_max'] ?? ''),
                      icon: Icons.bolt),
                if (isOutside)
                  _tag(context, l10n.quotationValidationOutsideTableBadge, AppSeverity.info,
                      l10n.quotationValidationOutsideTableTooltip),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              itm['category']?.toString() ?? '',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
            ),
          ),
          LtrText(
            priceStr,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isRange ? AppTheme.infoForeground : AppTheme.successForeground,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            itm['pricing_unit']?.toString() ?? '',
            style: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
          ),
        ],
      ),
    );
  }
}
