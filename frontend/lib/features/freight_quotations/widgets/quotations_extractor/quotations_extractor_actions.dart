import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

/// Footer action buttons for the Freight Quotations Extractor dialog.
class QuotationsExtractorFooterActions extends StatelessWidget {
  final int selectedCount;
  final bool hasResults;
  final VoidCallback onCancel;
  final VoidCallback onAddSelected;

  const QuotationsExtractorFooterActions({
    super.key,
    required this.selectedCount,
    required this.hasResults,
    required this.onCancel,
    required this.onAddSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const Spacer(),
          if (hasResults)
            AppButton(
              label: isArabic
                  ? '➕ تعبئة وإضافة العروض المحددة ($selectedCount)'
                  : '➕ Add Selected Quotes ($selectedCount)',
              variant: AppButtonVariant.primary,
              icon: Icons.check,
              onPressed: selectedCount > 0 ? onAddSelected : null,
            ),
        ],
      ),
    );
  }
}

/// Helper modals for adding and editing custom/unmapped fields.
class QuotationsExtractorModals {
  /// Shows modal dialog to manually add a custom field or expense.
  static void showAddCustomFieldModal(
    BuildContext context, {
    required void Function(String key, String value) onAdd,
  }) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    String selectedPreset = 'free_time_extend';
    final keyCtrl = TextEditingController(
      text: isArabic ? 'تمديد فترة السماح' : 'Free Time Extension',
    );
    final valCtrl = TextEditingController();

    final presets = isArabic
        ? {
            'free_time_extend': '⏳ تمديد فترة السماح (بالدولار لكل حاوية)',
            'thc_charge': '🏗️ رسوم المناولة وتداول الحاويات',
            'doc_fee': '📄 رسوم بوليصة ومستندات',
            'isps_fee': '🛡️ رسوم أمن الميناء',
            'seal_fee': '🔒 رسوم الرصاصة الجمركية',
            'vgm_fee': '⚖️ رسوم وزن الحاوية',
            'chassis_fee': '🚛 رسوم الشاسيه',
            'forwarder_name': '🏢 وكيل الشحن أو الناقل',
            'carrier_name': '🚢 الخط الملاحي',
            'origin_port': '⚓ ميناء الشحن أو القيام',
            'destination_port': '⚓ ميناء الوصول أو التفريغ',
            'vessel_name': '🚢 اسم الباخرة',
            'voyage_number': '🔢 رقم الرحلة',
            'etd_date': '📅 تاريخ الإبحار',
            'eta_date': '📅 تاريخ الوصول',
            'transit_days': '⏱ مدة الإبحار (أيام)',
            'free_time_days': '⏳ فترة السماح (أيام)',
            'rate_20gp': '💵 نولون الحاوية 20',
            'rate_40hq': '💵 نولون الحاوية 40',
            'local_charges': '💰 مصاريف ورسوم محلية بالدولار',
            'exw_charges': '🏭 رسوم المصنع والنقل الداخلي بالدولار',
            'notes': '📝 ملاحظات وشروط إضافية',
            'custom': '➕ بيان أو مصروف مخصص آخر',
          }
        : {
            'free_time_extend': '⏳ Free Time Extension (USD/cntr)',
            'thc_charge': '🏗️ Terminal Handling Charges',
            'doc_fee': '📄 Documentation Fee',
            'isps_fee': '🛡️ Port Security Fee',
            'seal_fee': '🔒 Container Seal Fee',
            'vgm_fee': '⚖️ Verified Gross Mass Fee',
            'chassis_fee': '🚛 Chassis Fee',
            'forwarder_name': '🏢 Freight Forwarder',
            'carrier_name': '🚢 Shipping Line',
            'origin_port': '⚓ Port of Loading',
            'destination_port': '⚓ Port of Discharge',
            'vessel_name': '🚢 Vessel Name',
            'voyage_number': '🔢 Voyage Number',
            'etd_date': '📅 Departure Date',
            'eta_date': '📅 Arrival Date',
            'transit_days': '⏱ Transit Time (Days)',
            'free_time_days': '⏳ Free Time (Days)',
            'rate_20gp': '💵 Rate USD / 20GP',
            'rate_40hq': '💵 Rate USD / 40HQ',
            'local_charges': '💰 Local Charges (USD)',
            'exw_charges': '🏭 EXW / Inland Charges (USD)',
            'notes': '📝 Special Notes & Terms',
            'custom': '➕ Other Custom Expense / Field',
          };

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SelectionArea(
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                const Icon(Icons.add_box_rounded, color: AppTheme.emerald),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'إضافة بيان أو مصروف إضافي يدوياً' : 'Add Custom Field / Expense',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic
                        ? 'اختر نوع المصروف أو البيان أو أدخل بياناً مخصصاً لعروض الأسعار:'
                        : 'Select expense/field type or enter custom details:',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SearchableDropdownField<String>(
                    value: selectedPreset,
                    labelText: isArabic ? 'نوع البيان أو المصروف المطلوب إضافته' : 'Expense / Field Type',
                    items: presets.entries
                        .map((e) => SearchableDropdownItem<String>(value: e.key, label: e.value))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() {
                          selectedPreset = v;
                          if (v != 'custom') {
                            keyCtrl.text = presets[v]!.replaceAll(RegExp(r'^[^\w\s\u0600-\u06FF]+'), '').trim();
                          } else {
                            keyCtrl.clear();
                          }
                        });
                      }
                    },
                  ),
                  if (selectedPreset == 'custom') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: keyCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'اسم المصروف أو البيان الجديد *' : 'New Expense / Field Name *',
                        hintText: isArabic ? 'مثلاً: غرامة إضافية أو تأخير' : 'e.g. Demurrage Tier 2 or Surcharge',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: valCtrl,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'القيمة أو التفاصيل *' : 'Value / Details *',
                      hintText: isArabic ? 'مثلاً: 200 دولار لكل حاوية أو 21 يوماً' : 'e.g. USD 200/cntr or 21 days',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              AppButton(
                label: isArabic ? 'إضافة للبيانات' : 'Add to Data',
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                icon: Icons.check,
                onPressed: () {
                  final k = keyCtrl.text.trim();
                  final v = valCtrl.text.trim();
                  if (k.isNotEmpty && v.isNotEmpty) {
                    onAdd(k, v);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows modal dialog to edit an existing custom field.
  static void showEditCustomFieldModal(
    BuildContext context, {
    required String key,
    required String currentValue,
    required void Function(String newValue) onSave,
  }) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final valCtrl = TextEditingController(text: currentValue);

    showDialog<void>(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'تعديل: $key' : 'Edit: $key',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: TextField(
              controller: valCtrl,
              decoration: InputDecoration(
                labelText: isArabic ? 'القيمة المعدلة' : 'Updated Value',
                isDense: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            AppButton(
              label: isArabic ? 'حفظ التعديل' : 'Save Changes',
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              icon: Icons.save,
              onPressed: () {
                final v = valCtrl.text.trim();
                if (v.isNotEmpty) {
                  onSave(v);
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
