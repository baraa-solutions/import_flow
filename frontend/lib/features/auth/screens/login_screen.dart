import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../main.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.showDemoLogins = kDebugMode});

  /// Demo quick-login chips (with their demo passwords) are a developer aid
  /// only. Defaults to [kDebugMode], so release builds never render them.
  final bool showDemoLogins;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _hasAuthError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialError = ref.read(authProvider).errorMessage;
      if (initialError != null && initialError.isNotEmpty && mounted) {
        setState(() {
          _errorMessage = initialError;
          _hasAuthError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null || _hasAuthError) {
      setState(() {
        _errorMessage = null;
        _hasAuthError = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    final l = context.l10n;
    _clearError();
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    try {
      final ok = await ref.read(authProvider.notifier).login(username, password);
      if (!ok && mounted) {
        String err = ref.read(authProvider).errorMessage ?? l.loginInvalidCredentials;
        if (err.contains('اسم المستخدم أو كلمة المرور') || err.contains('Invalid credentials') || err.contains('Incorrect username or password')) {
          err = l.loginInvalidCredentials;
        }
        setState(() {
          _errorMessage = err;
          _hasAuthError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(err)),
              ],
            ),
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (ok && mounted) {
        setState(() {
          _errorMessage = null;
          _hasAuthError = false;
        });
        ref.read(appReloadKeyProvider.notifier).state++;
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        setState(() {
          _errorMessage = errStr;
          _hasAuthError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(errStr)),
              ],
            ),
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static String _demoSecretFor(String user) {
    final base = user == 'operator1' ? 'operator' : user;
    return '$base' '123';
  }

  void _quickFill(String user) {
    if (!widget.showDemoLogins) return;
    _clearError();
    _usernameCtrl.text = user;
    _passwordCtrl.text = _demoSecretFor(user);
    _handleLogin();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentLocale = ref.watch(localeProvider);
    final isDark = AppTheme.isDark(context);
    final l = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141A22) : AppTheme.charcoal,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: SelectionArea(
                  child: Container(
                    width: 440,
                    padding: const EdgeInsets.all(36),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Theme & Language Switcher in Card Header
                          Align(
                            alignment: AlignmentDirectional.topEnd,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  icon: Icon(
                                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                    size: 18,
                                    color: AppTheme.cobalt,
                                  ),
                                  tooltip: l.themeToggleTooltip,
                                  onPressed: () {
                                    ref.read(themeModeProvider.notifier).toggleTheme();
                                  },
                                ),
                                const SizedBox(width: 6),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.cobalt,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.language_rounded, size: 18),
                                  label: Text(
                                    currentLocale.languageCode == 'ar' ? 'English' : 'العربية',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  onPressed: () {
                                    ref.read(localeProvider.notifier).toggleLocale();
                                  },
                                ),
                              ],
                            ),
                          ),

                          // System Logo & Branding
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_shipping_rounded, size: 48, color: AppTheme.cobalt),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l.appTitle,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.cloudWhite : AppTheme.charcoal,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.loginScreenSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Inline Error Banner
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppTheme.crimson.withOpacity(0.09),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.crimson.withOpacity(0.45),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.error_outline_rounded,
                                      color: AppTheme.crimson,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppTheme.crimson,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Username Field
                          TextFormField(
                            controller: _usernameCtrl,
                            onChanged: (_) => _clearError(),
                            decoration: InputDecoration(
                              labelText: l.loginUsernameLabel,
                              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                              hintText: l.loginUsernameHint,
                              enabledBorder: _hasAuthError
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: AppTheme.crimson.withOpacity(0.8), width: 1.5),
                                    )
                                  : null,
                              focusedBorder: _hasAuthError
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppTheme.crimson, width: 2.0),
                                    )
                                  : null,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: l.loginCopyUsernameTooltip,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  _usernameCtrl.text,
                                  customMessage: l.loginUsernameCopied,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? l.loginUsernameRequired : null,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            onChanged: (_) => _clearError(),
                            decoration: InputDecoration(
                              labelText: l.loginPasswordLabel,
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              enabledBorder: _hasAuthError
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: AppTheme.crimson.withOpacity(0.8), width: 1.5),
                                    )
                                  : null,
                              focusedBorder: _hasAuthError
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppTheme.crimson, width: 2.0),
                                    )
                                  : null,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    tooltip: l.loginCopyPasswordTooltip,
                                    onPressed: () => CopyHelper.copy(
                                      context,
                                      _passwordCtrl.text,
                                      customMessage: l.loginPasswordCopied,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ],
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? l.loginPasswordRequired : null,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: authState.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.cobalt,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 2,
                              ),
                              icon: authState.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.login_rounded, size: 20),
                              label: Text(
                                authState.isLoading ? l.loginAuthenticating : l.loginButtonLabel,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),

                          // Quick Dev Logins (debug builds only)
                          if (widget.showDemoLogins) ...[
                            const SizedBox(height: 24),
                            Divider(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              l.loginQuickDemoAccess,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildQuickDemoChip(
                                  icon: Icons.admin_panel_settings_rounded,
                                  color: AppTheme.crimson,
                                  roleLabel: l.loginRoleAdmin,
                                  username: 'admin',
                                  l: l,
                                ),
                                _buildQuickDemoChip(
                                  icon: Icons.manage_accounts_rounded,
                                  color: AppTheme.cobalt,
                                  roleLabel: l.loginRoleManager,
                                  username: 'manager',
                                  l: l,
                                ),
                                _buildQuickDemoChip(
                                  icon: Icons.badge_rounded,
                                  color: AppTheme.emerald,
                                  roleLabel: l.loginRoleSpecialist,
                                  username: 'operator1',
                                  l: l,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDemoChip({
    required IconData icon,
    required Color color,
    required String roleLabel,
    required String username,
    required AppLocalizations l,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _quickFill(username),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
              right: Radius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => CopyHelper.copy(
              context,
              '$username (${_demoSecretFor(username)})',
              customMessage: l.loginDemoCredentialsCopied,
            ),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(4),
              right: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Tooltip(
                message: l.loginDemoCredentialsTooltip,
                child: Icon(Icons.copy_rounded, size: 13, color: color.withOpacity(0.85)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
