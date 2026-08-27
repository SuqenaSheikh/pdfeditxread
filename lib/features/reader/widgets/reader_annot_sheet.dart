import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

enum ReaderAnnotTool { none, highlight, underline, strikethrough, pen }

Future<void> showReaderAnnotSheet({
  required BuildContext context,
  required ReaderAnnotTool currentTool,
  required Color markupColor,
  required ValueChanged<ReaderAnnotTool> onSelectTool,
  required ValueChanged<Color> onSelectColor,
  required VoidCallback onSquiggly,
  required VoidCallback onStickyNote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Markup', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Highlight'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSelectTool(ReaderAnnotTool.highlight);
                    },
                  ),
                  ActionChip(
                    label: const Text('Underline'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSelectTool(ReaderAnnotTool.underline);
                    },
                  ),
                  ActionChip(
                    label: const Text('Strike'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSelectTool(ReaderAnnotTool.strikethrough);
                    },
                  ),
                  ActionChip(
                    label: const Text('Squiggly'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSquiggly();
                    },
                  ),
                  ActionChip(
                    label: const Text('Note'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onStickyNote();
                    },
                  ),
                  ActionChip(
                    label: Text(
                      currentTool == ReaderAnnotTool.pen ? 'Exit pen' : 'Pen',
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSelectTool(
                        currentTool == ReaderAnnotTool.pen
                            ? ReaderAnnotTool.none
                            : ReaderAnnotTool.pen,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Highlight color', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: AppConstants.highlightColors.map((value) {
                  final color = Color(value);
                  final selected = color.toARGB32() == markupColor.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      onSelectColor(color);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.outline,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
