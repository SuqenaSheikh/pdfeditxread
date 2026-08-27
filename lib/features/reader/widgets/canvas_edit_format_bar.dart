import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../editable_text_box.dart';

class CanvasEditFormatBar extends StatelessWidget {
  const CanvasEditFormatBar({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onDelete,
  });

  final PdfEditableBox selected;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  static const textColors = <Color>[
    Color(0xFF1C1C1E),
    Color(0xFF6B6B70),
    Color(0xFFC24E4E),
    Color(0xFF0F6E63),
    Color(0xFF1B4F9C),
    Color(0xFFF2B705),
    Color(0xFF7B3FA0),
    Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Bold',
                      onPressed: () {
                        selected.bold = !selected.bold;
                        onChanged();
                      },
                      icon: Icon(
                        PhosphorIconsRegular.textB,
                        color: selected.bold ? colors.primary : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Italic',
                      onPressed: () {
                        selected.italic = !selected.italic;
                        onChanged();
                      },
                      icon: Icon(
                        PhosphorIconsRegular.textItalic,
                        color: selected.italic ? colors.primary : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Smaller',
                      onPressed: () {
                        selected.setFontSizeFromToolbar(selected.fontSize - 1);
                        onChanged();
                      },
                      icon: const Icon(PhosphorIconsRegular.minus),
                    ),
                    Text(
                      '${selected.fontSize.round()}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    IconButton(
                      tooltip: 'Larger',
                      onPressed: () {
                        selected.setFontSizeFromToolbar(selected.fontSize + 1);
                        onChanged();
                      },
                      icon: const Icon(PhosphorIconsRegular.plus),
                    ),
                    IconButton(
                      tooltip: 'Delete text',
                      onPressed: onDelete,
                      icon: Icon(
                        PhosphorIconsRegular.trash,
                        color: colors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final color in textColors)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () {
                            selected.color = color;
                            onChanged();
                          },
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected.color.toARGB32() ==
                                        color.toARGB32()
                                    ? colors.primary
                                    : colors.outline,
                                width: selected.color.toARGB32() ==
                                        color.toARGB32()
                                    ? 2.5
                                    : 1,
                              ),
                              boxShadow: color.toARGB32() == 0xFFFFFFFF
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
