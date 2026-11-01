import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/email_settings_model.dart';

class EmailProviderSelector extends StatelessWidget {
  final String providerType;
  final ValueChanged<String> onSelectProvider;
  final LocalOutlookStatusModel? localOutlookStatus;

  const EmailProviderSelector({
    super.key,
    required this.providerType,
    required this.onSelectProvider,
    required this.localOutlookStatus,
  });

  Widget _buildProviderRadio(
      BuildContext context, String value, String title, IconData icon) {
    final isSelected = providerType == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => onSelectProvider(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.cobalt.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark
                    ? AppTheme.darkInputBackground
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppTheme.cobalt
                  : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? AppTheme.cobalt : Colors.grey),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? AppTheme.cobalt
                        : (isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal;
    final secTextColor =
        isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مزود خدمة البريد (Mail Provider)',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildProviderRadio(context, 'LOCAL_OUTLOOK',
                'Outlook جهازك (MAPI)', Icons.desktop_windows_rounded),
            const SizedBox(width: 8),
            _buildProviderRadio(
                context, 'GMAIL', 'Google Gmail', Icons.mail_outline),
            const SizedBox(width: 8),
            _buildProviderRadio(context, 'OUTLOOK', 'Office 365 / Outlook',
                Icons.business_outlined),
            const SizedBox(width: 8),
            _buildProviderRadio(
                context, 'CUSTOM', 'خادم مخصص (Custom)', Icons.dns_outlined),
          ],
        ),
        const SizedBox(height: 12),

        // Provider Guidance Note
        if (providerType == 'LOCAL_OUTLOOK')
          Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    AppTheme.cobalt.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.cobalt.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.laptop_windows_rounded,
                          color: AppTheme.cobalt, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تكامل مباشر مع تطبيق مايكروسوفت أوتلوك المثبت على هذا الجهاز',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFBAE6FD)
                                : const Color(0xFF0369A1),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.emerald),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 12, color: AppTheme.emerald),
                            SizedBox(width: 4),
                            Text(
                              'ربط MAPI مباشر',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.emerald,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اتصال تلقائي بحساب Outlook المفتوح حالياً بدون كلمات مرور أو إعدادات خوادم، مع تجاوز قيود أمان المؤسسة والمصادقة الثنائية تلقائياً.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : Colors.blueGrey.shade800,
                      height: 1.4,
                    ),
                  ),
                  if (localOutlookStatus?.available == true) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 15, color: secTextColor),
                          const SizedBox(width: 5),
                          Text(
                            localOutlookStatus?.userName ?? 'Ahmed Sorour',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: textColor),
                          ),
                          const SizedBox(width: 14),
                          Icon(Icons.alternate_email,
                              size: 15, color: secTextColor),
                          const SizedBox(width: 5),
                          Text(
                            localOutlookStatus?.emailAddress ??
                                'a.sorour@scas-egypt.com',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: textColor),
                          ),
                          const Spacer(),
                          const Icon(Icons.inbox_rounded,
                              size: 15, color: AppTheme.emerald),
                          const SizedBox(width: 5),
                          Text(
                            '${localOutlookStatus?.inboxCount ?? 186} رسالة بالصندوق',
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.emerald),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

        if (providerType == 'GMAIL')
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.amber.shade700.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لحسابات Gmail: يجب تفعيل التحقق بخطوتين (2-Step Verification) واستخراج "كلمة مرور التطبيقات (App Password)" من إعدادات أمان حساب Google لاستخدامها ككلمة سر.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFFDE68A)
                          : Colors.amber.shade900,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (providerType == 'OUTLOOK')
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  AppTheme.cobalt.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.cobalt.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لحسابات Outlook/Office 365: يدعم حسابات المؤسسات مع التحقق الأساسي أو App Password. تأكد من تفعيل بروتوكول Authenticated SMTP للمستخدم في مركز الإدارة.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFBAE6FD)
                          : const Color(0xFF0369A1),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
