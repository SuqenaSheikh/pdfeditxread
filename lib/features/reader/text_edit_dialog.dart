import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';

class TextEditDialogResult {
  const TextEditDialogResult({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.markupOnly,
  });

  final String text;
  final bool bold;
  final bool italic;

  /// When set, apply this markup annotation instead of rewriting glyphs.
  /// Values: highlight | underline | strikethrough | squiggly
  final String? markupOnly;
}

Future<TextEditDialogResult?> showTextEditDialog(
  BuildContext context, {
  required String initialText,
}) {
  return showDialog<TextEditDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _TextEditDialog(initialText: initialText),
  );
}

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({required this.initialText});

  final String initialText;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller;
  bool _bold = false;
  bool _italic = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _popMarkup(String markup) {
    Navigator.pop(
      context,
      TextEditDialogResult(
        text: _controller.text,
        bold: _bold,
        italic: _italic,
        markupOnly: markup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Edit text'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              style: TextStyle(
                fontWeight: _bold ? FontWeight.w700 : FontWeight.w400,
                fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
              ),
              decoration: const InputDecoration(
                hintText: 'Replacement text',
              ),
            ),
            const SizedBox(height: 12),
            Text('Style', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Bold'),
                  selected: _bold,
                  avatar: const Icon(PhosphorIconsRegular.textB, size: 16),
                  onSelected: (v) => setState(() => _bold = v),
                ),
                FilterChip(
                  label: const Text('Italic'),
                  selected: _italic,
                  avatar: const Icon(PhosphorIconsRegular.textItalic, size: 16),
                  onSelected: (v) => setState(() => _italic = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Markup', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Apply markup to the current selection without rewriting glyphs.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: Icon(
                    PhosphorIconsRegular.highlighterCircle,
                    size: 16,
                    color: AppColors.accentSecondary,
                  ),
                  label: const Text('Highlight'),
                  onPressed: () => _popMarkup('highlight'),
                ),
                ActionChip(
                  avatar: Icon(
                    PhosphorIconsRegular.textUnderline,
                    size: 16,
                    color: colors.primary,
                  ),
                  label: const Text('Underline'),
                  onPressed: () => _popMarkup('underline'),
                ),
                ActionChip(
                  avatar: Icon(
                    PhosphorIconsRegular.textStrikethrough,
                    size: 16,
                    color: colors.primary,
                  ),
                  label: const Text('Strike'),
                  onPressed: () => _popMarkup('strikethrough'),
                ),
                ActionChip(
                  avatar: Icon(
                    PhosphorIconsRegular.waveSine,
                    size: 16,
                    color: colors.primary,
                  ),
                  label: const Text('Squiggly'),
                  onPressed: () => _popMarkup('squiggly'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              TextEditDialogResult(
                text: _controller.text,
                bold: _bold,
                italic: _italic,
              ),
            );
          },
          child: const Text('Apply text'),
        ),
      ],
    );
  }
}
