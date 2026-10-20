import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/email_settings_model.dart';
import '../providers/email_settings_provider.dart';
import 'email_sync_review_dialog.dart';

class EmailSettingsDialog extends ConsumerStatefulWidget {
  const EmailSettingsDialog({super.key});

  /// Email server settings are admin-only on the backend (403 otherwise).
  static bool canAccess(UserModel? user) => user?.canManageEmailSettings ?? false;

  static Future<void> show(BuildContext context) async {
    final user = ProviderScope.containerOf(context, listen: false).read(authProvider).user;
    if (!canAccess(user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.adminOnlyFeatureMessage),
          backgroundColor: AppTheme.orange,
        ),
      );
      return;
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const EmailSettingsDialog(),
    );
  }

  @override
  ConsumerState<EmailSettingsDialog> createState() => _EmailSettingsDialogState();
}

class _EmailSettingsDialogState extends ConsumerState<EmailSettingsDialog> {
  final _formKey = GlobalKey<FormState>();

  String _providerType = 'GMAIL';
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  final _imapHostController = TextEditingController(text: 'imap.gmail.com');
  final _imapPortController = TextEditingController(text: '993');
  bool _imapUseSsl = true;

  final _smtpHostController = TextEditingController(text: 'smtp.gmail.com');
  final _smtpPortController = TextEditingController(text: '587');
  bool _smtpUseTls = true;
  bool _smtpUseSsl = false;

  bool _autoFetchEnabled = false;
  int _fetchIntervalMinutes = 15;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingSettings();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _imapHostController.dispose();
    _imapPortController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    super.dispose();
  }

  void _loadExistingSettings() async {
    final outlookInfo = await ref.read(emailSettingsProvider.notifier).checkLocalOutlookStatus();
    final settings = ref.read(emailSettingsProvider).settings;
    if (settings != null) {
      setState(() {
        _providerType = settings.providerType;
        _emailController.text = settings.emailAddress;
        _usernameController.text = settings.username;
        _displayNameController.text = settings.senderDisplayName;
        _imapHostController.text = settings.imapHost;
        _imapPortController.text = settings.imapPort.toString();
        _imapUseSsl = settings.imapUseSsl;
        _smtpHostController.text = settings.smtpHost;
        _smtpPortController.text = settings.smtpPort.toString();
        _smtpUseTls = settings.smtpUseTls;
        _smtpUseSsl = settings.smtpUseSsl;
        _autoFetchEnabled = settings.autoFetchEnabled;
        _fetchIntervalMinutes = settings.fetchIntervalMinutes;
      });
    } else {
      if (outlookInfo?.available == true) {
        _applyProviderDefaults('LOCAL_OUTLOOK');
      } else {
        _applyProviderDefaults('GMAIL');
      }
    }
  }

  void _applyProviderDefaults(String provider) {
    setState(() {
      _providerType = provider;
      final outlookInfo = ref.read(emailSettingsProvider).localOutlookStatus;
      if (provider == 'LOCAL_OUTLOOK') {
        _emailController.text = outlookInfo?.emailAddress ?? 'a.sorour@scas-egypt.com';
        _usernameController.text = outlookInfo?.userName ?? 'Ahmed Sorour';
        _displayNameController.text = '${outlookInfo?.userName ?? "Ahmed Sorour"} - Sorour Logistics';
        _imapHostController.text = 'localhost';
        _imapPortController.text = '0';
        _smtpHostController.text = 'localhost';
        _smtpPortController.text = '0';
      } else if (provider == 'GMAIL') {
        _imapHostController.text = 'imap.gmail.com';
        _imapPortController.text = '993';
        _imapUseSsl = true;
        _smtpHostController.text = 'smtp.gmail.com';
        _smtpPortController.text = '587';
        _smtpUseTls = true;
        _smtpUseSsl = false;
      } else if (provider == 'OUTLOOK') {
        _imapHostController.text = 'outlook.office365.com';
        _imapPortController.text = '993';
        _imapUseSsl = true;
        _smtpHostController.text = 'smtp.office365.com';
        _smtpPortController.text = '587';
        _smtpUseTls = true;
        _smtpUseSsl = false;
      }
    });
  }

  Future<void> _handleTestConnection() async {
    if (!_formKey.currentState!.validate()) return;

    final testPayload = {
      'provider_type': _providerType,
      'email_address': _emailController.text.trim(),
      'username': _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'imap_host': _imapHostController.text.trim().isNotEmpty ? _imapHostController.text.trim() : 'localhost',
      'imap_port': int.tryParse(_imapPortController.text.trim()) ?? 0,
      'imap_use_ssl': _imapUseSsl,
      'smtp_host': _smtpHostController.text.trim().isNotEmpty ? _smtpHostController.text.trim() : 'localhost',
      'smtp_port': int.tryParse(_smtpPortController.text.trim()) ?? 0,
      'smtp_use_tls': _smtpUseTls,
      'smtp_use_ssl': _smtpUseSsl,
    };

    await ref.read(emailSettingsProvider.notifier).testConnection(testPayload);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final currentSettings = ref.read(emailSettingsProvider).settings;
    final model = EmailSettingsModel(
      settingsId: currentSettings?.settingsId,
      providerType: _providerType,
      emailAddress: _emailController.text.trim(),
      username: _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : _emailController.text.trim(),
      senderDisplayName: _displayNameController.text.trim(),
      imapHost: _imapHostController.text.trim().isNotEmpty ? _imapHostController.text.trim() : 'localhost',
      imapPort: int.tryParse(_imapPortController.text.trim()) ?? 0,
      imapUseSsl: _imapUseSsl,
      smtpHost: _smtpHostController.text.trim().isNotEmpty ? _smtpHostController.text.trim() : 'localhost',
      smtpPort: int.tryParse(_smtpPortController.text.trim()) ?? 0,
      smtpUseTls: _smtpUseTls,
      smtpUseSsl: _smtpUseSsl,
      autoFetchEnabled: _autoFetchEnabled,
      fetchIntervalMinutes: _fetchIntervalMinutes,
    );

    final success = await ref.read(emailSettingsProvider.notifier).saveSettings(
          model,
          newPassword: _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : null,
        );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إعدادات البريد بنجاح'),
          backgroundColor: AppTheme.emerald,
        ),
      );
    } else if (mounted) {
      final error = ref.read(emailSettingsProvider).error;
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.crimson),
        );
      }
    }
  }

  Future<void> _handleFetchInbox() async {
    final result = await ref.read(emailSettingsProvider.notifier).fetchInboxNow();
    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.matchedFilesCount > 0 ? AppTheme.emerald : AppTheme.cobalt,
        ),
      );
      if (result.matchedFilesCount > 0) {
        await EmailSyncReviewDialog.show(context, result: result);
      }
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = h >= 12 ? 'م' : 'ص';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$d/$m/$y $hour12:$min $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(emailSettingsProvider);

    final bgCardColor = isDark ? AppTheme.darkInputBackground : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal;
    final secTextColor = isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 820,
          height: 720,
          padding: const EdgeInsets.all(24),
          child: Column(
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.settings_suggest_rounded, color: AppTheme.cobalt, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعدادات ربط البريد الإلكتروني (IMAP / SMTP)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تكوين خادم الاستقبال لمتابعة إشعارات الوصول وخادم الإرسال لتنبيهات الشحن',
                        style: TextStyle(fontSize: 12, color: secTextColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: secTextColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider Selector
                      Text(
                        'مزود خدمة البريد (Mail Provider)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildProviderRadio('LOCAL_OUTLOOK', 'Outlook جهازك (MAPI)', Icons.desktop_windows_rounded),
                          const SizedBox(width: 8),
                          _buildProviderRadio('GMAIL', 'Google Gmail', Icons.mail_outline),
                          const SizedBox(width: 8),
                          _buildProviderRadio('OUTLOOK', 'Office 365 / Outlook', Icons.business_outlined),
                          const SizedBox(width: 8),
                          _buildProviderRadio('CUSTOM', 'خادم مخصص (Custom)', Icons.dns_outlined),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Provider Guidance Note
                      if (_providerType == 'LOCAL_OUTLOOK')
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withOpacity(isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.cobalt.withOpacity(0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.laptop_windows_rounded, color: AppTheme.cobalt, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'تكامل مباشر مع تطبيق مايكروسوفت أوتلوك المثبت على هذا الجهاز',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.emerald),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.emerald),
                                          SizedBox(width: 4),
                                          Text(
                                            'ربط MAPI مباشر',
                                            style: TextStyle(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.bold),
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
                                    color: isDark ? AppTheme.darkTextSecondary : Colors.blueGrey.shade800,
                                    height: 1.4,
                                  ),
                                ),
                                if (state.localOutlookStatus?.available == true) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkSurface : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 15, color: secTextColor),
                                        const SizedBox(width: 5),
                                        Text(
                                          state.localOutlookStatus?.userName ?? 'Ahmed Sorour',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                                        ),
                                        const SizedBox(width: 14),
                                        Icon(Icons.alternate_email, size: 15, color: secTextColor),
                                        const SizedBox(width: 5),
                                        Text(
                                          state.localOutlookStatus?.emailAddress ?? 'a.sorour@scas-egypt.com',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.inbox_rounded, size: 15, color: AppTheme.emerald),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${state.localOutlookStatus?.inboxCount ?? 186} رسالة بالصندوق',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      if (_providerType == 'GMAIL')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
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
                                    color: isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_providerType == 'OUTLOOK')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withOpacity(isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'لحسابات Outlook/Office 365: يدعم حسابات المؤسسات مع التحقق الأساسي أو App Password. تأكد من تفعيل بروتوكول Authenticated SMTP للمستخدم في مركز الإدارة.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Credentials Grid
                      if (_providerType == 'LOCAL_OUTLOOK') ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                style: TextStyle(color: textColor, fontSize: 13),
                                decoration: _inputDecoration('عنوان البريد الإلكتروني (Email Address)', isDark),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                                  if (!v.contains('@')) return 'صيغة بريد غير صحيحة';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _displayNameController,
                                style: TextStyle(color: textColor, fontSize: 13),
                                decoration: _inputDecoration('اسم مرسل الرسائل (Sender Display Name)', isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkInputBackground : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.emerald),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'المصادقة نشطة: لا حاجة لإدخال كلمة مرور — يتم الاعتماد كلياً على جلسة نظام Windows وتطبيق Outlook المفتوح على هذا الجهاز.',
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                style: TextStyle(color: textColor, fontSize: 13),
                                decoration: _inputDecoration('عنوان البريد الإلكتروني (Email Address)', isDark),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                                  if (!v.contains('@')) return 'صيغة بريد غير صحيحة';
                                  return null;
                                },
                                onChanged: (v) {
                                  if (_usernameController.text.isEmpty || _usernameController.text == v) {
                                    _usernameController.text = v;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _usernameController,
                                style: TextStyle(color: textColor, fontSize: 13),
                                decoration: _inputDecoration('اسم المستخدم (Username)', isDark),
                                validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المستخدم' : null,
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
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: textColor, fontSize: 13),
                                decoration: _inputDecoration(
                                  state.settings?.hasPassword == true
                                      ? 'كلمة المرور (اتركه فارغاً للإبقاء على الحالية)'
                                      : 'كلمة المرور / كلمة مرور التطبيقات',
                                  isDark,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      size: 18,
                                      color: secTextColor,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (_providerType == 'LOCAL_OUTLOOK') return null;
                                  if (state.settings?.hasPassword != true && (v == null || v.trim().isEmpty)) {
                                    return 'يرجى إدخال كلمة المرور';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _displayNameController,
                                style: TextStyle(color: textColor, fontSize: 13),
                                decoration: _inputDecoration('اسم مرسل الرسائل (Sender Display Name)', isDark),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Server Configuration Panel
                      if (_providerType != 'LOCAL_OUTLOOK') ...[
                        const SizedBox(height: 20),
                        Container(
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
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                              ),
                              const SizedBox(height: 12),

                              // IMAP Config
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 90,
                                    child: Text('IMAP (وارد):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _imapHostController,
                                      enabled: _providerType == 'CUSTOM',
                                      style: TextStyle(color: textColor, fontSize: 12),
                                      decoration: _compactInputDecoration('المضيف (Host)', isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: _imapPortController,
                                      enabled: _providerType == 'CUSTOM',
                                      style: TextStyle(color: textColor, fontSize: 12),
                                      decoration: _compactInputDecoration('المنفذ', isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _imapUseSsl,
                                        onChanged: _providerType == 'CUSTOM' ? (v) => setState(() => _imapUseSsl = v ?? true) : null,
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
                                    child: Text('SMTP (صادر):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _smtpHostController,
                                      enabled: _providerType == 'CUSTOM',
                                      style: TextStyle(color: textColor, fontSize: 12),
                                      decoration: _compactInputDecoration('المضيف (Host)', isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: _smtpPortController,
                                      enabled: _providerType == 'CUSTOM',
                                      style: TextStyle(color: textColor, fontSize: 12),
                                      decoration: _compactInputDecoration('المنفذ', isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _smtpUseTls,
                                        onChanged: _providerType == 'CUSTOM' ? (v) => setState(() => _smtpUseTls = v ?? true) : null,
                                        activeColor: AppTheme.cobalt,
                                      ),
                                      const Text('STARTTLS', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Auto Fetch Polling Options
                      Row(
                        children: [
                          Switch(
                            value: _autoFetchEnabled,
                            onChanged: (v) => setState(() => _autoFetchEnabled = v),
                            activeColor: AppTheme.cobalt,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تفعيل الفحص الدوري التلقائي لصندوق الوارد',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('كل: ', style: TextStyle(fontSize: 12, color: secTextColor)),
                          DropdownButton<int>(
                            value: _fetchIntervalMinutes,
                            dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5 دقائق')),
                              DropdownMenuItem(value: 15, child: Text('15 دقيقة')),
                              DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
                              DropdownMenuItem(value: 60, child: Text('ساعة واحدة')),
                            ],
                            onChanged: _autoFetchEnabled ? (v) => setState(() => _fetchIntervalMinutes = v ?? 15) : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Test Results Card
                      if (state.testResult != null) _buildTestResultCard(state.testResult!, isDark),

                      // Last Sync Info
                      if (state.settings?.lastSyncAt != null)
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkInputBackground : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.history_rounded, size: 16, color: AppTheme.cobalt),
                                const SizedBox(width: 8),
                                Text(
                                  'آخر فحص: ${_formatDateTime(state.settings?.lastSyncAt)}',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (state.settings?.lastSyncStatus == 'SUCCESS' ? AppTheme.emerald : AppTheme.orange).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    state.settings?.lastSyncStatus == 'SUCCESS' ? 'ناجح' : (state.settings?.lastSyncStatus ?? '-'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: state.settings?.lastSyncStatus == 'SUCCESS' ? AppTheme.emerald : AppTheme.orange,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.settings?.lastSyncMessage ?? '',
                                    style: TextStyle(fontSize: 11, color: secTextColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (state.fetchResult != null && state.fetchResult!.matchedFilesCount > 0) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => EmailSyncReviewDialog.show(context, result: state.fetchResult!),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.cobalt.withOpacity(0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.rule_folder_rounded, size: 13, color: AppTheme.cobalt),
                                          SizedBox(width: 4),
                                          Text(
                                            'مراجعة وتوجيه المهام 📋',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Action Buttons Footer
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Test Connection Button
                      OutlinedButton.icon(
                        onPressed: state.isTesting ? null : _handleTestConnection,
                        icon: state.isTesting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check_rounded, size: 16),
                        label: Text(state.isTesting ? 'جارٍ الفحص...' : 'اختبار الاتصال', style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cobalt,
                          side: const BorderSide(color: AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sync Now Button
                      OutlinedButton.icon(
                        onPressed: state.isFetching ? null : _handleFetchInbox,
                        icon: state.isFetching
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync_rounded, size: 16),
                        label: Text(state.isFetching ? 'جارٍ المزامنة...' : 'فحص الصندوق الآن', style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.emerald,
                          side: const BorderSide(color: AppTheme.emerald),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Close Button
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('إغلاق', style: TextStyle(color: secTextColor, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),

                      // Save Button
                      ElevatedButton.icon(
                        onPressed: state.isSaving ? null : _handleSave,
                        icon: state.isSaving
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded, size: 16),
                        label: Text(state.isSaving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات', style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildProviderRadio(String value, String title, IconData icon) {
    final isSelected = _providerType == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => _applyProviderDefaults(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.cobalt.withOpacity(isDark ? 0.25 : 0.12)
                : (isDark ? AppTheme.darkInputBackground : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.cobalt : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppTheme.cobalt : Colors.grey),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.cobalt : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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

  Widget _buildTestResultCard(EmailConnectionTestResultModel res, bool isDark) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: res.overallSuccess
              ? AppTheme.emerald.withOpacity(isDark ? 0.2 : 0.1)
              : AppTheme.crimson.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: res.overallSuccess ? AppTheme.emerald : AppTheme.crimson,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  res.overallSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: res.overallSuccess ? AppTheme.emerald : AppTheme.crimson,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  res.overallSuccess ? 'نجح اختبار الاتصال بالمخدمين بالكامل' : 'فشل أحد اختبارات الاتصال',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: res.overallSuccess ? AppTheme.emerald : AppTheme.crimson,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• خادم الاستقبال (IMAP): ${res.imapMessage}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• خادم الإرسال (SMTP): ${res.smtpMessage}',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
      filled: true,
      fillColor: isDark ? AppTheme.darkInputBackground : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
      ),
    );
  }

  InputDecoration _compactInputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
      filled: true,
      fillColor: isDark ? AppTheme.darkInputBackground : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
      ),
    );
  }
}
