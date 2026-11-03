import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class SwiftRawSourcePanel extends StatelessWidget {
  final String rawSourceText;
  final String? highlightedFieldKey;
  final String? highlightSnippet;

  const SwiftRawSourcePanel({
    super.key,
    required this.rawSourceText,
    this.highlightedFieldKey,
    this.highlightSnippet,
  });

  @override
  Widget build(BuildContext context) {
    final snippet = highlightSnippet?.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkScaffoldBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.textStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.darkInputBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, color: AppTheme.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  context.l10n.faSwiftRawSource,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (highlightedFieldKey != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.orange, width: 0.8),
                    ),
                    child: Text(
                      context.l10n.faSwiftHighlightedField('$highlightedFieldKey'),
                      style: const TextStyle(
                        color: AppTheme.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _buildHighlightedRawText(rawSourceText, snippet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedRawText(String fullText, String? snippet) {
    if (snippet == null || snippet.isEmpty || !fullText.contains(snippet)) {
      return SelectableText(
        fullText,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          color: AppTheme.cloudWhite,
          height: 1.45,
        ),
      );
    }

    final spans = <TextSpan>[];
    final parts = fullText.split(snippet);
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            color: AppTheme.cloudWhite,
            height: 1.45,
          ),
        ));
      }
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: snippet,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.black,
            backgroundColor: AppTheme.orange,
            height: 1.45,
          ),
        ));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}
