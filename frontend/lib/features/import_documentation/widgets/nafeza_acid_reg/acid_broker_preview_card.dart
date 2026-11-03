import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import 'acid_broker_message_generator.dart';

class AcidBrokerPreviewCard extends StatelessWidget {
  final AcidBrokerMessageData data;

  const AcidBrokerPreviewCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final whatsAppMsg = AcidBrokerMessageGenerator.buildWhatsAppMessage(data);
    final englishMsg = AcidBrokerMessageGenerator.buildEnglishRequestMessage(data);
    final emailMsg = AcidBrokerMessageGenerator.buildEmailMessage(data);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.emeraldLight : AppTheme.successBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.wcagEmerald.withValues(alpha: 0.5) : AppTheme.emeraldBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.brokerDispatchMessageTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.brokerDispatchMessageSub,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: l.copyArabicWhatsApp,
                onPressed: () {
                  CopyHelper.copy(context, whatsAppMsg, customMessage: l.whatsAppMessageCopied);
                },
                variant: AppButtonVariant.success,
                icon: Icons.copy,
              ),
              AppButton(
                label: l.copyEnglishRequest,
                onPressed: () {
                  CopyHelper.copy(context, englishMsg, customMessage: l.acidRequestCopied);
                },
                icon: Icons.language,
              ),
              AppButton(
                label: l.emailTemplateButton,
                onPressed: () {
                  CopyHelper.copy(context, emailMsg, customMessage: l.emailTemplateCopied);
                },
                variant: AppButtonVariant.secondary,
                icon: Icons.email_outlined,
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.emeraldBorder),
            ),
            child: SelectableText(
              isAr ? whatsAppMsg : englishMsg,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
