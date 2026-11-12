import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import 'supplier_form_controllers.dart';

class SupplierTrademarkSection extends StatelessWidget {
  final SupplierFormControllers controllers;
  final ValueChanged<VoidCallback> onStateChanged;

  const SupplierTrademarkSection({
    super.key,
    required this.controllers,
    required this.onStateChanged,
  });

  Widget _expiry(String key, bool isAr) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: CertificateExpiryField(
          key: ValueKey('supplier_expiry_$key'),
          value: controllers.expiries[key],
          isArabic: isAr,
          label: isAr ? 'تاريخ الانتهاء' : 'Expiry Date',
          onChanged: (v) => onStateChanged(() => controllers.expiries[key] = v),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Text(
                isAr ? 'شهادات العلامة التجارية والجودة' : 'Trademark Certificates & ISO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(isAr ? 'شهادة وايپو مدريد (WIPO)' : 'WIPO Madrid Monitor Certificate'),
            value: controllers.hasWipo,
            activeColor: AppTheme.cobalt,
            onChanged: (val) => onStateChanged(() => controllers.hasWipo = val ?? false),
          ),
          if (controllers.hasWipo) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: CustomTextField(
                controller: controllers.wipoCtrl,
                suffixIcon: controllers.buildCopySuffix(context, controllers.wipoCtrl),
                label: isAr ? 'رقم تسجيل WIPO Madrid' : 'WIPO Madrid Registration No.',
                icon: Icons.numbers,
                hint: 'e.g. 1234567',
              ),
            ),
            _expiry('wipo', isAr),
          ],
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(isAr ? 'شهادة العلامة الأوروبية (EUIPO)' : 'EUIPO Certificate'),
            value: controllers.hasEuipo,
            activeColor: AppTheme.cobalt,
            onChanged: (val) => onStateChanged(() => controllers.hasEuipo = val ?? false),
          ),
          if (controllers.hasEuipo) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: CustomTextField(
                controller: controllers.euipoCtrl,
                suffixIcon: controllers.buildCopySuffix(context, controllers.euipoCtrl),
                label: isAr ? 'رقم تسجيل EUIPO' : 'EUIPO Registration No.',
                icon: Icons.numbers,
                hint: 'e.g. 018345678',
              ),
            ),
            _expiry('euipo', isAr),
          ],
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(isAr ? 'قاعدة بيانات العلامات العالمية' : 'Global Brand Database'),
            value: controllers.hasGlobalBrand,
            activeColor: AppTheme.cobalt,
            onChanged: (val) => onStateChanged(() => controllers.hasGlobalBrand = val ?? false),
          ),
          if (controllers.hasGlobalBrand) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: CustomTextField(
                controller: controllers.globalBrandCtrl,
                suffixIcon: controllers.buildCopySuffix(context, controllers.globalBrandCtrl),
                label: isAr ? 'معرف العلامة في قاعدة بيانات العلامات العالمية' : 'Global Brand DB Identifier',
                icon: Icons.numbers,
                hint: 'e.g. GBD-987654',
              ),
            ),
            _expiry('global_brand', isAr),
          ],
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(isAr ? 'شهادة نظام إدارة الجودة (ISO 9001)' : 'ISO 9001 Certificate'),
            value: controllers.hasIso9001,
            activeColor: AppTheme.cobalt,
            onChanged: (val) => onStateChanged(() => controllers.hasIso9001 = val ?? false),
          ),
          if (controllers.hasIso9001) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: CustomTextField(
                controller: controllers.iso9001Ctrl,
                suffixIcon: controllers.buildCopySuffix(context, controllers.iso9001Ctrl),
                label: isAr ? 'رقم شهادة ISO 9001' : 'ISO 9001 Certificate No.',
                icon: Icons.verified_user_outlined,
                hint: 'e.g. ISO-9001-2015-XYZ',
              ),
            ),
            _expiry('iso_9001', isAr),
          ],
        ],
      ),
    );
  }
}
