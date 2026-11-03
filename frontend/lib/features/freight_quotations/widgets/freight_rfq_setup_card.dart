import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../../transport_locations/models/transport_location_model.dart';

class FreightRfqSetupData {
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final List<ImportFileModel> importFilesList;
  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final String shippingMethod;
  final ValueChanged<String?> onShippingMethodChanged;
  final DateTime crdDate;
  final ValueChanged<DateTime?> onCrdDateChanged;
  final String polName;
  final ValueChanged<String?> onPolNameChanged;
  final String podName;
  final ValueChanged<String?> onPodNameChanged;
  final List<TransportLocationModel> portsList;
  final TextEditingController cbmController;
  final TextEditingController weightController;
  final bool isStackable;
  final ValueChanged<bool> onStackableChanged;
  final VoidCallback onCompareCases;

  const FreightRfqSetupData({
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.importFilesList,
    required this.titleController,
    required this.onTitleChanged,
    required this.shippingMethod,
    required this.onShippingMethodChanged,
    required this.crdDate,
    required this.onCrdDateChanged,
    required this.polName,
    required this.onPolNameChanged,
    required this.podName,
    required this.onPodNameChanged,
    required this.portsList,
    required this.cbmController,
    required this.weightController,
    required this.isStackable,
    required this.onStackableChanged,
    required this.onCompareCases,
  });
}

class FreightRfqSetupCard extends StatelessWidget {
  final FreightRfqSetupData data;

  const FreightRfqSetupCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'بيانات شحنة طلب عرض الأسعار (Freight RFQ Setup)'
                  : 'Freight RFQ Setup & Cargo Details',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<int?>(
                    value: data.selectedImportFileId,
                    labelText: isArabic ? 'ملف الشحنة الاستيرادية (Import File)' : 'Import File',
                    searchHintText:
                        isArabic ? 'ابحث عن ملف الشحنة...' : 'Search import file...',
                    items: [
                      SearchableDropdownItem<int?>(
                        value: null,
                        label: isArabic
                            ? '-- غير مرتبط بملف شحنة / None --'
                            : '-- None / Unlinked --',
                      ),
                      ...data.importFilesList.map((f) => SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} - ${f.companyName}',
                          )),
                    ],
                    onChanged: data.onImportFileChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: data.titleController,
                    onChanged: data.onTitleChanged,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'عنوان طلب عرض الأسعار *' : 'RFQ Subject / Title *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isArabic ? 'يرجى إدخال العنوان' : 'Please enter title')
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    value: data.shippingMethod,
                    labelText: isArabic
                        ? 'وسيلة الشحن (Shipping Method) *'
                        : 'Shipping Method *',
                    searchHintText:
                        isArabic ? 'ابحث عن الوسيلة...' : 'Search shipping method...',
                    items: [
                      SearchableDropdownItem(
                          value: 'Ocean FCL',
                          label: isArabic
                              ? 'Ocean FCL (شحن بحري كامل)'
                              : 'Ocean FCL (Full Container Load)'),
                      SearchableDropdownItem(
                          value: 'Ocean LCL',
                          label: isArabic
                              ? 'Ocean LCL (شحن بحري جزئي)'
                              : 'Ocean LCL (Less than Container Load)'),
                      SearchableDropdownItem(
                          value: 'Air Freight',
                          label: isArabic ? 'Air Freight (شحن جوي)' : 'Air Freight'),
                      SearchableDropdownItem(
                          value: 'Courier Express',
                          label: isArabic
                              ? 'Courier Express (بريد سريع / شحن سريع)'
                              : 'Courier Express'),
                      SearchableDropdownItem(
                          value: 'Inland Trucking',
                          label: isArabic ? 'Inland Trucking (شحن بري)' : 'Inland Trucking'),
                      SearchableDropdownItem(
                          value: 'Multi-Modal',
                          label: isArabic
                              ? 'Multi-Modal (نقل متعدد الوسائط)'
                              : 'Multi-Modal'),
                    ],
                    onChanged: data.onShippingMethodChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppDatePickerField(
                    label: isArabic
                        ? 'تاريخ جاهزية البضاعة (CRD) *'
                        : 'Cargo Ready Date (CRD) *',
                    value: data.crdDate,
                    isRequired: true,
                    allowClear: false,
                    onChanged: data.onCrdDateChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SearchableDropdownField<String>(
                    value: data.polName.isNotEmpty
                        ? data.polName
                        : (data.portsList.isNotEmpty
                            ? data.portsList.first.locationName
                            : 'Shanghai Port (CN SHA), China'),
                    labelText: isArabic ? 'ميناء التحميل (POL) *' : 'Port of Loading (POL) *',
                    searchHintText:
                        isArabic ? 'ابحث عن ميناء التحميل...' : 'Search port of loading...',
                    items: [
                      if (data.polName.isNotEmpty &&
                          !data.portsList.any((p) => p.locationName == data.polName))
                        SearchableDropdownItem<String>(value: data.polName, label: data.polName),
                      ...data.portsList.map((p) => SearchableDropdownItem<String>(
                          value: p.locationName, label: p.locationName)),
                    ],
                    onChanged: data.onPolNameChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SearchableDropdownField<String>(
                    value: data.podName.isNotEmpty
                        ? data.podName
                        : (data.portsList.length > 1
                            ? data.portsList[1].locationName
                            : 'Alexandria Port (EG ALX), Egypt'),
                    labelText: isArabic ? 'ميناء الوصول (POD) *' : 'Port of Discharge (POD) *',
                    searchHintText:
                        isArabic ? 'ابحث عن ميناء الوصول...' : 'Search port of discharge...',
                    items: [
                      if (data.podName.isNotEmpty &&
                          !data.portsList.any((p) => p.locationName == data.podName))
                        SearchableDropdownItem<String>(value: data.podName, label: data.podName),
                      ...data.portsList.map((p) => SearchableDropdownItem<String>(
                          value: p.locationName, label: p.locationName)),
                    ],
                    onChanged: data.onPodNameChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: data.cbmController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'إجمالي الحجم (CBM)' : 'Total Volume (CBM)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: data.weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'الوزن القائم (Gross Wt kg)' : 'Gross Weight (kg)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            // Container Recommendation Engine (MD-019.1 Banner)
            Builder(builder: (context) {
              final curCbm = double.tryParse(data.cbmController.text.trim()) ?? 0.0;
              final curWeight = double.tryParse(data.weightController.text.trim()) ?? 0.0;
              final dualRec = ContainerRequirementEngine.calculateBoth(
                  totalCbm: curCbm, totalWeightKg: curWeight);
              final containerRec =
                  data.isStackable ? dualRec.stackableResult : dualRec.nonStackableResult;

              return Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          isArabic ? '🚚 نوع التحميل والتخزين: ' : '🚚 Cargo Stacking Type: ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.charcoal),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(isArabic ? '📦 بضائع قابلة للرص' : '📦 Stackable Cargo'),
                          selected: data.isStackable,
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                              color: data.isStackable ? Colors.white : AppTheme.charcoal,
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                          onSelected: (_) => data.onStackableChanged(true),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                              isArabic ? '🚫 بضائع غير قابلة للرص' : '🚫 Non-Stackable Cargo'),
                          selected: !data.isStackable,
                          selectedColor: Colors.orange.shade800,
                          labelStyle: TextStyle(
                              color: !data.isStackable ? Colors.white : AppTheme.charcoal,
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                          onSelected: (_) => data.onStackableChanged(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic
                                    ? '🚚 اقتراح أعداد وأنواع الحاويات التلقائي:'
                                    : '🚚 Auto Container Recommendation:',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.charcoal),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                containerRec.recommendationSummary,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: data.isStackable
                                        ? Colors.blue.shade900
                                        : Colors.orange.shade900,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.table_chart, size: 14, color: Colors.white),
                          label: Text(isArabic ? 'مقارنة الحالتين' : 'Compare Cases',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          onPressed: data.onCompareCases,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
