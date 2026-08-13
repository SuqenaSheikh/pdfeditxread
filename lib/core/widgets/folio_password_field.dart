import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Folio-styled password field with show/hide toggle.
class FolioPasswordField extends StatefulWidget {
  const FolioPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint = 'Enter password',
    this.autofocus = false,
    this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;

  @override
  State<FolioPasswordField> createState() => _FolioPasswordFieldState();
}

class _FolioPasswordFieldState extends State<FolioPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.78),
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          autofocus: widget.autofocus,
          onSubmitted: widget.onSubmitted,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            filled: true,
            fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.45),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.error),
            ),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? PhosphorIconsRegular.eye
                    : PhosphorIconsRegular.eyeSlash,
                color: colors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Themed password prompt used for opening and protecting PDFs.
Future<String?> showFolioPasswordDialog(
  BuildContext context, {
  required String title,
  String message = 'This PDF is protected. Enter the password to open it.',
  String confirmLabel = 'Unlock',
  String? errorText,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FolioPasswordDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      errorText: errorText,
    ),
  );
}

class _FolioPasswordDialog extends StatefulWidget {
  const _FolioPasswordDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.errorText,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? errorText;

  @override
  State<_FolioPasswordDialog> createState() => _FolioPasswordDialogState();
}

class _FolioPasswordDialogState extends State<_FolioPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value.trim().isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(PhosphorIconsRegular.x),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: 16),
          FolioPasswordField(
            controller: _controller,
            autofocus: true,
            errorText: widget.errorText,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
