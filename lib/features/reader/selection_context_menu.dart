import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';

/// Folio-styled replacement for Syncfusion's default purple Material 3 menu.
class SelectionContextMenu extends StatelessWidget {
  const SelectionContextMenu({
    super.key,
    required this.onAction,
  });

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = <({String id, String label, IconData icon})>[
      (id: 'Copy', label: 'Copy', icon: PhosphorIconsRegular.copy),
      (
        id: 'Highlight',
        label: 'Highlight',
        icon: PhosphorIconsRegular.highlighterCircle
      ),
      (
        id: 'Underline',
        label: 'Underline',
        icon: PhosphorIconsRegular.textUnderline
      ),
      (
        id: 'Strikethrough',
        label: 'Strikethrough',
        icon: PhosphorIconsRegular.textStrikethrough
      ),
      (
        id: 'Squiggly',
        label: 'Squiggly',
        icon: PhosphorIconsRegular.waveSine
      ),
      (
        id: 'Edit',
        label: 'Edit PDF',
        icon: PhosphorIconsRegular.pencilSimple
      ),
    ];

    return Material(
      elevation: 4,
      color: colors.surface,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 168, maxWidth: 200),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                InkWell(
                  onTap: () => onAction(item.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: item.id == 'Highlight'
                              ? AppColors.accentSecondary
                              : colors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
