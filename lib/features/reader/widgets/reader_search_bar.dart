import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ReaderSearchBar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onPrevious,
    required this.onNext,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Find in document',
                isDense: true,
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          IconButton(
            onPressed: () => onSubmitted(controller.text),
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
          ),
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(PhosphorIconsRegular.caretUp),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(PhosphorIconsRegular.caretDown),
          ),
        ],
      ),
    );
  }
}
