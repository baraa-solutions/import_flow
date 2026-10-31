import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../models/freight_quotation_model.dart';

class FreightAddQuotationDialog {
  static void show(
    BuildContext context,
    WidgetRef ref, {
    required DateTime crdDate,
    String? prefillCarrierName,
    int? prefillProviderId,
    double? prefillOceanCost,
    double? prefillLocalCost,
    int? prefillTransitDays,
    int? prefillFreeDays,
    String? prefillRemarks,
    required ValueChanged<FreightQuotationItemModel> onQuotationAdded,
  }) {
    final isArabic = context.l10n.isArabic;
    final partnersState = ref.read(partnersProvider);
    final partnersList = partnersState.value ?? [];
    final carriersList = partnersList
        .where((p) => p.partnerType.contains('Shipping Line') || p.partnerType.contains('Freight'))
        .toList();

    if (carriersList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic
              ? 'يرجى إضافة ناقلين بحريين وخطوط ملاحية في دليل الشركاء أولاً'
              : 'Please add ocean carriers and shipping lines in Partners Directory first',
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    // Try to find matching carrier if prefill name provided
    int? matchedProviderId = prefillProviderId;
    String matchedProviderName = carriersList.first.partnerName;
    if (prefillProviderId != null) {
      final found = carriersList.where((c) => c.providerId == prefillProviderId).firstOrNull;
      if (found != null) matchedProviderName = found.partnerName;
    } else if (prefillCarrierName != null && prefillCarrierName.isNotEmpty) {
      final nameLower = prefillCarrierName.toLowerCase();
      final found = carriersList
          .where((c) =>
              c.partnerName.toLowerCase().contains(nameLower) ||
              nameLower.contains(c.partnerName.toLowerCase()))
          .firstOrNull;
      if (found != null) {
        matchedProviderId = found.providerId;
        matchedProviderName = found.partnerName;
      } else {
        matchedProviderId = carriersList.first.providerId;
      }
    } else {
      matchedProviderId = carriersList.first.providerId;
    }

    final vesselController = TextEditingController();
    final voyageController = TextEditingController();
    final oceanCostController = TextEditingController(
        text: prefillOceanCost != null ? prefillOceanCost.toStringAsFixed(0) : '');
    final localCostController = TextEditingController(
        text: prefillLocalCost != null ? prefillLocalCost.toStringAsFixed(0) : '');
    final inlandCostController = TextEditingController();
    final freeDaysController =
        TextEditingController(text: prefillFreeDays?.toString() ?? '');
    final remarksController = TextEditingController(text: prefillRemarks ?? '');

    showDialog(
      context: context,
      builder: (context) {
        int? selectedProviderId = matchedProviderId;
        String selectedProviderName = matchedProviderName;

        DateTime sailingDate = crdDate.add(const Duration(days: 4));
        DateTime arrivalDate = prefillTransitDays != null
            ? sailingDate.add(Duration(days: prefillTransitDays))
            : sailingDate.add(const Duration(days: 24));

        return SelectionArea(
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.directions_boat, color: AppTheme.cobalt),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prefillCarrierName != null
                            ? (isArabic
                                ? 'مراجعة وتأكيد عرض السعر المستخرج'
                                : 'Review & Confirm Extracted Quote')
                            : (isArabic
                                ? 'إضافة عرض سعر ناقل أو شركة شحن'
                                : 'Add Carrier / Shipping Line Quotation'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 550,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (prefillCarrierName != null && prefillCarrierName.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isArabic
                                        ? '🤖 تم استخراج هذا العرض تلقائياً من النص. راجع البيانات قبل الإضافة.'
                                        : '🤖 Auto-extracted from quote text. Please verify fields before adding.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.cobalt.withValues(alpha: 0.8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SearchableDropdownField<int?>(
                          value: selectedProviderId,
                          labelText:
                              isArabic ? 'شركة الشحن أو الخط الملاحي *' : 'Shipping Line or Carrier *',
                          searchHintText: isArabic ? 'ابحث عن الشركة...' : 'Search carrier...',
                          items: carriersList
                              .map((c) => SearchableDropdownItem<int?>(
                                  value: c.providerId, label: c.partnerName))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final c = carriersList.firstWhere((p) => p.providerId == val);
                              setDialogState(() {
                                selectedProviderId = val;
                                selectedProviderName = c.partnerName;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: vesselController,
                                decoration: InputDecoration(
                                  labelText: isArabic ? 'اسم السفينة الناقلة' : 'Vessel Name',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: voyageController,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  labelText: isArabic ? 'رقم الرحلة البحرية' : 'Voyage Number',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: oceanCostController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'نولون الشحن البحري بالدولار *'
                                      : 'Ocean Freight USD *',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: localCostController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'المصاريف والرسوم المحلية بالدولار'
                                      : 'Local Charges USD',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: inlandCostController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'النقل الداخلي والتعتيق بالدولار'
                                      : 'Inland Haulage USD',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppDatePickerField(
                                label: isArabic
                                    ? 'تاريخ الإبحار الفعلي'
                                    : 'Actual Sailing Date (ETD)',
                                value: sailingDate,
                                allowClear: false,
                                onChanged: (d) {
                                  if (d != null) setDialogState(() => sailingDate = d);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppDatePickerField(
                                label: isArabic
                                    ? 'تاريخ الوصول المتوقع للميناء'
                                    : 'Estimated Arrival Date (ETA)',
                                value: arrivalDate,
                                allowClear: false,
                                onChanged: (d) {
                                  if (d != null) setDialogState(() => arrivalDate = d);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: freeDaysController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'فترة السماح بالجمارك بالأيام'
                                      : 'Free Time at POD (Days)',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: remarksController,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'ملاحظات وشروط العرض' : 'Quotation Remarks & Terms',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                    onPressed: () {
                      final oceanCost =
                          double.tryParse(oceanCostController.text.trim()) ?? 0.0;
                      final localCost =
                          double.tryParse(localCostController.text.trim()) ?? 0.0;
                      final inlandCost =
                          double.tryParse(inlandCostController.text.trim()) ?? 0.0;
                      final totalCost = oceanCost + localCost + inlandCost;
                      final transitDays = arrivalDate.difference(sailingDate).inDays;

                      final quote = FreightQuotationItemModel(
                        providerId: selectedProviderId!,
                        providerName: selectedProviderName,
                        vesselName: vesselController.text.trim().isNotEmpty
                            ? vesselController.text.trim()
                            : null,
                        voyageNumber: voyageController.text.trim().isNotEmpty
                            ? voyageController.text.trim()
                            : null,
                        oceanFreightCost: oceanCost,
                        localChargesCost: localCost,
                        inlandCost: inlandCost,
                        totalCost: totalCost,
                        sailingDate: sailingDate.toString().substring(0, 10),
                        estimatedArrivalDate: arrivalDate.toString().substring(0, 10),
                        transitDays: transitDays > 0 ? transitDays : 1,
                        freeDaysAtPod: int.tryParse(freeDaysController.text.trim()) ?? 14,
                        remarks: remarksController.text.trim().isNotEmpty
                            ? remarksController.text.trim()
                            : null,
                      );
                      onQuotationAdded(quote);
                      Navigator.pop(context);
                    },
                    child: Text(isArabic ? 'إضافة العرض' : 'Add Quote',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          ),
        );
      },
    ).then((_) {
      vesselController.dispose();
      voyageController.dispose();
      oceanCostController.dispose();
      localCostController.dispose();
      inlandCostController.dispose();
      freeDaysController.dispose();
      remarksController.dispose();
    });
  }
}
