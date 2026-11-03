import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../extractor_controllers.dart';

/// Reusable section for capturing bank details (name, swift, account, IBAN).
class ExtractorBankDetailsSection extends StatelessWidget {
  final ExtractorControllers controllers;
  final String titleAr;
  final String titleEn;

  const ExtractorBankDetailsSection({
    super.key,
    required this.controllers,
    this.titleAr = 'بيانات البنك المستفيد والحساب المصرفي',
    this.titleEn = 'Beneficiary Bank Details',
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final c = controllers;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, size: 16, color: AppTheme.charcoal),
              const SizedBox(width: 6),
              Text(
                isArabic ? titleAr : titleEn,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: c.bankNameCtrl,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'اسم البنك المصرفي' : 'Bank Name',
                    prefixIcon: const Icon(Icons.account_balance_outlined, size: 16),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: c.swiftCodeCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'كود السويفت البنكي الدولي' : 'SWIFT Code',
                    prefixIcon: const Icon(Icons.code, size: 16),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: c.accountNumberCtrl,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم الحساب المصرفي' : 'Account Number',
                    prefixIcon: const Icon(Icons.numbers, size: 16),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: c.ibanCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم الآيبان الدولي' : 'IBAN',
                    prefixIcon: const Icon(Icons.credit_card, size: 16),
                    isDense: true,
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
