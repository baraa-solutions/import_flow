import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class EmailServerEndpointsCard extends StatelessWidget {
  final String providerType;
  final TextEditingController imapHostController;
  final TextEditingController imapPortController;
  final bool imapUseSsl;
  final ValueChanged<bool?>? onToggleImapSsl;
  final TextEditingController smtpHostController;
  final TextEditingController smtpPortController;
  final bool smtpUseTls;
  final ValueChanged<bool?>? onToggleSmtpTls;

  const EmailServerEndpointsCard({
    super.key,
    required this.providerType,
    required this.imapHostController,
    required this.imapPortController,
    required this.imapUseSsl,
    required this.onToggleImapSsl,
    required this.smtpHostController,
    required this.smtpPortController,
    required this.smtpUseTls,
    required this.onToggleSmtpTls,
  });

  InputDecoration _compactInputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontSize: 11,
          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
      filled: true,
      fillColor:
          isDark ? AppTheme.darkInputBackground : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCardColor =
        isDark ? AppTheme.darkInputBackground : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إعدادات المضيف والمنافذ (Server Endpoints)',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
          ),
          const SizedBox(height: 12),

          // IMAP Config
          Row(
            children: [
              const SizedBox(
                width: 90,
                child: Text('IMAP (وارد):',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: imapHostController,
                  enabled: providerType == 'CUSTOM',
                  style: TextStyle(color: textColor, fontSize: 12),
                  decoration: _compactInputDecoration('المضيف (Host)', isDark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: imapPortController,
                  enabled: providerType == 'CUSTOM',
                  style: TextStyle(color: textColor, fontSize: 12),
                  decoration: _compactInputDecoration('المنفذ', isDark),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Checkbox(
                    value: imapUseSsl,
                    onChanged:
                        providerType == 'CUSTOM' ? onToggleImapSsl : null,
                    activeColor: AppTheme.cobalt,
                  ),
                  const Text('SSL/TLS', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // SMTP Config
          Row(
            children: [
              const SizedBox(
                width: 90,
                child: Text('SMTP (صادر):',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: smtpHostController,
                  enabled: providerType == 'CUSTOM',
                  style: TextStyle(color: textColor, fontSize: 12),
                  decoration: _compactInputDecoration('المضيف (Host)', isDark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: smtpPortController,
                  enabled: providerType == 'CUSTOM',
                  style: TextStyle(color: textColor, fontSize: 12),
                  decoration: _compactInputDecoration('المنفذ', isDark),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Checkbox(
                    value: smtpUseTls,
                    onChanged:
                        providerType == 'CUSTOM' ? onToggleSmtpTls : null,
                    activeColor: AppTheme.cobalt,
                  ),
                  const Text('STARTTLS', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
