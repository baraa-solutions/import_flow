import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';
import '../services/financial_export_service.dart';

class PaymentEmailShareDialog extends StatefulWidget {
  final PaymentRequestModel payment;

  const PaymentEmailShareDialog({
    super.key,
    required this.payment,
  });

  static Future<void> show(
    BuildContext context, {
    required PaymentRequestModel payment,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PaymentEmailShareDialog(payment: payment),
    );
  }

  @override
  State<PaymentEmailShareDialog> createState() =>
      _PaymentEmailShareDialogState();
}

class _PaymentEmailShareDialogState extends State<PaymentEmailShareDialog> {
  late final TextEditingController _toController;
  late final String _subject;
  late final String _body;

  @override
  void initState() {
    super.initState();
    _toController = TextEditingController();
    _subject =
        FinancialExportService.generatePaymentEmailSubject(widget.payment);
    _body = FinancialExportService.generatePaymentEmailBody(widget.payment);
  }

  @override
  void dispose() {
    _toController.dispose();
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
          const Icon(Icons.email, color: AppTheme.orange),
          const SizedBox(width: 8),
          Text(
            l.sendPaymentEmailTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _toController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                decoration: InputDecoration(
                  labelText: l.recipientEmailLabel,
                  hintText: 'accounting@company.com',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : AppTheme.charcoalSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.emailSubjectLabel(_subject),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal,
                      ),
                    ),
                    const Divider(height: 12),
                    SelectableText(
                      _body,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.charcoal,
                      ),
                    ),
                  ],
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
            CopyHelper.copy(context, 'Subject: $_subject\n\n$_body');
          },
        ),
        AppButton(
          label: l.openEmailClientBtn,
          variant: AppButtonVariant.primary,
          icon: Icons.send,
          onPressed: () {
            final to = _toController.text.trim();
            final encodedSubject = Uri.encodeComponent(_subject);
            final encodedBody = Uri.encodeComponent(_body);
            final url = 'mailto:$to?subject=$encodedSubject&body=$encodedBody';
            FinancialExportService.launchUrlNative(url);
            Navigator.pop(context);
          },
        ),
      ],
    ),
    );
  }
}
