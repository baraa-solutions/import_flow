import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import '../localization/app_localizations.dart';
import '../localization/app_localizations_ar.dart';
import '../theme/app_theme.dart';
import 'copyable_data_helper.dart';

class ValidationIssueItem {
  final String fieldName;
  final String issueDescription;
  final String? recommendation;
  final bool isBlocking;
  final VoidCallback? onFix;

  ValidationIssueItem({
    required this.fieldName,
    required this.issueDescription,
    this.recommendation,
    this.isBlocking = false,
    this.onFix,
  });
}

class ParsedErrorInfo {
  final String summary;
  final List<ValidationIssueItem> validationIssues;
  final List<String> errorPoints;
  final String rawTechnicalLog;
  final bool isConnectionError;

  ParsedErrorInfo({
    required this.summary,
    required this.validationIssues,
    required this.errorPoints,
    required this.rawTechnicalLog,
    this.isConnectionError = false,
  });
}

class ErrorFormatter {
  static ParsedErrorInfo parse(
    dynamic error, {
    String? defaultMessage,
    List<ValidationIssueItem>? customIssues,
    AppLocalizations? l10n,
  }) {
    final loc = l10n ?? const AppLocalizationsAr();
    final points = <String>[];
    final issues = <ValidationIssueItem>[...(customIssues ?? [])];
    String summary = defaultMessage ?? loc.errorDefaultSummary;
    String rawLog = error.toString();
    bool isConn = false;

    if (error is DioException) {
      final res = error.response;
      if (res?.data != null) {
        final data = res!.data;
        if (data is Map) {
          final detail = data['detail'];
          if (detail is String) {
            summary = detail;
            points.add(detail);
            issues.add(ValidationIssueItem(
              fieldName: loc.errorServerResponseField,
              issueDescription: detail,
              recommendation: loc.errorServerResponseRecommendation,
              isBlocking: true,
            ));
          } else if (detail is List) {
            summary = loc.errorValidationSummary;
            for (var item in detail) {
              if (item is Map) {
                final locList = (item['loc'] as List?)
                        ?.where((p) => p.toString() != 'body')
                        .map((p) => loc.errorFieldName(p.toString()))
                        .toList() ??
                    [];
                final rawField = (item['loc'] as List?)?.last?.toString() ?? loc.errorUnspecifiedField;
                final fieldPath = locList.join(' ➔ ');
                final msg = item['msg']?.toString() ?? loc.errorInvalidValue;

                String localizedMsg = msg;
                String rec = loc.errorStandardRecommendation;
                if (msg.contains('Field required') || msg.contains('field required')) {
                  localizedMsg = loc.errorFieldRequiredMsg;
                  rec = loc.errorFieldRequiredRec;
                } else if (msg.contains('valid date')) {
                  localizedMsg = loc.errorValidDateMsg;
                  rec = loc.errorValidDateRec;
                } else if (msg.contains('at least')) {
                  localizedMsg = loc.errorMinLengthMsg;
                  rec = loc.errorMinLengthRec;
                }

                final displayField = fieldPath.isNotEmpty ? fieldPath : loc.errorFieldName(rawField);
                points.add('[$displayField]: $localizedMsg');
                issues.add(ValidationIssueItem(
                  fieldName: displayField,
                  issueDescription: localizedMsg,
                  recommendation: rec,
                  isBlocking: true,
                ));
              } else {
                points.add(item.toString());
              }
            }
          } else if (data['message'] != null) {
            summary = data['message'].toString();
            points.add(summary);
          }
        }
      } else if (error.type == DioExceptionType.connectionError ||
          error.message?.contains('XMLHttpRequest') == true ||
          error.message?.contains('connection error') == true ||
          error.message?.contains('Failed to fetch') == true) {
        isConn = true;
        final targetUri = error.requestOptions.uri.toString().isNotEmpty 
            ? error.requestOptions.uri.toString() 
            : ApiConstants.baseUrl;
        summary = loc.errorConnectionSummary;
        points.add(loc.errorConnectionPointUnavailable);
        points.add(loc.errorConnectionPointTarget(targetUri));
        points.add(loc.errorConnectionPointCors);

        issues.add(ValidationIssueItem(
          fieldName: loc.errorConnectionFieldName,
          issueDescription: loc.errorConnectionIssueDesc(targetUri, error.message ?? 'XMLHttpRequest onError'),
          recommendation: loc.errorConnectionRecommendation,
          isBlocking: true,
        ));
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        isConn = true;
        summary = loc.errorTimeoutSummary;
        points.add(loc.errorTimeoutPoint);
        issues.add(ValidationIssueItem(
          fieldName: loc.errorTimeoutFieldName,
          issueDescription: loc.errorTimeoutIssueDesc,
          recommendation: loc.errorTimeoutRecommendation,
          isBlocking: true,
        ));
      } else {
        summary = error.message ?? defaultMessage ?? loc.errorDefaultSummary;
        points.add(summary);
      }
    } else {
      points.add(error.toString());
    }

    if (points.isEmpty) {
      points.add(summary);
    }

    return ParsedErrorInfo(
      summary: summary,
      validationIssues: issues,
      errorPoints: points,
      rawTechnicalLog: rawLog,
      isConnectionError: isConn,
    );
  }
}

Future<void> showErrorDetailsDialog(
  BuildContext context, {
  required String title,
  required dynamic error,
  String? subtitle,
  List<ValidationIssueItem>? validationIssues,
  Future<void> Function()? onRetry,
  VoidCallback? onFixAction,
  AppLocalizations? l10n,
}) async {
  final loc = l10n ?? context.l10n;
  final parsed = ErrorFormatter.parse(
    error,
    defaultMessage: subtitle ?? loc.errorDialogDefaultSubtitle,
    customIssues: validationIssues,
    l10n: loc,
  );

  bool showTechnical = false;
  bool isRetrying = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.crimson, width: 1.5),
            ),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.crimson,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            content: SelectionArea(
              child: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: parsed.isConnectionError ? Colors.orange.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: parsed.isConnectionError ? Colors.orange.shade300 : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            parsed.isConnectionError ? Icons.wifi_off_rounded : Icons.warning_amber_rounded,
                            color: parsed.isConnectionError ? Colors.orange.shade900 : AppTheme.crimson,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parsed.summary,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: parsed.isConnectionError ? Colors.orange.shade900 : AppTheme.charcoal,
                                    fontSize: 13.5,
                                  ),
                                ),
                                if (parsed.isConnectionError) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    loc.errorConnectionBannerHint,
                                    style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (parsed.validationIssues.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.playlist_remove, color: AppTheme.crimson, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.errorTableSectionTitle(parsed.validationIssues.length),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.4),
                            1: FlexColumnWidth(2.0),
                            2: FlexColumnWidth(2.2),
                          },
                          border: TableBorder(
                            horizontalInside: BorderSide(color: Colors.grey.shade200),
                          ),
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade100),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Text(loc.errorColFieldCondition, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Text(loc.errorColDescription, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Text(loc.errorColAction, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            ...parsed.validationIssues.map((issue) {
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          issue.isBlocking ? Icons.cancel : Icons.error_outline,
                                          size: 14,
                                          color: issue.isBlocking ? AppTheme.crimson : Colors.orange.shade800,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            issue.fieldName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    child: Text(
                                      issue.issueDescription,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: issue.isBlocking ? AppTheme.crimson : AppTheme.charcoal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    child: Text(
                                      issue.recommendation ?? '—',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() => showTechnical = !showTechnical);
                            },
                            icon: Icon(
                              showTechnical ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            label: Text(
                              showTechnical
                                  ? loc.errorBtnHideTechnicalLog
                                  : loc.errorBtnShowTechnicalLog,
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            icon: const Icon(Icons.copy, size: 14, color: AppTheme.cobalt),
                            label: Text(loc.errorBtnCopyReport, style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                            onPressed: () {
                              final report = '''
${loc.errorReportHeader}
${loc.errorReportDateTime} ${DateTime.now().toIso8601String()}
${loc.errorReportTitle} $title
${loc.errorReportSummary} ${parsed.summary}
${loc.errorReportType} ${parsed.isConnectionError ? loc.errorReportTypeConnection : loc.errorReportTypeValidation}
------------------------------------------------
${loc.errorReportIssues(parsed.validationIssues.length)}
${parsed.validationIssues.map((i) => '- [${i.fieldName}]: ${i.issueDescription} -> ${i.recommendation}').join('\n')}
------------------------------------------------
${loc.errorReportRawLog}
${parsed.rawTechnicalLog}
================================================
''';
                              CopyHelper.copy(context, report, customMessage: loc.errorReportCopiedSnackBar);
                            },
                          ),
                        ],
                      ),
                    ),
                    if (showTechnical) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SelectableText(
                          parsed.rawTechnicalLog,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              if (onRetry != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: isRetrying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(isRetrying ? loc.errorBtnRetrying : loc.errorBtnRetryNow),
                  onPressed: isRetrying
                      ? null
                      : () async {
                          setState(() => isRetrying = true);
                          try {
                            await onRetry();
                            if (context.mounted) Navigator.of(ctx).pop();
                          } catch (retryErr) {
                            if (context.mounted) {
                              setState(() => isRetrying = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(loc.errorRetryFailedSnackBar(retryErr.toString())),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check),
                label: Text(loc.errorBtnFixAndClose),
                onPressed: () {
                  if (onFixAction != null) {
                    onFixAction();
                  }
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}
