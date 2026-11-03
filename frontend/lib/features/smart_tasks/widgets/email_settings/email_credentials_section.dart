import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class EmailCredentialsSection extends StatelessWidget {
  final String providerType;
  final TextEditingController emailController;
  final TextEditingController displayNameController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool hasExistingPassword;
  final bool obscurePassword;
  final VoidCallback onToggleObscurePassword;

  const EmailCredentialsSection({
    super.key,
    required this.providerType,
    required this.emailController,
    required this.displayNameController,
    required this.usernameController,
    required this.passwordController,
    required this.hasExistingPassword,
    required this.obscurePassword,
    required this.onToggleObscurePassword,
  });

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
      filled: true,
      fillColor:
          isDark ? AppTheme.darkInputBackground : const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
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

    if (providerType == 'LOCAL_OUTLOOK') {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: emailController,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: _inputDecoration(
                      'عنوان البريد الإلكتروني (Email Address)', isDark),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني';
                    }
                    if (!v.contains('@')) return 'صيغة بريد غير صحيحة';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: displayNameController,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: _inputDecoration(
                      'اسم مرسل الرسائل (Sender Display Name)', isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkInputBackground
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 18, color: AppTheme.emerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'المصادقة نشطة: لا حاجة لإدخال كلمة مرور — يتم الاعتماد كلياً على جلسة نظام Windows وتطبيق Outlook المفتوح على هذا الجهاز.',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: emailController,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: _inputDecoration(
                    'عنوان البريد الإلكتروني (Email Address)', isDark),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'يرجى إدخال البريد الإلكتروني';
                  }
                  if (!v.contains('@')) return 'صيغة بريد غير صحيحة';
                  return null;
                },
                onChanged: (v) {
                  if (usernameController.text.isEmpty ||
                      usernameController.text == v) {
                    usernameController.text = v;
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: usernameController,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration:
                    _inputDecoration('اسم المستخدم (Username)', isDark),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'يرجى إدخال اسم المستخدم'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: _inputDecoration(
                  hasExistingPassword
                      ? 'كلمة المرور (اتركه فارغاً للإبقاء على الحالية)'
                      : 'كلمة المرور / كلمة مرور التطبيقات',
                  isDark,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                      color: secTextColor,
                    ),
                    onPressed: onToggleObscurePassword,
                  ),
                ),
                validator: (v) {
                  if (providerType == 'LOCAL_OUTLOOK') return null;
                  if (!hasExistingPassword &&
                      (v == null || v.trim().isEmpty)) {
                    return 'يرجى إدخال كلمة المرور';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: displayNameController,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: _inputDecoration(
                    'اسم مرسل الرسائل (Sender Display Name)', isDark),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
