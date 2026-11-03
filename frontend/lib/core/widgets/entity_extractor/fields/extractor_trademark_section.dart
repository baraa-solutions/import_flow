import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../extractor_controllers.dart';

/// Section for capturing trademark and quality certification details.
class ExtractorTrademarkSection extends StatefulWidget {
  final ExtractorControllers controllers;

  const ExtractorTrademarkSection({
    super.key,
    required this.controllers,
  });

  @override
  State<ExtractorTrademarkSection> createState() => _ExtractorTrademarkSectionState();
}

class _ExtractorTrademarkSectionState extends State<ExtractorTrademarkSection> {
  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final c = widget.controllers;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.cobalt),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isArabic ? 'شهادات العلامة التجارية والجودة' : 'Trademark & Quality Certificates',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 1. WIPO Madrid
          Row(
            children: [
              SizedBox(
                width: 170,
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('WIPO Madrid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: c.hasWipo,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) => setState(() => c.hasWipo = val ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: c.wipoNumberCtrl,
                  enabled: c.hasWipo,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم تسجيل WIPO Madrid Monitor' : 'WIPO Registration Number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.tag, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 2. EUIPO
          Row(
            children: [
              SizedBox(
                width: 170,
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isArabic ? 'شهادة الاتحاد الأوروبي' : 'EUIPO',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    value: c.hasEuipo,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) => setState(() => c.hasEuipo = val ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: c.euipoNumberCtrl,
                  enabled: c.hasEuipo,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم تسجيل الاتحاد الأوروبي' : 'EUIPO Registration Number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.tag, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 3. Global Brand
          Row(
            children: [
              SizedBox(
                width: 170,
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isArabic ? 'قاعدة العلامات العالمية' : 'Global Brand',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    value: c.hasGlobalBrand,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) => setState(() => c.hasGlobalBrand = val ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: c.globalBrandNumberCtrl,
                  enabled: c.hasGlobalBrand,
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? 'رقم تسجيل قاعدة العلامات التجارية العالمية'
                        : 'Global Brand Registration Number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.public, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 4. ISO 9001
          Row(
            children: [
              SizedBox(
                width: 170,
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isArabic ? 'شهادة آيزو 9001' : 'ISO 9001 Cert',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    value: c.hasIso9001,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) => setState(() => c.hasIso9001 = val ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: c.iso9001NumberCtrl,
                  enabled: c.hasIso9001,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم وتفاصيل شهادة آيزو 9001' : 'ISO 9001 Certificate Number',
                    isDense: true,
                    prefixIcon: const Icon(Icons.workspace_premium_outlined, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
