import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

/// Obscured password [TextFormField] with a show/hide toggle.
class PasswordInputField extends StatefulWidget {
  const PasswordInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.icon = Icons.lock_outline_rounded,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final IconData icon;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      enabled: widget.enabled,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, size: 20),
        suffixIcon: IconButton(
          tooltip: _obscure ? l.forcePwdShowPassword : l.forcePwdHidePassword,
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
