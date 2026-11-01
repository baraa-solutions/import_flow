import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../providers/import_documentation_provider.dart';
import '../edit_mts_data_dialog.dart';
import 'nafeza_acid_service.dart';
import 'nafeza_parsed_mts_result_card.dart';

class NafezaSmartMtsParserTab extends ConsumerStatefulWidget {
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final Map<String, dynamic>? initialParsedData;
  final ValueChanged<Map<String, dynamic>?> onParsedDataChanged;
  final VoidCallback onGoToVerification;
  final VoidCallback onOpenImportFromPrevious;
  final TextEditingController rawMtsTextController;

  const NafezaSmartMtsParserTab({
    super.key,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    this.initialParsedData,
    required this.onParsedDataChanged,
    required this.onGoToVerification,
    required this.onOpenImportFromPrevious,
    required this.rawMtsTextController,
  });

  @override
  ConsumerState<NafezaSmartMtsParserTab> createState() => _NafezaSmartMtsParserTabState();
}

class _NafezaSmartMtsParserTabState extends ConsumerState<NafezaSmartMtsParserTab> {
  bool _isParsingMts = false;
  bool _isSaving = false;
  Map<String, dynamic>? _parsedData;

  @override
  void initState() {
    super.initState();
    _parsedData = widget.initialParsedData;
  }

  @override
  void didUpdateWidget(covariant NafezaSmartMtsParserTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialParsedData != widget.initialParsedData) {
      _parsedData = widget.initialParsedData;
    }
  }

  void _loadSampleMtsText() {
    if (!kDebugMode) return;
    setState(() {
      widget.rawMtsTextController.text = '''MTS Notification
Dear Sample Exporter Co.,Ltd,

Kindly be informed that an Advance Cargo Information request (ACI) has been approved for shipping:
[ACID: 0000000000000000000]
Requested: 01-Jan-2026 10:00:00 AM   Generated: 01-Jan-2026 10:00:10 AM   Expires: 01-Jul-2026 10:00:10 AM

Egyptian Importer
Egyptian Importer Name: Sample Importer Co.
Egyptian Importer Tax ID: 000000000
Address: Sample address

Foreign Exporter
Foreign Exporter Name: Sample Exporter Co.,Ltd
Foreign Exporter ID: 000000000000000000
Registration Type: Company Registration Number
Country of Export: CHINA

Proforma Invoice No.: SAMPLE-001
Port of Loading: SAMPLE PORT
Port of Discharge: Alexandria
CargoX Platform ID: 00000000-0000-0000-0000-000000000000''';
    });
    parseMtsText();
  }

  Future<void> parseMtsText() async {
    final l = context.l10n;
    final raw = widget.rawMtsTextController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.pasteMtsTextFirst, severity: AppSeverity.danger),
      );
      return;
    }

    if (raw.contains('MTS EMAIL NOTICE This Electronic Mail') &&
        !raw.contains('ACID') &&
        !RegExp(r'\d{19}').hasMatch(raw)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 26),
              const SizedBox(width: 8),
              Text(l.mtsNoticeDisclaimerAlertTitle),
            ],
          ),
          content: Text(
            l.mtsNoticeDisclaimerAlertContent,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            AppButton(
              label: l.close,
              onPressed: () => Navigator.pop(ctx),
              variant: AppButtonVariant.secondary,
            ),
            if (kDebugMode)
              AppButton(
                label: l.loadSampleMtsAndTest,
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadSampleMtsText();
                },
                icon: Icons.auto_fix_high,
              ),
          ],
        ),
      );
      return;
    }

    setState(() => _isParsingMts = true);
    try {
      final responseData = await ref.read(acidSessionsProvider.notifier).parseAcidText(raw, importFileId: widget.selectedImportFileId);
      final Map<String, dynamic> parsedFields = (responseData['parsed_data'] != null && responseData['parsed_data'] is Map)
          ? Map<String, dynamic>.from(responseData['parsed_data'] as Map)
          : Map<String, dynamic>.from(responseData);

      setState(() => _parsedData = parsedFields);
      widget.onParsedDataChanged(parsedFields);

      if (mounted) {
        final acidFound = (parsedFields['acid_number'] != null && parsedFields['acid_number'].toString().trim().isNotEmpty);
        if (acidFound) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.acidExtractedSuccess(parsedFields['acid_number']?.toString() ?? ''), severity: AppSeverity.success),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.orange, size: 26),
                  const SizedBox(width: 8),
                  Text(l.mtsNoticeNoAcidAlertTitle),
                ],
              ),
              content: Text(
                l.mtsNoticeNoAcidAlertContent,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              actions: [
                AppButton(
                  label: l.close,
                  onPressed: () => Navigator.pop(ctx),
                  variant: AppButtonVariant.secondary,
                ),
                if (kDebugMode)
                  AppButton(
                    label: l.loadSampleMtsAndExtract,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _loadSampleMtsText();
                    },
                    icon: Icons.auto_fix_high,
                  ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: l.errorParsingMts, error: e);
      }
    } finally {
      if (mounted) setState(() => _isParsingMts = false);
    }
  }

  void _showEditMtsDataDialog() {
    if (_parsedData == null) return;
    EditMtsDataDialog.show(
      context,
      initialData: _parsedData!,
      onSaved: (updated) {
        setState(() => _parsedData = updated);
        widget.onParsedDataChanged(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.mtsExtractedDataUpdated, severity: AppSeverity.success),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.emeraldLight : AppTheme.infoBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.wcagEmerald.withValues(alpha: 0.4) : AppTheme.cobaltBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: isDark ? AppTheme.wcagEmerald : AppTheme.cobalt, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.smartParserInfoBanner,
                      style: TextStyle(
                        color: isDark ? AppTheme.emerald : AppTheme.infoForeground,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecorationOf(context),
              child: SearchableDropdownField<int>(
                labelText: l.linkImportFileResult,
                hintText: l.searchFileOrSupplierHint,
                value: widget.selectedImportFileId,
                items: importFiles.map((f) => SearchableDropdownItem<int>(
                  value: f.importFileId,
                  label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName}',
                )).toList(),
                onChanged: widget.onImportFileChanged,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              decoration: AppTheme.cardDecorationOf(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l.pasteRawMtsTextTitle}:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (kDebugMode)
                        AppButton(
                          label: l.loadSampleMtsTextButton,
                          onPressed: _loadSampleMtsText,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          icon: Icons.auto_fix_high,
                        ),
                      AppButton(
                        label: l.importFromPreviousAcidSessionBtn,
                        onPressed: widget.onOpenImportFromPrevious,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        icon: Icons.history_edu,
                      ),
                      AppButton(
                        label: l.pasteFromClipboardButton,
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            widget.rawMtsTextController.text = data!.text!;
                          }
                        },
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        icon: Icons.paste,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: widget.rawMtsTextController,
                    maxLines: 8,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: l.mtsNotificationHint,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AppButton(
                        label: _isParsingMts ? l.loading : l.runSmartParserButton,
                        onPressed: _isParsingMts ? null : parseMtsText,
                        icon: Icons.bolt,
                        isLoading: _isParsingMts,
                      ),
                      AppButton(
                        label: l.clearTextButton,
                        onPressed: () => setState(() {
                          widget.rawMtsTextController.clear();
                          _parsedData = null;
                          widget.onParsedDataChanged(null);
                        }),
                        variant: AppButtonVariant.secondary,
                        icon: Icons.clear_all,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_parsedData != null) ...[
              const SizedBox(height: 20),
              NafezaParsedMtsResultCard(
                parsedData: _parsedData!,
                isSaving: _isSaving,
                onGoToVerification: widget.onGoToVerification,
                onSaveCertified: () => NafezaAcidService.saveMtsResultAsAcidSession(
                  context: context,
                  ref: ref,
                  parsedData: _parsedData,
                  selectedImportFileId: widget.selectedImportFileId,
                  rawText: widget.rawMtsTextController.text,
                  isDraft: false,
                  onSavingStateChanged: (s) => setState(() => _isSaving = s),
                ),
                onSaveDraft: () => NafezaAcidService.saveMtsResultAsAcidSession(
                  context: context,
                  ref: ref,
                  parsedData: _parsedData,
                  selectedImportFileId: widget.selectedImportFileId,
                  rawText: widget.rawMtsTextController.text,
                  isDraft: true,
                  onSavingStateChanged: (s) => setState(() => _isSaving = s),
                ),
                onEdit: _showEditMtsDataDialog,
                onCodeSupplier: () => NafezaAcidService.codeSupplierFromMts(
                  context: context,
                  ref: ref,
                  parsedData: _parsedData,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
