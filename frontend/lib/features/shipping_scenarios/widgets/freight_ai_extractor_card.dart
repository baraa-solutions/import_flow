import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../freight_quotations/widgets/freight_quotations_extractor_dialog.dart';

/// بطاقة استخلاص عروض الشحن بالذكاء الاصطناعي ومعالجة الملفات (SWIFT MT103 Style)
class FreightAiExtractorCard extends StatefulWidget {
  final void Function(List<ExtractedQuotationOption> options) onAddQuotations;
  final void Function(ExtractedQuotationOption option)? onAddSingleQuotation;
  final void Function(List<ExtractedQuotationOption> options)? onAddAllQuotations;
  final List<ExtractedQuotationOption>? initialExtractedOptions;
  final Map<String, dynamic>? initialExtractedMetadata;
  final PlatformFile? initialPickedFile;

  const FreightAiExtractorCard({
    super.key,
    required this.onAddQuotations,
    this.onAddSingleQuotation,
    this.onAddAllQuotations,
    this.initialExtractedOptions,
    this.initialExtractedMetadata,
    this.initialPickedFile,
  });

  @override
  State<FreightAiExtractorCard> createState() => _FreightAiExtractorCardState();
}

class _FreightAiExtractorCardState extends State<FreightAiExtractorCard> {
  bool _isFreightExtractorExpanded = true;
  final bool _isFreightExtracting = false;
  final TextEditingController _rawFreightQuoteController = TextEditingController();
  List<ExtractedQuotationOption> _extractedOptions = [];
  Map<String, dynamic>? _extractedFreightMetadata;
  PlatformFile? _pickedFreightFile;
  String? _extractorError;

  static const String _sampleFreightQuoteText = '''
Dear Ahmed,
Please find below our best rates for your shipment:

Route: Shanghai – Alexandria
Local charges: Approx. USD 880/40HQ
Ocean freight:
• WHL: USD 6,700/40HQ  ETD: 28/AUG
  Transit time: 29 days, DIRECT
  Free time: 21 days FT

• YML: USD 6,180/40HQ  ETD: 27/AUG
  Transit time: 48 days, INDIRECT
  Free time: 21 days FT

• MSC: USD 6,950/40HQ  ETD: 30/AUG
  Transit time: 27 days, DIRECT
  Free time: 14 days FT (INCL OWS)

Cancellation fee: \$100/cntr
Best regards,
''';

  @override
  void initState() {
    super.initState();
    if (widget.initialExtractedOptions != null) {
      _extractedOptions = List.from(widget.initialExtractedOptions!);
    }
    _extractedFreightMetadata = widget.initialExtractedMetadata;
    _pickedFreightFile = widget.initialPickedFile;
  }

  @override
  void didUpdateWidget(FreightAiExtractorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialExtractedOptions != null &&
        widget.initialExtractedOptions != oldWidget.initialExtractedOptions) {
      setState(() {
        _extractedOptions = List.from(widget.initialExtractedOptions!);
      });
    }
    if (widget.initialExtractedMetadata != oldWidget.initialExtractedMetadata) {
      setState(() {
        _extractedFreightMetadata = widget.initialExtractedMetadata;
      });
    }
    if (widget.initialPickedFile != oldWidget.initialPickedFile) {
      setState(() {
        _pickedFreightFile = widget.initialPickedFile;
      });
    }
  }

  @override
  void dispose() {
    _rawFreightQuoteController.dispose();
    super.dispose();
  }

  void _loadSampleFreightQuote() {
    setState(() {
      _rawFreightQuoteController.text = _sampleFreightQuoteText.trim();
      _extractorError = null;
    });
  }

  void _openFreightSmartExtractorDialog([String? initialText]) {
    FreightQuotationsExtractorDialog.show(
      context,
      onAddQuotations: (selectedOptions) {
        widget.onAddQuotations(selectedOptions);
      },
    );
  }

  Future<void> _extractFreightFromText() async {
    _openFreightSmartExtractorDialog(_rawFreightQuoteController.text.trim());
  }

  Future<void> _extractFreightFromFile() async {
    _openFreightSmartExtractorDialog();
  }

  void _handleAddAll() {
    if (widget.onAddAllQuotations != null) {
      widget.onAddAllQuotations!(_extractedOptions);
    } else {
      widget.onAddQuotations(_extractedOptions);
    }
    setState(() {
      _extractedOptions.clear();
    });
  }

  void _handleAddSingle(ExtractedQuotationOption opt) {
    if (widget.onAddSingleQuotation != null) {
      widget.onAddSingleQuotation!(opt);
    } else {
      widget.onAddQuotations([opt]);
    }
    setState(() {
      _extractedOptions.removeWhere((o) => o.optionId == opt.optionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.charcoal),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Cobalt Gradient & Icons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.cobalt, AppTheme.wcagCobalt],
                begin: AlignmentDirectional.centerEnd,
                end: AlignmentDirectional.centerStart,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.orange, size: 20),
                      const SizedBox(width: 6),
                      const Icon(Icons.bolt, color: AppTheme.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.freightExtractorTitle,
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isFreightExtractorExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.white,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _isFreightExtractorExpanded ? l.collapseExtractor : l.expandExtractor,
                  onPressed: () => setState(() => _isFreightExtractorExpanded = !_isFreightExtractorExpanded),
                ),
              ],
            ),
          ),

          // Collapsible Body
          if (_isFreightExtractorExpanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;

                      final hintText = isArabic
                          ? 'ألصق نص رسالة أو إيميل عرض السعر من الخط الملاحي أو شركة الشحن...\n(مثال: Route: Shanghai - Alexandria | WHL: USD 6700/40HQ | Transit: 29 days, DIRECT | Free time: 21 days FT)'
                          : 'Paste freight quote email or message text from shipping line or forwarder...\n(Example: Route: Shanghai - Alexandria | WHL: USD 6700/40HQ | Transit: 29 days, DIRECT | Free time: 21 days FT)';

                      // Text Area with bottom Action Overlay
                      final textArea = Stack(
                        children: [
                          TextField(
                            controller: _rawFreightQuoteController,
                            maxLines: 5,
                            minLines: 4,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                            decoration: InputDecoration(
                              hintText: hintText,
                              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 40),
                            ),
                          ),
                          PositionedDirectional(
                            start: 8,
                            bottom: 8,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () async {
                                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                                    if (d != null && d.text != null && d.text!.isNotEmpty) {
                                      _rawFreightQuoteController.text = d.text!;
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cloudWhite,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.paste, size: 12, color: AppTheme.charcoal),
                                        const SizedBox(width: 4),
                                        Text(l.pasteQuoteText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    _rawFreightQuoteController.clear();
                                    setState(() {
                                      _extractedOptions = [];
                                      _extractedFreightMetadata = null;
                                      _extractorError = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoalSurface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.clear, size: 12, color: AppTheme.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(l.clearField, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _loadSampleFreightQuote,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.orangeLight,
                                      border: Border.all(color: AppTheme.orange),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lightbulb_outline, size: 12, color: AppTheme.orange),
                                        const SizedBox(width: 4),
                                        Text(l.sampleQuoteBtn, style: const TextStyle(fontSize: 11, color: AppTheme.wcagOrange, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      // Action Buttons
                      final actionButtons = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton(
                            label: l.uploadQuoteDocument,
                            icon: Icons.upload_file,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: _isFreightExtracting ? null : _extractFreightFromFile,
                          ),
                          const SizedBox(height: 8),
                          AppButton(
                            label: l.extractQuotesBtn,
                            icon: Icons.bolt,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            isLoading: _isFreightExtracting,
                            onPressed: _isFreightExtracting ? null : _extractFreightFromText,
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            textArea,
                            const SizedBox(height: 10),
                            actionButtons,
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: textArea),
                            const SizedBox(width: 14),
                            SizedBox(width: 220, child: actionButtons),
                          ],
                        );
                      }
                    },
                  ),

                  // Error Banner
                  if (_extractorError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.crimsonLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.crimsonBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.crimson, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_extractorError!, style: const TextStyle(color: AppTheme.crimson, fontSize: 11))),
                        ],
                      ),
                    ),
                  ],

                  // Extracted Options Live Results Card
                  if (_extractedOptions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.emeraldBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.extractedQuotesBanner(_extractedOptions.length),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                ),
                              ),
                              AppButton(
                                label: l.addAllQuotes(_extractedOptions.length),
                                icon: Icons.add_task,
                                variant: AppButtonVariant.success,
                                size: AppButtonSize.small,
                                onPressed: _handleAddAll,
                              ),
                            ],
                          ),
                          if (_pickedFreightFile != null || _extractedFreightMetadata != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (_pickedFreightFile != null)
                                  Chip(
                                    avatar: const Icon(Icons.attach_file, size: 14, color: AppTheme.cobalt),
                                    label: Text('${l.attachedFileChip}: ${_pickedFreightFile!.name}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    backgroundColor: AppTheme.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                if (_extractedFreightMetadata?['origin_port'] != null)
                                  Chip(
                                    avatar: const Icon(Icons.flight_takeoff, size: 14, color: AppTheme.cobalt),
                                    label: Text('${l.originPortChip}: ${_extractedFreightMetadata!['origin_port']}', style: const TextStyle(fontSize: 10.5)),
                                    backgroundColor: AppTheme.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                if (_extractedFreightMetadata?['destination_port'] != null)
                                  Chip(
                                    avatar: const Icon(Icons.flight_land, size: 14, color: AppTheme.emerald),
                                    label: Text('${l.destinationPortChip}: ${_extractedFreightMetadata!['destination_port']}', style: const TextStyle(fontSize: 10.5)),
                                    backgroundColor: AppTheme.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                if (_extractedFreightMetadata?['local_charges'] != null)
                                  Chip(
                                    avatar: const Icon(Icons.monetization_on, size: 14, color: AppTheme.orange),
                                    label: Text('${l.localExpensesChip}: \$${_extractedFreightMetadata!['local_charges']}', style: const TextStyle(fontSize: 10.5)),
                                    backgroundColor: AppTheme.white,
                                    padding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _extractedOptions.map((opt) {
                              return Container(
                                width: 340,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.cloudWhite),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${opt.carrierName} (${opt.containerType})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: opt.isDirect ? AppTheme.emeraldLight : AppTheme.orangeLight,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: opt.isDirect ? AppTheme.emeraldBorder : AppTheme.orange),
                                          ),
                                          child: Text(
                                            opt.isDirect ? l.directRoute : l.transitRoute,
                                            style: TextStyle(fontSize: 10, color: opt.isDirect ? AppTheme.wcagEmerald : AppTheme.wcagOrange, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${l.oceanFreightLabel}: \$${opt.oceanFreight.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                        if (opt.localCharges != null && opt.localCharges! > 0)
                                          Text('${l.localChargesLabel}: \$${opt.localCharges!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        Text('${l.totalLabel}: \$${opt.totalEstimatedCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('⏱️ ${l.transitDaysLabel}: ${opt.transitDays ?? "-"}', style: const TextStyle(fontSize: 10.5, color: AppTheme.charcoal)),
                                        Text('⏳ ${l.freeTimeDaysLabel}: ${opt.freeTimeDays ?? 14}', style: const TextStyle(fontSize: 10.5, color: AppTheme.charcoal)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: AppButton(
                                        label: l.addThisQuoteBtn,
                                        icon: Icons.add,
                                        variant: AppButtonVariant.secondary,
                                        size: AppButtonSize.small,
                                        onPressed: () => _handleAddSingle(opt),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
