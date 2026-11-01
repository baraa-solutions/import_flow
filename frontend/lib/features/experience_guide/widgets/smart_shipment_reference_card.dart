import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../comprehensive_report/models/comprehensive_dossier_model.dart';
import '../../comprehensive_report/services/comprehensive_dossier_service.dart';
import '../../import_files/models/import_file_model.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/smart_reference_card_model.dart';
import '../providers/experience_guide_provider.dart';
import 'add_guide_entry_dialog.dart';
import 'experience_guide_management_dialog.dart';
import 'smart_card/smart_reference_card_export_helper.dart';
import 'smart_card/smart_reference_card_header.dart';
import 'smart_card/smart_reference_guidelines_alert_banner.dart';
import 'smart_card/smart_reference_info_boxes.dart';

class SmartShipmentReferenceCard extends ConsumerStatefulWidget {
  final int importFileId;
  final String? initialHsCode;
  final String? initialCategory;
  final String? initialPod;
  final String? initialSupplier;
  final String? initialCarrier;
  final VoidCallback? onGuidelineAdded;
  final List<PurchaseOrderModel>? linkedPOs;
  final ImportFileModel? file;
  final ComprehensiveShipmentDossierModel? dossier;

  const SmartShipmentReferenceCard({
    super.key,
    required this.importFileId,
    this.initialHsCode,
    this.initialCategory,
    this.initialPod,
    this.initialSupplier,
    this.initialCarrier,
    this.onGuidelineAdded,
    this.linkedPOs,
    this.file,
    this.dossier,
  });

  @override
  ConsumerState<SmartShipmentReferenceCard> createState() => _SmartShipmentReferenceCardState();
}

class _SmartShipmentReferenceCardState extends ConsumerState<SmartShipmentReferenceCard> {
  int _selectedHsIndex = 0;

  void _openAddGuidelineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AddGuideEntryDialog(
        initialHsCode: widget.initialHsCode,
        initialCategory: widget.initialCategory,
        initialDestinationPort: widget.initialPod,
        initialSupplier: widget.initialSupplier,
        initialShippingLine: widget.initialCarrier,
        onSuccess: () {
          ref.invalidate(smartReferenceCardProvider(widget.importFileId));
          ref.invalidate(experienceGuideProvider);
          if (widget.onGuidelineAdded != null) widget.onGuidelineAdded!();
        },
      ),
    );
  }

  void _openManageGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const ExperienceGuideManagementDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isArabic =
        ref.watch(localeProvider).languageCode == 'ar' || Localizations.localeOf(context).languageCode == 'ar';
    final dossier = widget.dossier ?? ref.watch(comprehensiveDossierProvider(widget.importFileId)).valueOrNull;
    final cardAsync = dossier != null
        ? AsyncValue.data(SmartReferenceCardModel.fromDossier(dossier))
        : ref.watch(smartReferenceCardProvider(widget.importFileId));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: SelectionArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: cardAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.flatOrange, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? 'تعذر تحميل المرجع الذكي للشحنة: $err'
                          : 'Failed to load shipment smart reference: $err',
                      style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                      onPressed: () => ref.invalidate(smartReferenceCardProvider(widget.importFileId)),
                    )
                  ],
                ),
              ),
            ),
            data: (card) {
              final acidNum = (card.documentStatus['acid_number'] as String?) ??
                  widget.file?.acidNumber ??
                  widget.dossier?.acidNumber;
              final form4Num = (card.documentStatus['form4_no'] as String?) ??
                  widget.file?.form4No ??
                  widget.dossier?.form4No;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SmartReferenceCardHeader(
                    card: card,
                    onRefresh: () {
                      ref.invalidate(smartReferenceCardProvider(widget.importFileId));
                      ref.invalidate(similarShipmentsProvider(widget.importFileId));
                      ref.invalidate(detectedPatternsProvider);
                    },
                    onCopy: () => SmartReferenceCardExportHelper.copyCardData(context, card, isArabic: isArabic),
                    onManageGuide: () => _openManageGuideDialog(context),
                    onAddGuideline: () => _openAddGuidelineDialog(context),
                    isDark: isDark,
                    isArabic: isArabic,
                  ),
                  Divider(height: 24, color: isDark ? AppTheme.darkBorder : null),
                  SmartReferenceGuidelinesAlertBanner(
                    matchedGuideEntries: card.matchedGuideEntries,
                  ),
                  if (card.matchedGuideEntries.isNotEmpty) const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SmartReferenceProductBox(
                        card: card,
                        selectedHsIndex: _selectedHsIndex,
                        onSelectHsIndex: (idx) => setState(() => _selectedHsIndex = idx),
                        isDark: isDark,
                        isArabic: isArabic,
                      ),
                      SmartReferenceRouteBox(
                        card: card,
                        isDark: isDark,
                        isArabic: isArabic,
                      ),
                      SmartReferenceDatesBox(
                        card: card,
                        isDark: isDark,
                        isArabic: isArabic,
                      ),
                      SmartReferenceDocsBox(
                        card: card,
                        acidNum: acidNum,
                        form4Num: form4Num,
                        isDark: isDark,
                        isArabic: isArabic,
                      ),
                      SmartReferenceCostBox(
                        card: card,
                        isDark: isDark,
                        isArabic: isArabic,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
