import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

class POLineItemIdentificationSection extends StatelessWidget {
  final TextEditingController itemCodeController;
  final TextEditingController descArController;
  final TextEditingController descEnController;
  final String? selectedCountryOfOrigin;
  final List<SearchableDropdownItem<String?>> countryItems;
  final ValueChanged<String?> onCountryChanged;
  final bool isArabic;

  const POLineItemIdentificationSection({
    super.key,
    required this.itemCodeController,
    required this.descArController,
    required this.descEnController,
    required this.selectedCountryOfOrigin,
    required this.countryItems,
    required this.onCountryChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: itemCodeController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كود الصنف / SKU' : 'Item Code / SKU',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: SearchableDropdownField<String?>(
                value: selectedCountryOfOrigin,
                labelText: isArabic ? 'بلد المنشأ للبند' : 'Country of Origin',
                searchHintText:
                    isArabic ? 'ابحث عن بلد المنشأ...' : 'Search country...',
                items: countryItems,
                onChanged: onCountryChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: descArController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الوصف بالعربية *' : 'Arabic Description *',
                  isDense: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: descEnController,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الوصف بالإنجليزية' : 'English Description',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
