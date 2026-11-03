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
import '../../../core/widgets/extraction_progress_dialog.dart';
import '../../customs_consultation/widgets/price_list_form_dialog.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import 'extractor/extracted_rate_normalizer.dart';
import 'extractor/extractor_gap_dialog.dart';
import 'extractor/extractor_result_panel.dart';
import 'quotation_sample_texts.dart';
import 'quotation_validation_banner.dart';

export 'extractor/extracted_rate_normalizer.dart' show normalizeExtractedRateData;

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
      targetRfqId: targetRfqId,
      onExtracted: onExtracted,
    ),
  );
}

class _SmartClearanceExtractorDialog extends StatefulWidget {
  const _SmartClearanceExtractorDialog({
    required this.hostContext,
    required this.hostRef,
    this.targetRfqId,
    this.onExtracted,
  });

  final BuildContext hostContext;
  final WidgetRef hostRef;
  final int? targetRfqId;
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
    if (!await ExtractorGapDialog.confirmGapIfRequired(context, l10n, _result)) return;
    if (!mounted) return;
    Navigator.pop(context);
    if (!widget.hostContext.mounted) return;
    _openPriceListForm();
  }

  Future<void> _applyQuote(AppLocalizations l10n) async {
    if (!await ExtractorGapDialog.confirmGapIfRequired(context, l10n, _result)) return;
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
                  ExtractorResultPanel(
                    result: result,
                    onSaveAsPriceList: () => _saveAsPriceList(l10n),
                    onApplyQuote: () => _applyQuote(l10n),
                    onSelectRateOption: (cType, optMap) {
                      setState(() {
                        result['container_type'] = cType;
                        result['clearance_fee'] = optMap['clearance_fee'];
                        result['inland_transport_fee'] = optMap['inland_transport_fee'];
                        result['inspection_fee'] = optMap['inspection_fee'];
                        result['port_expenses'] = optMap['port_expenses'];
                        result['total_estimated_clearance_cost'] = optMap['total_estimated_clearance_cost'] ?? 0;
                        result['notes'] = optMap['notes'];
                      });
                    },
                  ),
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
}
