import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/pdf_document_item.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.document,
    required this.onTap,
    this.onFavorite,
    this.onShare,
    this.onDelete,
    this.onRename,
    this.compact = false,
  });

  final PdfDocumentItem document;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final meta = [
      if (document.pageCount != null) formatPageCount(document.pageCount),
      if (document.fileSizeBytes != null)
        formatFileSize(document.fileSizeBytes),
      if (document.lastOpenedAt != null)
        formatRelativeDate(document.lastOpenedAt),
    ].where((e) => e.isNotEmpty).join(' · ');

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(compact ? 8 : 16),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showActions(context),
        borderRadius: BorderRadius.circular(compact ? 8 : 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 8 : 16),
            border: Border.all(color: colors.outline),
          ),
          padding: EdgeInsets.all(compact ? 10 : 12),
          child: Row(
            children: [
              _Thumb(name: document.name, favorite: document.isFavorite),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(meta, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _showActions(context),
                icon: Icon(
                  PhosphorIconsRegular.dotsThreeVertical,
                  color: colors.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    document.isFavorite
                        ? PhosphorIconsFill.star
                        : PhosphorIconsRegular.star,
                    color: AppColors.accentSecondary,
                  ),
                  title: Text(
                    document.isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onFavorite?.call();
                  },
                ),
                if (onRename != null)
                  ListTile(
                    leading: const Icon(PhosphorIconsRegular.pencilSimple),
                    title: const Text('Rename'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onRename?.call();
                    },
                  ),
                if (onShare != null)
                  ListTile(
                    leading: const Icon(PhosphorIconsRegular.shareNetwork),
                    title: const Text('Share'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onShare?.call();
                    },
                  ),
                if (onDelete != null)
                  ListTile(
                    leading: const Icon(
                      PhosphorIconsRegular.trash,
                      color: AppColors.error,
                    ),
                    title: const Text(
                      'Remove from library',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDelete?.call();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.name, required this.favorite});

  final String name;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Container(
          width: 52,
          height: 68,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIconsRegular.filePdf, color: accent, size: 22),
              const SizedBox(height: 4),
              Text(
                'PDF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        if (favorite)
          const Positioned(
            right: 2,
            top: 2,
            child: Icon(
              PhosphorIconsFill.star,
              size: 12,
              color: AppColors.accentSecondary,
            ),
          ),
      ],
    );
  }
}
