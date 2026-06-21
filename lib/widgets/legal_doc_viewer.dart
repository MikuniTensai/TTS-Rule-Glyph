import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class LegalDocViewer extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalDocViewer({
    super.key,
    required this.title,
    required this.assetPath,
  });

  static Future<void> show(BuildContext context, {required String title, required String assetPath}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          child: LegalDocViewer(title: title, assetPath: assetPath),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // Use app colors matching theme or fallbacks
    final surfaceColor = colorScheme.surface;
    final borderColor = Colors.white.withOpacity(0.12);
    final textPrimary = Colors.white;
    final textSecondary = Colors.white70;
    final primaryAccent = colorScheme.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryAccent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: borderColor,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: borderColor,
            height: 1,
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: rootBundle.loadString(assetPath),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: primaryAccent,
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load document: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                } else {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _MarkdownParser(
                      markdown: snapshot.data ?? '',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryAccent: primaryAccent,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownParser extends StatelessWidget {
  final String markdown;
  final Color textPrimary;
  final Color textSecondary;
  final Color primaryAccent;

  const _MarkdownParser({
    required this.markdown,
    required this.textPrimary,
    required this.textSecondary,
    required this.primaryAccent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final lines = markdown.split('\n');
    final List<Widget> children = [];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('# ')) {
        // Skip main H1 because title is in bottom sheet header
        continue;
      } else if (line.startsWith('## ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            line.substring(3),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
        ));
      } else if (line.startsWith('### ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            line.substring(4),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: textPrimary.withOpacity(0.9),
            ),
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: TextStyle(
                  color: primaryAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  line.substring(2),
                  style: textTheme.bodyMedium?.copyWith(
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else {
        // Check for basic bold tags (e.g. **Effective Date:**)
        Widget contentWidget;
        if (line.contains('**')) {
          final parts = line.split('**');
          final spans = <TextSpan>[];
          for (var j = 0; j < parts.length; j++) {
            final isBold = j % 2 == 1;
            spans.add(TextSpan(
              text: parts[j],
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? textPrimary : textSecondary,
              ),
            ));
          }
          contentWidget = RichText(
            text: TextSpan(
              children: spans,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.45,
              ),
            ),
          );
        } else {
          contentWidget = Text(
            line,
            style: textTheme.bodyMedium?.copyWith(
              color: textSecondary,
              height: 1.45,
            ),
          );
        }

        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: contentWidget,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
