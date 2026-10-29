import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';
import '../services/financial_export_service.dart';

class PaymentWhatsAppShareDialog extends StatefulWidget {
  final PaymentRequestModel payment;

  const PaymentWhatsAppShareDialog({
    super.key,
    required this.payment,
  });

  static Future<void> show(
    BuildContext context, {
    required PaymentRequestModel payment,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PaymentWhatsAppShareDialog(payment: payment),
    );
  }

  @override
  State<PaymentWhatsAppShareDialog> createState() =>
      _PaymentWhatsAppShareDialogState();
}

class _PaymentWhatsAppShareDialogState
    extends State<PaymentWhatsAppShareDialog> {
  late final TextEditingController _phoneController;
  late final String _text;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _text = FinancialExportService.generatePaymentWhatsAppText(widget.payment);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      title: Row(
        children: [
          const Icon(Icons.chat, color: AppTheme.emerald),
          const SizedBox(width: 8),
          Text(
            l.sendPaymentWhatsAppTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                decoration: InputDecoration(
                  labelText: l.whatsAppNumberLabel,
                  hintText: l.whatsAppNumberHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_android),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.messagePreviewLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color:
                      isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : AppTheme.cloudWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                ),
                child: SelectableText(
                  _text,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l.cancel,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: l.copySummaryBtn,
          variant: AppButtonVariant.secondary,
          icon: Icons.copy,
          onPressed: () {
            CopyHelper.copy(context, _text);
          },
        ),
        AppButton(
          label: l.openWhatsAppBtn,
          variant: AppButtonVariant.success,
          icon: Icons.open_in_new,
          onPressed: () {
            final phone = _phoneController.text
                .trim()
                .replaceAll(RegExp(r'[^0-9]'), '');
            final encoded = Uri.encodeComponent(_text);
            final url = phone.isNotEmpty
                ? 'https://wa.me/$phone?text=$encoded'
                : 'https://wa.me/?text=$encoded';
            FinancialExportService.launchUrlNative(url);
            Navigator.pop(context);
          },
        ),
      ],
    ),
    );
  }
}
