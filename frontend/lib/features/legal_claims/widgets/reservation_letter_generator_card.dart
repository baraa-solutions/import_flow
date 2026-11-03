import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../legal_claims_provider.dart';

class ReservationLetterGeneratorCard extends StatelessWidget {
  final LegalClaimItem claim;

  const ReservationLetterGeneratorCard({super.key, required this.claim});

  String _generateLetterText() {
    return '''السادة المحترمون / ${claim.targetParty}
تحية طيبة وبعد،،

الموضوع: خطاب تحفظ رسمي ضد الأضرار والعجز للشحنة كود [${claim.claimCode}]

نحيطكم علماً بأنه بموجب استلام وفحص الحاوية / الرسالة الخاصة بملف الاستيراد رقم [${claim.importFileId}]، تبين وجود ${claim.damageNature == 'LATENT' ? 'أضرار مستترة وتلف خفي' : 'أضرار ظاهرة وعجز تفريغ'} بلغت قيمتها المبدئية [${claim.claimedAmount.toStringAsFixed(2)} ${claim.claimedCurrency}].

وعليه، فإننا نحملكم المسؤولية القانونية والمادية الكاملة عن هذه الأضرار وفقاً لأحكام القانون التجاري وقواعد سند الشحن البحري، مع احتفاظنا الكامل بكافة حقوقنا بالتعويض والرجوع القضائي وتكليف خبير معاينة مشتركة لإعداد محضر المعاينة النهائي.

وتفضلوا بقبول فائق الاحترام والتقدير،،
شركة سرور للخدمات اللوجستية والاستيراد
''';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'خطاب التحفظ الرسمي وتحميل المسؤولية للناقل',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                  ),
                ),
                AppButton(
                  label: 'نسخ نص الخطاب',
                  icon: Icons.copy,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => CopyHelper.copy(context, _generateLetterText()),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'تصدير الخطاب',
                  icon: Icons.download_outlined,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () async {
                    final bytes = utf8.encode(_generateLetterText());
                    await FileSaveHelper.exportAndSaveFile(
                      context: context,
                      bytes: bytes,
                      stageName: 'خطاب تحفظ رسمي',
                      importFileNameOrCode: claim.claimCode,
                      extension: 'txt',
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الطرف الموجه له التحفظ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(claim.targetParty, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رقم صادر خطاب التحفظ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(claim.reservationLetterRef ?? 'غير صادر', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('قيمة المطالبة المبدئية', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${claim.claimedAmount.toStringAsFixed(2)} ${claim.claimedCurrency}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
