import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool isRequired;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;

  /// Direction of the typed value. Pass [TextDirection.ltr] for codes (HS,
  /// ACID, container, B/L, SWIFT, IBAN) and numbers so they stay readable in
  /// Arabic. Null follows the ambient [Directionality]. The label keeps the
  /// ambient direction either way.
  final TextDirection? textDirection;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.isRequired = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.validator,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    // Default validation if isRequired is true and no custom validator provided
    final effectiveValidator = validator ?? (isRequired
        ? (value) {
            if (value == null || value.trim().isEmpty) {
              return context.l10n.requiredField;
            }
            return null;
          }
        : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
      enabled: enabled,
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textDirection: textDirection,
          validator: effectiveValidator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryOf(context)),
          decoration: InputDecoration(
            hintText: hint ?? context.l10n.enterFieldHint(label),
            prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.textSecondaryOf(context)) : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
