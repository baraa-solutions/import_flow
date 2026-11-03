import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/email_settings_model.dart';
import '../providers/email_settings_provider.dart';
import 'email_settings/email_credentials_section.dart';
import 'email_settings/email_provider_selector.dart';
import 'email_settings/email_server_endpoints_card.dart';
import 'email_settings/email_settings_footer.dart';
import 'email_settings/email_settings_header.dart';
import 'email_settings/email_sync_status_section.dart';
import 'email_sync_review_dialog.dart';

class EmailSettingsDialog extends ConsumerStatefulWidget {
  const EmailSettingsDialog({super.key});

  /// Email server settings are admin-only on the backend (403 otherwise).
  static bool canAccess(UserModel? user) =>
      user?.canManageEmailSettings ?? false;

  static Future<void> show(BuildContext context) async {
    final user = ProviderScope.containerOf(context, listen: false)
        .read(authProvider)
        .user;
    if (!canAccess(user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.adminOnlyFeatureMessage,
            severity: AppSeverity.warning),
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
  ConsumerState<EmailSettingsDialog> createState() =>
      _EmailSettingsDialogState();
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
    final outlookInfo = await ref
        .read(emailSettingsProvider.notifier)
        .checkLocalOutlookStatus();
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
      final outlookInfo =
          ref.read(emailSettingsProvider).localOutlookStatus;
      if (provider == 'LOCAL_OUTLOOK') {
        _emailController.text =
            outlookInfo?.emailAddress ?? 'a.sorour@scas-egypt.com';
        _usernameController.text =
            outlookInfo?.userName ?? 'Ahmed Sorour';
        _displayNameController.text =
            '${outlookInfo?.userName ?? "Ahmed Sorour"} - Sorour Logistics';
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
      'imap_host': _imapHostController.text.trim().isNotEmpty
          ? _imapHostController.text.trim()
          : 'localhost',
      'imap_port': int.tryParse(_imapPortController.text.trim()) ?? 0,
      'imap_use_ssl': _imapUseSsl,
      'smtp_host': _smtpHostController.text.trim().isNotEmpty
          ? _smtpHostController.text.trim()
          : 'localhost',
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
      imapHost: _imapHostController.text.trim().isNotEmpty
          ? _imapHostController.text.trim()
          : 'localhost',
      imapPort: int.tryParse(_imapPortController.text.trim()) ?? 0,
      imapUseSsl: _imapUseSsl,
      smtpHost: _smtpHostController.text.trim().isNotEmpty
          ? _smtpHostController.text.trim()
          : 'localhost',
      smtpPort: int.tryParse(_smtpPortController.text.trim()) ?? 0,
      smtpUseTls: _smtpUseTls,
      smtpUseSsl: _smtpUseSsl,
      autoFetchEnabled: _autoFetchEnabled,
      fetchIntervalMinutes: _fetchIntervalMinutes,
    );

    final success =
        await ref.read(emailSettingsProvider.notifier).saveSettings(
              model,
              newPassword: _passwordController.text.trim().isNotEmpty
                  ? _passwordController.text.trim()
                  : null,
            );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'تم حفظ إعدادات البريد بنجاح',
            severity: AppSeverity.success),
      );
    } else if (mounted) {
      final error = ref.read(emailSettingsProvider).error;
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, error, severity: AppSeverity.danger),
        );
      }
    }
  }

  Future<void> _handleFetchInbox() async {
    final result =
        await ref.read(emailSettingsProvider.notifier).fetchInboxNow();
    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, result.message,
            severity: AppSeverity.success),
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
              EmailSettingsHeader(
                onClose: () => Navigator.of(context).pop(),
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
                        EmailProviderSelector(
                          providerType: _providerType,
                          onSelectProvider: _applyProviderDefaults,
                          localOutlookStatus: state.localOutlookStatus,
                        ),
                        const SizedBox(height: 16),

                        // Credentials Grid
                        EmailCredentialsSection(
                          providerType: _providerType,
                          emailController: _emailController,
                          displayNameController: _displayNameController,
                          usernameController: _usernameController,
                          passwordController: _passwordController,
                          hasExistingPassword:
                              state.settings?.hasPassword == true,
                          obscurePassword: _obscurePassword,
                          onToggleObscurePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),

                        // Server Configuration Panel
                        if (_providerType != 'LOCAL_OUTLOOK') ...[
                          const SizedBox(height: 20),
                          EmailServerEndpointsCard(
                            providerType: _providerType,
                            imapHostController: _imapHostController,
                            imapPortController: _imapPortController,
                            imapUseSsl: _imapUseSsl,
                            onToggleImapSsl: (v) =>
                                setState(() => _imapUseSsl = v ?? true),
                            smtpHostController: _smtpHostController,
                            smtpPortController: _smtpPortController,
                            smtpUseTls: _smtpUseTls,
                            onToggleSmtpTls: (v) =>
                                setState(() => _smtpUseTls = v ?? true),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Polling & Sync Status
                        EmailSyncStatusSection(
                          autoFetchEnabled: _autoFetchEnabled,
                          fetchIntervalMinutes: _fetchIntervalMinutes,
                          onToggleAutoFetch: (v) =>
                              setState(() => _autoFetchEnabled = v),
                          onChangeFetchInterval: (v) => setState(
                              () => _fetchIntervalMinutes = v ?? 15),
                          testResult: state.testResult,
                          settings: state.settings,
                          fetchResult: state.fetchResult,
                          formatDateTime: _formatDateTime,
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
              EmailSettingsFooter(
                isTesting: state.isTesting,
                onTestConnection: _handleTestConnection,
                isFetching: state.isFetching,
                onFetchInbox: _handleFetchInbox,
                isSaving: state.isSaving,
                onSave: _handleSave,
                onClose: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
